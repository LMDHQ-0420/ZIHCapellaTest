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
        self.cfg.update(schema_version=2,run_id='20261022T000000Z-12345678',cat_dir=str(self.root/'cat'),
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
        self.c.state['reserved_gpu_hours']=64
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
        self.assertTrue((run/'REPORT.md').is_file()); self.assertTrue(run.with_suffix('.tar.gz').is_file())
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
        self.assertTrue(self.root.with_suffix('.tar.gz').is_file())
    def test_uuid_and_field_parsing(self):
        u='01234567-89ab-cdef-0123-456789abcdef'
        self.assertEqual(m.normalize_uuid(u),'GPU-'+u)
        self.assertEqual(m.normalize_uuid('MIG-'+u),'')
        self.assertEqual(m.field('WorkDir=/a path/b StdOut=/home/x file NodeList=c27','WorkDir'),'/a path/b')

if __name__=='__main__': unittest.main()
