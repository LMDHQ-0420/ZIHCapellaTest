"""Offline tests. Fake Slurm commands only; never contacts or submits to a cluster."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import types
import unittest
import tarfile
import socket
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[1]/'capella_audit.sh'
SOURCE=SCRIPT.read_text().split("<<'CAPELLA_PY'\n",1)[1].rsplit('\nCAPELLA_PY',1)[0]
m=types.ModuleType('audit')
with patch.object(sys,'argv',['-',str(SCRIPT)]):
    exec(compile(SOURCE,str(SCRIPT),'exec'),m.__dict__)

class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.root=Path(self.tmp.name)/'run'
        self.root.mkdir(); (self.root/'jobs').mkdir(); (self.root/'cases').mkdir()
        self.cfg=copy.deepcopy(m.DEFAULT)
        self.cfg.update(schema_version=3,run_id='20261022T000000Z-12345678',cat_dir=str(self.root/'cat'),
                        sacct_fields=['JobIDRaw','JobID','State','Start','End','ExitCode'])
        m.atomic(self.root/'config.json',self.cfg); self.c=m.Controller(self.root)
    def tearDown(self): self.tmp.cleanup()
    def test_script_syntax_and_config(self):
        subprocess.run(['bash','-n',str(SCRIPT)],check=True)
        p=self.root/'generated.json'
        subprocess.run(['bash',str(SCRIPT),'init-config',str(p)],check=True,stdout=subprocess.PIPE)
        self.assertEqual(m.read(p)['max_gpus'],4)
        self.assertGreaterEqual(m.read(p)['long_seconds'],3600)
    def test_budget_and_documented_limits(self):
        self.assertEqual(self.c.case('rounding',wall_seconds=390)['wall_seconds'],420)
        self.assertEqual(self.c.guard(self.c.case('x',gpus=1,cpus=15)),'DOCUMENTED_CPU_CAP')
        self.assertEqual(self.c.guard(self.c.case('x',mem_mib=193251)),'DOCUMENTED_MEMORY_CAP')
        self.assertEqual(self.c.guard(self.c.case('x',exclusive=True)),'EXCLUSIVE_REQUIRES_ALL_GPU')
        self.assertEqual(self.c.guard(self.c.case('x',array=4,throttle=4,gpus=2)),'GPU_CONCURRENCY_LIMIT')
        self.c.state['reserved_gpu_hours']=self.cfg['gpu_hour_budget']
        self.assertEqual(self.c.guard(self.c.case('x')),'GPU_HOUR_RESERVATION_BUDGET')
    def test_site_rejection_never_submits(self):
        calls=[]
        def fake(args,timeout=30,cwd=None):
            calls.append(args); return 1,'Requested node configuration is not available'
        with patch.object(m,'command',fake): self.assertFalse(self.c.execute(self.c.case('reject')))
        self.assertEqual(len(calls),1)
        self.assertIn('--test-only',calls[0])
        self.assertEqual(self.c.state['reserved_gpu_hours'],0)
        self.assertEqual(self.c.state['cases']['reject']['status'],'REJECTED')
    def test_array_raw_numeric_ids_and_recovery_are_idempotent(self):
        case=self.c.case('array',array=4,throttle=4)
        # Emulate Slurm: JobIDRaw differs from array-form JobID.
        rows=[]
        for i in range(4):
            rows.append(dict(JobIDRaw=str(501+i),JobID=f'500_{i}',State='COMPLETED',ExitCode='0:0',Start='2026-10-22T00:00:00',End='2026-10-22T00:00:20'))
            p=self.root/'jobs'/'array'/f'500_{i}'
            p.mkdir(parents=True); m.atomic(p/'batch.result.json',{'exit_code':0})
        submits=[]
        def fake(args,timeout=30,cwd=None):
            if args[0]=='sbatch':
                if '--test-only' in args: return 0,'expected'
                submits.append(args); return 0,'500\n'
            return 0,'JobId=500 JobState=COMPLETED'
        with patch.object(m,'command',fake),patch.object(self.c,'query',return_value=rows):
            self.assertTrue(self.c.execute(case))
            self.assertTrue(self.c.execute(case))
        self.assertEqual(len(submits),1)
        self.assertEqual(self.c.state['cases']['array']['status'],'DONE')
    def test_slurm_success_requires_every_payload(self):
        case=self.c.case('missing')
        def fake(args,timeout=30,cwd=None):
            return (0,'expected') if '--test-only' in args else (0,'600\n') if args[0]=='sbatch' else (0,'')
        rows=[dict(JobIDRaw='600',JobID='600',State='COMPLETED',ExitCode='0:0',Start='2026-10-22T00:00:00')]
        with patch.object(m,'command',fake),patch.object(self.c,'query',return_value=rows):
            self.assertFalse(self.c.execute(case))
        self.assertTrue(self.c.state['cases']['missing']['pass_slurm'])
    def test_cancellation_checks_uid_comment_and_registry(self):
        case=self.c.case('owned'); case['comment']='capella-audit:RUN:owned'
        self.c.state['cases']['owned']={'job_id':'700'}
        for txt in ['UserId=someone(0) Comment=capella-audit:RUN:owned',
                    f'UserId=test({os.getuid()}) Comment=unrelated']:
            calls=[]
            def fake(args,timeout=30,cwd=None): calls.append(args); return 0,txt
            with patch.object(m,'command',fake),self.assertRaises(RuntimeError): self.c.cancel('700',case,'test')
            self.assertFalse(any(x[0]=='scancel' for x in calls))
        calls=[]
        def good(args,timeout=30,cwd=None):
            calls.append(args)
            return 0,f'UserId=test({os.getuid()}) Comment=capella-audit:RUN:owned'
        with patch.object(m,'command',good): self.assertTrue(self.c.cancel('700',case,'QUEUE_TIMEOUT'))
        self.assertEqual(calls[-1],['scancel','700'])
    def test_uncertain_submission_is_not_retried(self):
        case=self.c.case('uncertain'); case['job_name']='unique'
        s={'submit_epoch':time.time(),'status':'SUBMIT_INTENT'}
        with patch.object(m,'command',return_value=(0,'')),self.assertRaises(RuntimeError): self.c.reconcile(case,s)
        self.assertEqual(s['status'],'SUBMISSION_UNCERTAIN')
    def test_array_reconciliation_uses_array_parent(self):
        case=self.c.case('recover'); case['job_name']='unique'
        s={'submit_epoch':time.time(),'status':'SUBMISSION_UNCERTAIN'}
        def fake(args,timeout=30,cwd=None):
            return (0,'') if args[0]=='squeue' else (0,'500_0\n500_1\n500_2\n500_3\n')
        with patch.object(m,'command',fake): self.c.reconcile(case,s)
        self.assertEqual(s['job_id'],'500'); self.assertEqual(s['status'],'ACTIVE')
    def test_queue_timeout_is_no_resources(self):
        case=self.c.case('queue')
        self.c.state['cases']['queue']={'status':'ACTIVE','job_id':'900','submit_epoch':time.time()-4000}
        calls=[]
        def fake(args,timeout=30,cwd=None):
            calls.append(args)
            if args[0]=='scontrol': return 0,f'UserId=test({os.getuid()}) Comment={case["comment"]}'
            if args[0]=='squeue': return 0,'900|PENDING|N/A\n'
            return 0,''
        rows=[dict(JobIDRaw='900',JobID='900',State='PENDING',Start='Unknown',ExitCode='0:0')]
        done=[dict(JobIDRaw='900',JobID='900',State='CANCELLED',Start='Unknown',ExitCode='0:0')]
        with patch.object(m,'command',fake),patch.object(self.c,'query',side_effect=[rows,done]),patch.object(m.time,'sleep'):
            self.assertFalse(self.c.execute(case))
        self.assertEqual(self.c.state['cases']['queue']['outcome'],'NO_RESOURCES')
        self.assertEqual([a for a in calls if a[0]=='scancel'],[['scancel','900']])
    def test_environment_is_always_own_venv(self):
        prefix=m.environment_prefix(self.root,{},env={'VIRTUAL_ENV':'/unrelated','PYTHONPATH':'/unrelated'})
        self.assertEqual(prefix,[str(self.root/'.venv'/'bin'/'python3'),'-I'])
    def test_readonly_evidence_never_submits(self):
        calls=[]
        required='JobIDRaw JobID State Start End ReqTRES AllocTRES'
        def fake(args,timeout=30,cwd=None):
            calls.append(args)
            return (0,required) if args==['sacct','--helpformat'] else (0,'')
        with patch.object(m,'command',fake): self.c.snapshot()
        self.assertTrue(self.c.state['evidence_complete'])
        self.assertFalse(any(a[0] in ['sbatch','scancel','srun'] for a in calls))
        self.assertFalse(any(a[0]=='squeue' for a in calls))
        self.assertEqual([a for a in calls if a[0]=='sacct'],[['sacct','--helpformat']])
    def test_standalone_evidence_end_to_end_without_cat(self):
        fakebin=self.root/'bin'; fakebin.mkdir()
        fake=fakebin/'fake-tool'
        fake.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
name=Path(sys.argv[0]).name
with open(os.environ['AUDIT_TEST_CALL_LOG'],'a') as f: f.write(name+' '+repr(sys.argv[1:])+'\\n')
if name in ['sbatch','scancel','srun']: sys.exit(99)
if name=='sacct' and '--helpformat' in sys.argv:
    print('JobIDRaw JobID JobName State ExitCode Submit Eligible Start End ReqTRES AllocTRES')
''')
        fake.chmod(0o700)
        for name in ['sacct','scontrol','sinfo','sacctmgr','squeue','sbatch','scancel','srun']:
            (fakebin/name).symlink_to(fake)
        home=self.root/'home'; home.mkdir()
        cfg=copy.deepcopy(m.DEFAULT); cfg.update(stages=[1],expected_user=os.environ['USER'])
        config=self.root/'read-only.json'; m.atomic(config,cfg)
        env=os.environ.copy()
        for k in list(env):
            if k.startswith('SLURM_'): env.pop(k)
        calls=self.root/'calls.txt'
        env.update(HOME=str(home),PATH=str(fakebin)+os.pathsep+env['PATH'],AUDIT_TEST_CALL_LOG=str(calls))
        # The delivered script fixes PATH to system tools. Inject fake Slurm only
        # into a temporary TEST COPY, never into the delivered script or live CLI.
        local_script=self.root/'test-copy.sh'
        local_script.write_text(SCRIPT.read_text().replace(
            'export PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
            'export PATH='+str(fakebin)+':/usr/bin:/bin:/usr/sbin:/sbin'))
        r=subprocess.run(['bash',str(local_script),'start','--config',str(config),'--foreground'],env=env,text=True,capture_output=True,timeout=30)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        runs=[p for p in (home/'capella-audit').iterdir() if p.is_dir()]; self.assertEqual(len(runs),1)
        run=runs[0]
        self.assertTrue((run/'REPORT.md').is_file()); self.assertTrue(run.with_suffix('.full.tar.gz').is_file())
        self.assertEqual(m.read(run/'config.json')['cat_dir'],'')
        self.assertEqual(m.read(run/'results.json')['reserved_gpu_hour_upper_bound'],0)
        invoked=calls.read_text().splitlines()
        self.assertFalse(any(l.split()[0] in ['sbatch','scancel','srun'] for l in invoked))
        self.assertFalse(any(l.split()[0]=='squeue' for l in invoked))
    def test_no_external_workload_configuration(self):
        for key in ['project','g2i','history_jobs','evidence_files','train_adapter','workflow_adapter','project_env','container','cat_root']:
            self.assertNotIn(key,m.DEFAULT)
        self.assertNotIn('importlib',SOURCE)
        self.assertNotIn("['ps','-u'",SOURCE)
        self.assertNotIn('--export=ALL',SOURCE)
    def test_gpu_queries_require_owned_selector(self):
        with patch.dict(os.environ,{},clear=True):
            self.assertIsNone(m.gpu_command('uuid'))
        with patch.dict(os.environ,{'SLURM_JOB_GPUS':'1,3'},clear=True):
            self.assertIn('--id=1,3',m.gpu_command('uuid'))
        self.assertIsNone(m.gpu_command('uuid',devices='all'))
    def test_builtin_workloads_are_fixed_and_self_contained(self):
        w=m.BuiltinWorkload()
        descriptions=[w.describe({'model':size}) for size in ['S','M','L']]
        self.assertEqual(len({r['model_id'] for r in descriptions}),3)
        self.assertEqual(len({r['data_id'] for r in descriptions}),1)
        self.assertEqual({r['batch_size'] for r in descriptions},{64})
    def test_rejects_old_external_configuration_before_commands(self):
        p=self.root/'old-config.json'; m.atomic(p,{'project':'/never-read-this'})
        with patch.object(m,'command') as execute,self.assertRaises(SystemExit): m.start(str(p),True)
        execute.assert_not_called()
    def test_software_is_installed_only_into_own_venv(self):
        calls=[]
        def fake(path,args,timeout=30): calls.append(args); return 0,'test package list'
        with patch.object(m,'capture',fake): self.assertTrue(m.prepare_runtime(self.root))
        self.assertEqual(calls[0][:5],['/usr/bin/python3','-I','-m','venv','--copies'])
        self.assertEqual(calls[1][0],str(self.root/'.venv'/'bin'/'python3'))
        self.assertIn('--isolated',calls[1]); self.assertIn('--no-cache-dir',calls[1])
        self.assertNotIn('--system-site-packages',str(calls))
    def test_real_local_io_locks_counts_and_restart(self):
        out=self.root/'jobs'/'io'/'local_0'; out.mkdir(parents=True)
        with patch.dict(os.environ,{},clear=False):
            # CI is outside Slurm; force the same local key even if the runner inherited variables.
            with patch.object(m,'job_key',return_value='local_0'):
                self.assertEqual(m.io_test(str(self.root),'io'),0)
        results=m.read(out/'io.json')
        self.assertEqual(len(results),2)
        for r in results:
            self.assertTrue(r['ok']); self.assertEqual(r['records'],800)
            self.assertEqual(r['child_exits'],[0]*8); self.assertEqual(r['restart_exits'],[0]*8)
            self.assertEqual(r['duplicates'],0); self.assertEqual(r['invalid_json'],0)
    def test_report_array_overlap_and_unallocated_classification(self):
        case=self.c.case('array',array=4,throttle=4)
        m.atomic(self.root/'cases'/'array.json',case)
        self.c.state['cases']['array']={'status':'DONE','job_id':'800','pass':False,'outcome':'INCONCLUSIVE_OR_FAILED',
                                      'queue_timed_out_elements':['800_3']}
        rows=[]
        for i in range(4):
            rows.append(dict(JobIDRaw=str(801+i),JobID=f'800_{i}',AllocTRES='cpu=1,gres/gpu=1,mem=1024M',State='COMPLETED' if i<3 else 'CANCELLED',
                             Start='2026-10-22T00:00:00' if i<3 else 'Unknown',End='2026-10-22T00:00:20'))
        m.atomic(self.root/'jobs'/'array'/'sacct.json',rows)
        self.c.report()
        r=m.read(self.root/'results.json')
        self.assertEqual(r['overlap']['array']['actual_peak_jobs'],3)
        self.assertEqual(r['global_actual_peak_gpus'],3)
        self.assertEqual(r['experiments'][-1]['outcome'],'NO_RESOURCES')
        self.assertAlmostEqual(r['gpu_hours_observed'],60/3600)
        self.assertTrue(self.root.with_suffix('.full.tar.gz').is_file())
    def test_uuid_and_field_parsing(self):
        u='01234567-89ab-cdef-0123-456789abcdef'
        self.assertEqual(m.normalize_uuid(u),'GPU-'+u)
        self.assertEqual(m.normalize_uuid('MIG-'+u),'')
        self.assertEqual(m.field('WorkDir=/a path/b StdOut=/home/x file NodeList=c27','WorkDir'),'/a path/b')

    def own_cat(self):
        cat=Path(self.cfg['cat_dir']); cat.mkdir(exist_ok=True)
        m.atomic(cat/'audit-owner.json',{'run_id':self.cfg['run_id'],'uid':os.getuid()})
        return cat

    def test_short_tmp_works_for_multiprocessing_unix_listener(self):
        # Real IPC, even when the inherited TMPDIR would exceed Linux's socket limit.
        long=self.root/('x'*100)/('y'*50); long.mkdir(parents=True)
        with patch.dict(os.environ,{'TMPDIR':str(long)}): scratch=m.short_temp()
        try:
            self.assertLess(len(str(scratch)),30)
            self.assertEqual(scratch.stat().st_mode & 0o777,0o700)
            env=os.environ.copy(); env['TMPDIR']=str(scratch)
            code='from multiprocessing.connection import Listener; l=Listener(family="AF_UNIX"); print(l.address); l.close()'
            result=subprocess.run([sys.executable,'-I','-c',code],env=env,capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn(str(scratch),result.stdout)
            with socket.socket(socket.AF_UNIX) as sock,self.assertRaises(OSError): sock.bind(str(long/'listener-abcdefgh'))
        finally: m.shutil.rmtree(scratch)

    def test_export_full_logs_results_and_checkpoint_option(self):
        cat=self.own_cat(); (cat/'slurm').mkdir(); (cat/'slurm'/'complete.out').write_bytes(b'Z'*2_100_001)
        (self.root/'controller.log').write_text('full controller log\n')
        (cat/'weights.pt').write_bytes(b'own-checkpoint')
        (self.root/'.venv').mkdir(); (self.root/'.venv'/'secret-software').write_text('excluded')
        (cat/'external-link').symlink_to('/etc/hosts')
        manifest=m.export_run(self.root)
        self.assertTrue(manifest['complete_logs'])
        archive=self.root.with_suffix('.full.tar.gz')
        self.assertEqual(m.verify_export(archive),manifest)
        with tarfile.open(archive) as tar:
            self.assertEqual(tar.extractfile('run/cat/slurm/complete.out').read(),b'Z'*2_100_001)
            self.assertFalse(any('.venv/' in n or 'weights.pt' in n or 'external-link' in n for n in tar.getnames()))
        with patch.object(m,'command') as commands:
            all_manifest=m.export_run(self.root,True)
        commands.assert_not_called()
        self.assertTrue(any(r['archive_path'].endswith('/weights.pt') for r in all_manifest['files']))
        self.assertTrue((self.root.parent/'run.all.tar.gz.sha256').exists())

    def test_export_v2_partial_and_no_legacy_archive_overwrite(self):
        self.cfg['schema_version']=2; m.atomic(self.root/'config.json',self.cfg)
        original=self.root.with_suffix('.tar.gz'); original.write_bytes(b'original evidence')
        manifest=m.export_run(self.root)
        self.assertFalse(manifest['complete_logs']); self.assertEqual(manifest['gaps'][0]['source'],'cat')
        self.assertEqual(original.read_bytes(),b'original evidence')
        self.assertFalse(any('BOUNDED' in str(x) for x in manifest['files']))

    def test_export_refuses_active_controller_and_corrupt_content(self):
        self.own_cat(); (self.root/'test.log').write_bytes(b'actual content')
        with (self.root/'controller.lock').open('a') as lock:
            m.fcntl.flock(lock,m.fcntl.LOCK_EX|m.fcntl.LOCK_NB)
            with self.assertRaisesRegex(RuntimeError,'active'): m.export_run(self.root)
        m.export_run(self.root); archive=self.root.with_suffix('.full.tar.gz')
        corrupt=self.root.parent/'corrupt.tar.gz'
        import io
        with tarfile.open(archive) as source,tarfile.open(corrupt,'w:gz') as dest:
            for member in source:
                payload=source.extractfile(member).read()
                if member.name.endswith('/test.log'): payload=b'bad content'; member.size=len(payload)
                dest.addfile(member,io.BytesIO(payload))
        with self.assertRaisesRegex(RuntimeError,'checksum mismatch'): m.verify_export(corrupt)

    def test_capture_keeps_output_beyond_two_megabytes(self):
        output='a'*2_100_001+'TAIL'
        with patch.object(m,'command',return_value=(0,output)): m.capture(self.root/'big.log',['fake'])
        self.assertIn('TAIL',(self.root/'big.log').read_text())

    def test_report_lock_precedes_every_write(self):
        self.own_cat()
        m.atomic(self.root/'state.json',self.c.state)
        before=(self.root/'state.json').read_bytes()
        self.c.state['notes'].append({'text':'must never overwrite live state'})
        with (self.root/'controller.lock').open('a') as lock:
            m.fcntl.flock(lock,m.fcntl.LOCK_EX|m.fcntl.LOCK_NB)
            with self.assertRaisesRegex(RuntimeError,'active'): self.c.report()
        self.assertEqual((self.root/'state.json').read_bytes(),before)
        self.assertFalse((self.root/'REPORT.md').exists())

    def test_export_marks_unreadable_subtrees_as_incomplete(self):
        self.own_cat(); walk=m.os.walk
        def denied(base,**kw):
            if Path(base).resolve()==self.root.resolve():
                if kw.get('onerror'): kw['onerror'](PermissionError(13,'Permission denied',str(self.root/'unreadable')))
                yield str(base),[],['config.json']
            else: yield from walk(base,**kw)
        with patch.object(m.os,'walk',denied): manifest=m.export_run(self.root)
        self.assertFalse(manifest['complete_logs'])
        self.assertIn('unreadable',str(manifest['gaps']))
        self.assertEqual(m.verify_export(self.root.with_suffix('.full.tar.gz')),manifest)

    def test_export_of_registered_active_jobs_is_only_a_snapshot(self):
        self.own_cat()
        self.c.state['cases']['running']={'status':'ACTIVE','job_id':'123'}; self.c.save()
        manifest=m.export_run(self.root)
        self.assertFalse(manifest['complete_logs'])
        self.assertIn('123',str(manifest['gaps']))

    def test_all_array_queue_timeouts_are_no_resources(self):
        c=self.c.case('queue-array',array=2,throttle=2)
        self.c.state['cases'][c['id']]={'status':'ACTIVE','job_id':'901','submit_epoch':time.time()-4000}
        pending=[dict(JobIDRaw=str(902+i),JobID=f'901_{i}',State='PENDING',Start='Unknown') for i in range(2)]
        done=[dict(r,State='CANCELLED',ExitCode='0:0') for r in pending]
        def fake(args,timeout=30,cwd=None):
            if args[0]=='scontrol': return 0,f'UserId=test({os.getuid()}) Comment={c["comment"]}'
            if args[0]=='squeue': return 0,'901_0|PENDING|N/A\n901_1|PENDING|N/A\n'
            return 0,''
        with patch.object(m,'command',fake),patch.object(self.c,'query',side_effect=[pending,done]),patch.object(m.time,'sleep'):
            self.assertFalse(self.c.execute(c))
        self.assertEqual(self.c.state['cases'][c['id']]['outcome'],'NO_RESOURCES')

    def test_timeout_terminates_own_process_tree(self):
        marker=self.root/'orphan-ran.txt'
        child='import time,pathlib; time.sleep(1); pathlib.Path('+repr(str(marker))+').write_text("orphan")'
        parent='import subprocess,sys,time; subprocess.Popen([sys.executable,"-c",'+repr(child)+']); print("launched",flush=True); time.sleep(10)'
        rc,output=m.command([sys.executable,'-I','-c',parent],.3)
        self.assertEqual(rc,124); self.assertIn('COMMAND_TIMEOUT',output)
        time.sleep(1.1)
        self.assertFalse(marker.exists(),'timed out command left a descendant running')

    def test_invalid_configuration_fails_before_cluster_commands(self):
        for key,value in [('repeats',2.5),('max_gpus',True),('gpu_hour_budget',float('nan')),
                          ('gpu_hour_budget',float('inf')),('node_samples',2.5),('short_seconds',4500),
                          ('models',[]),('stages',[True]),('tune_workers',[True])]:
            with self.subTest(key=key,value=value):
                cfg=copy.deepcopy(m.DEFAULT); cfg[key]=value
                with self.assertRaises(ValueError): m.validate(cfg)

    def test_mps_failure_stops_only_its_own_escalation(self):
        self.c.cfg.update(models=['S'],tune_threads=[],tune_workers=[])
        executed=[]
        def execute(c):
            executed.append(c)
            return not (c['mps'] and c['concurrency']==2)
        def measure(cases):
            return [dict(case=c['id'],n=c['concurrency'],mps=c['mps'],threads=c['threads'],workers=c['workers'],
                         safe=True,throughput=c['concurrency']) for c in cases if not (c['mps'] and c['concurrency']==2)]
        with patch.object(self.c,'execute',execute),patch.object(self.c,'measure',measure): self.c.stress_matrix()
        self.assertTrue(any(not c['mps'] and c['concurrency']==12 for c in executed))
        self.assertFalse(any(c['mps'] and c['concurrency']>2 for c in executed))

    def test_measure_requires_valid_gpu_and_cpu_samples(self):
        c=self.c.train_case('telemetry','S',1); self.c.state['cases'][c['id']]={'pass':True}
        d=self.root/'jobs'/c['id']/'123_0'; d.mkdir(parents=True)
        m.atomic(d/'launcher.result.json',{'total_items_per_second':100,'total_items':6000,'devices':['GPU-0']})
        m.atomic(d/'launcher.context.json',{'affinity':list(range(14))})
        m.atomic(d/'child-g0-p0'/'result.json',dict(ok=True,binding_verified=True,observed_uuid='GPU-0',
            torch_peak_reserved=50,gpu_total_bytes=1000,workload={'fixed':True}))
        sample=dict(cgroup={'effective_memory':{'memory.peak':'10','memory.max':'100'}},
                    gpu={'exit':0,'output':'GPU-0, 100, 10, 50, 70'},cpu_total_percent=10,
                    thread_total=1,rss_sum_kib=100)
        for fault in ['none','gpu_error','gpu_missing','cpu_missing','cpu_nan']:
            with self.subTest(fault=fault):
                snap=copy.deepcopy(sample)
                if fault=='gpu_error': snap['gpu']={'exit':1,'output':'GPU-0, 100, 10, 50, 70'}
                if fault=='gpu_missing': snap['gpu']['output']='N/A'
                if fault=='cpu_missing': snap.pop('cpu_total_percent')
                if fault=='cpu_nan': snap['cpu_total_percent']=float('nan')
                (d/'events.jsonl').write_text('')
                for _ in range(2): m.event(d,'sample',data=snap)
                measured=self.c.measure([c])
                self.assertEqual(len(measured),1 if fault=='none' else 0)

    def test_io_integrity_failure_in_retry_is_not_retried_away(self):
        executed=[]
        def execute(c):
            executed.append(c['id'])
            if c['id']=='f6-io-retry-r1':
                m.atomic(self.root/'jobs'/c['id']/'123_0'/'io.json',[{'filesystem':'home','ok':False}])
            return False
        with patch.object(self.c,'execute',execute),patch.object(self.c,'followup_pipelines') as pipeline:
            self.c.final_stage()
        self.assertEqual(executed,['p6-io','f6-io-retry-r1'])
        pipeline.assert_called_once_with(False)

    def test_report_refreshes_state_after_acquiring_lock(self):
        state=copy.deepcopy(self.c.state); state['notes']=[{'text':'newer saved state'}]
        m.atomic(self.root/'state.json',state)
        self.c.report()
        self.assertEqual(m.read(self.root/'state.json')['notes'],state['notes'])

    def test_node_pairing_changes_one_factor_and_counterbalances(self):
        cases=[]
        with patch.object(self.c,'node_available',return_value=True),patch.object(self.c,'execute',side_effect=lambda c:cases.append(c)):
            self.c.node_paths('c59')
        self.assertEqual(len(cases),16)
        for i in range(8):
            base=cases[0]
            changed={k for k in cases[i] if cases[i][k]!=base.get(k)}-{'id'}
            self.assertLessEqual(len(changed),1)
        self.assertTrue(cases[8]['id'].endswith('ntpn-r2'))
        resource=[]
        with patch.object(self.c,'node_available',return_value=True),patch.object(self.c,'execute',side_effect=lambda c:resource.append(c)):
            self.c.followup_resources()
        self.assertTrue(any(c['mode']=='direct' for c in resource))
        self.assertEqual({c['gpus'] for c in resource},{4})

    def test_training_preflight_stops_cat_before_cuda_discovery(self):
        c=self.c.train_case('cat-test','S',1); c['storage']='cat'
        m.atomic(self.root/'cases'/'cat-test.json',c)
        with patch.object(m,'fs_probe',return_value=72),patch.object(m,'context_snapshot',return_value={}),patch.object(m,'command') as cmd:
            self.assertEqual(m.run_training(self.root,'cat-test'),72)
        cmd.assert_not_called()
        self.assertEqual(m.read(self.root/'jobs'/'cat-test'/'local_0'/'launcher.error.json')['type'],'FILESYSTEM_PREFLIGHT')

    def test_local_training_can_proceed_to_cuda_discovery_without_cat(self):
        c=self.c.train_case('local-test','S',1); c['storage']='local'
        m.atomic(self.root/'cases'/'local-test.json',c)
        with patch.object(m,'fs_probe',return_value=72),patch.object(m,'context_snapshot',return_value={}),patch.object(m,'capture'),patch.object(m,'command',return_value=(1,'CUDA unavailable')) as cmd:
            self.assertEqual(m.run_training(self.root,'local-test'),76)
        self.assertIn('--devices',cmd.call_args.args[0])

    def test_report_includes_launcher_root_error_and_ipc_error(self):
        case=self.c.case('fault',kind='train'); m.atomic(self.root/'cases'/'fault.json',case)
        self.c.state['cases']['fault']={'status':'DONE','outcome':'INCONCLUSIVE_OR_FAILED','pass':False}
        out=self.root/'jobs'/'fault'/'123_0'; out.mkdir(parents=True)
        m.atomic(out/'launcher.error.json',{'traceback':"PermissionError: /data/cat/ws unavailable"})
        (out/'g0-p0.log').write_text('OSError: AF_UNIX path too long\n')
        self.c.report(); types={r['type'] for r in m.read(self.root/'findings.json')['confirmed']}
        self.assertTrue({'CAT_PATH_UNUSABLE','IPC_TEMP_PATH_TOO_LONG'}<=types)

    def test_probe_retries_preserve_initial_failure_and_mount_evidence(self):
        (self.root/'fs').mkdir(); c=self.c.case('probe',retry_probe=True)
        m.atomic(self.root/'cases'/'probe.json',c)
        with patch.object(m,'context_snapshot',return_value={'hostname':'c59'}),patch.object(m,'command',return_value=(0,'mock root filesystem')),patch.dict(os.environ,{'SLURM_JOB_ID':'123'}),patch.object(m.time,'sleep'):
            self.assertEqual(m.fs_probe(self.root,'probe','step'),72)
        d=self.root/'jobs'/'probe'/'123_0'
        self.assertEqual(m.read(d/'step.home.json')['rw'],'PASS')
        self.assertEqual(m.read(d/'step.cat.json')['rw'],'FAIL')
        self.assertTrue((d/'step-retry.cat.json').exists())
        self.assertIn('cat_mount',m.read(d/'step.cat.json'))
        self.assertFalse(Path(self.cfg['cat_dir']).exists())
        self.assertEqual(list((self.root/'fs').iterdir()),[])

    def test_multigpu_margin_is_per_physical_gpu_and_includes_cpu(self):
        c=self.c.train_case('multi','S',2); c.update(gpus=4,cpus=56)
        self.c.state['cases']['multi']={'pass':True}
        d=self.root/'jobs'/'multi'/'123_0'; d.mkdir(parents=True)
        m.atomic(d/'launcher.result.json',{'total_items_per_second':800,'total_items':48000,'devices':['GPU-'+str(i) for i in range(4)]})
        m.atomic(d/'launcher.context.json',{'affinity':list(range(56))})
        m.atomic(self.root/'jobs'/'multi'/'sacct.json',[dict(JobID='123',Start='2026-10-22T00:00:00',
            End='2026-10-22T00:01:00',AllocTRES='gres/gpu=4')])
        for gpu in range(4):
            for child in range(2):
                m.atomic(d/f'child-g{gpu}-p{child}'/'result.json',dict(ok=True,binding_verified=True,observed_uuid='GPU-'+str(gpu),
                    torch_peak_reserved=50,gpu_total_bytes=1000,workload={'fixed':True}))
        sample={'cgroup':{'effective_memory':{'memory.peak':'10','memory.max':'100','memory.events':'oom_kill 0'}},
                'gpu':{'output':'\n'.join(f'GPU-{i}, 100, 10, 50, 70' for i in range(4))},'cpu_total_percent':560,
                'thread_total':16,'rss_sum_kib':100}
        for _ in range(2): m.event(d,'sample',data=sample)
        r=self.c.measure([c])[0]
        self.assertAlmostEqual(r['gpu_fraction'],.1); self.assertAlmostEqual(r['cpu_fraction'],.1)
        self.assertEqual(r['items_per_gpu_hour'],720000); self.assertTrue(r['safe'])
        self.assertAlmostEqual(r['requested_gpu_hours'],4*c['wall_seconds']/3600)
        m.atomic(d/'launcher.context.json',{'affinity':list(range(6))})
        self.assertFalse(self.c.measure([c])[0]['safe'])

    def test_resume_drains_registered_jobs_before_new_stages(self):
        c=self.c.case('later',stage=6); m.atomic(self.root/'cases'/'later.json',c)
        self.c.state['cases']['later']={'status':'ACTIVE','job_id':'123'}
        self.c.cfg['stages']=[1]; self.c.state['evidence_complete']=True
        order=[]
        with patch.object(self.c,'execute_group',side_effect=lambda cases:order.append([c['id'] for c in cases])),patch.object(self.c,'report',side_effect=lambda:order.append('report')):
            self.c.run()
        self.assertEqual(order,[['later'],'report'])

    def test_host_memory_checks_job_ancestor_and_final_counters(self):
        fraction,oom=m.memory_evidence({'effective_memory':{'memory.peak':'10','memory.max':'100','memory.events':'oom_kill 0'},
            'memory.scopes':[{'memory.peak':'95','memory.max':'100','memory.events':'oom_kill 1'}]})
        self.assertEqual(fraction,.95); self.assertTrue(oom)
        self.assertEqual(m.memory_evidence({'memory.max':'max','memory.peak':'100'}),(0,False))

    def test_job_count_comparison_matches_resources_per_gpu(self):
        cases=[]
        with patch.object(self.c,'execute_group',side_effect=lambda g:cases.extend(g)),patch.object(self.c,'execute',side_effect=lambda c:cases.append(c)):
            self.c.job_concurrency()
        self.assertEqual({c['mem_mib']/c['gpus'] for c in cases},{179200})
        self.assertEqual({c['cpus']/c['gpus'] for c in cases},{14})
        self.assertEqual({(c['concurrency'],c['threads'],c['workers'],c['mps']) for c in cases},{(1,1,0,False)})

    def test_sinfo_flags_do_not_hide_planned_mixed_nodes(self):
        for raw in ['mixed','mixed-','MIXED-','idle-','allocated+']:
            self.assertTrue(m.node_state(raw)['candidate'],raw)
        for raw in ['mixed*','mixed@','draining@','drained*','reserved','inval','mixed+maint','unknown']:
            self.assertFalse(m.node_state(raw)['candidate'],raw)

    def test_node_admission_uses_public_gpu_tres(self):
        def capture(path,args,timeout=30):
            if args[0]=='sinfo': return 0,'c59|mixed-|none\n'
            return 0,'NodeName=c59 CfgTRES=cpu=56,gres/gpu=4 AllocTRES=cpu=14,gres/gpu=1\n'
        with patch.object(m,'capture',capture):
            self.assertTrue(self.c.node_available('c59'))
            self.assertFalse(self.c.node_available('c59',gpus=4))
        self.assertEqual(self.c.state['node_snapshots']['c59']['free_gpus'],3)

    def test_queue_timeout_defers_remaining_node_variants(self):
        calls=[]
        def execute(c):
            calls.append(c); self.c.state['cases'][c['id']]={'status':'DONE','outcome':'NO_RESOURCES'}
            return False
        with patch.object(self.c,'node_available',return_value=True),patch.object(self.c,'execute',execute):
            self.assertFalse(self.c.node_paths('c113'))
        self.assertEqual(len(calls),1)
        self.assertEqual(sum(s['status']=='SKIPPED' for s in self.c.state['cases'].values()),15)
        self.assertEqual(self.c.state['node_coverage']['c113']['status'],'UNVERIFIED_ADMISSION')

    def test_testonly_rejection_allows_one_cat_check_then_defers(self):
        calls=[]
        def execute(c):
            calls.append(c); self.c.state['cases'][c['id']]={'status':'REJECTED','reason':'SITE_TEST_ONLY_REJECTED'}
            return False
        with patch.object(self.c,'node_available',return_value=True),patch.object(self.c,'execute',execute): self.c.node_paths('c148')
        self.assertEqual([c['license'] for c in calls],['default','cat'])
        self.assertEqual(sum(s['status']=='SKIPPED' for s in self.c.state['cases'].values()),14)

    def test_single_gpu_environment_survives_four_gpu_queue_timeout(self):
        def execute(c):
            passed=c['gpus']==1
            self.c.state['cases'][c['id']]={'status':'DONE','outcome':'PASS' if passed else 'NO_RESOURCES','pass':passed}
            return passed
        with patch.object(m,'prepare_runtime',return_value=True),patch.object(self.c,'execute',execute):
            env=self.c.environment_matrix()
        self.assertTrue(env['standalone']); self.assertTrue(env['by_gpu_count']['1']['passed'])
        self.assertFalse(env['by_gpu_count']['4']['passed']); self.assertEqual(env['by_gpu_count']['4']['status'],'NO_RESOURCES')

    def test_run_continues_single_card_work_when_node_coverage_and_four_cards_are_unverified(self):
        self.c.cfg['stages']=[1,2,4,5,6]; self.c.state['evidence_complete']=True
        def paths():
            self.c.state.update(local_startup_ok=True,paths_baseline_ok=True); return False
        def execute(c):
            passed=c['gpus']==1
            self.c.state['cases'][c['id']]={'status':'DONE','outcome':'PASS' if passed else 'NO_RESOURCES','pass':passed}
            return passed
        order=[]
        with patch.object(self.c,'followup_paths',paths),patch.object(m,'prepare_runtime',return_value=True),patch.object(self.c,'execute',execute),\
             patch.object(self.c,'worker_preflight',side_effect=lambda:order.append('workers')),\
             patch.object(self.c,'job_concurrency',side_effect=lambda:order.append('jobs')),\
             patch.object(self.c,'stress_matrix',side_effect=lambda:order.append('stress')),\
             patch.object(self.c,'memory_pressure',side_effect=lambda:order.append('memory')),\
             patch.object(self.c,'final_stage',side_effect=lambda:order.append('final')),patch.object(self.c,'report'):
            self.c.run()
        self.assertEqual(order,['workers','jobs','stress','memory','final'])
        self.assertEqual(self.c.state['stage_results']['2'],'BASELINE_PASS_NODE_MATRIX_UNVERIFIED')
        self.assertEqual(self.c.state['stage_results']['5'],'ATTEMPTED_SEE_LONG_PASS_AND_CASE_OUTCOMES')

    def test_report_counts_rejected_as_unverified(self):
        c=self.c.case('reject'); m.atomic(self.root/'cases'/'reject.json',c)
        self.c.state['cases']['reject']={'status':'REJECTED','reason':'SITE_TEST_ONLY_REJECTED'}
        self.c.report()
        self.assertEqual(m.read(self.root/'findings.json')['unverified'][0]['status'],'REJECTED')
        self.assertEqual(m.read(self.root/'coverage.json')['allocated_cases'],0)

    def test_parameter_specific_rejection_does_not_suppress_other_controls(self):
        calls=[]
        def execute(c):
            calls.append(c)
            self.c.state['cases'][c['id']]={'status':'REJECTED'} if c['ntpn'] else {'status':'DONE','pass':True,'outcome':'PASS'}
            return not c['ntpn']
        with patch.object(self.c,'node_available',return_value=True),patch.object(self.c,'execute',execute):
            self.assertFalse(self.c.node_paths('c59'))
        self.assertEqual(len(calls),16)
        self.assertEqual(sum(s['status']=='SKIPPED' for s in self.c.state['cases'].values()),0)
        self.assertEqual(self.c.state['node_coverage']['c59']['status'],'PARTIAL')

    def test_late_four_card_queue_timeout_keeps_single_card_evidence(self):
        self.c.state['environments']={'standalone':True,'by_gpu_count':{'1':{'passed':True},'4':{'passed':False,'status':'NO_RESOURCES'}}}
        self.c.state['candidates']={'S':{'throughput':{'long_pass':True}}}
        with patch.object(self.c,'environment_probe',return_value={'passed':False,'status':'NO_RESOURCES'}) as probe,patch.object(self.c,'execute') as execute:
            self.c.followup_pipelines(True)
        probe.assert_called_once_with(4,'f6-own-4gpu-recheck'); execute.assert_not_called()
        self.assertTrue(self.c.state['environments']['standalone'])
        self.assertTrue(self.c.state['candidates']['S']['throughput']['long_pass'])
        self.assertFalse(self.c.state['four_gpu_candidates']['S']['verified'])

if __name__=='__main__': unittest.main()
