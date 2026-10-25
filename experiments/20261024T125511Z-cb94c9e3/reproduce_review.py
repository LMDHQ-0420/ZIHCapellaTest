"""Read and verify the exact third-run archive as data; never execute its code or call Slurm."""
import argparse
import collections
import csv
import datetime as dt
import hashlib
import io
import json
import math
import pathlib
import re
import statistics
import tarfile

RUN='20261024T125511Z-cb94c9e3'
EXPECTED='b46f6cfea46102abdfa11d372435b535cd2657d430fe772729801a624090f126'
PREFIX=RUN+'/home/'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive',type=pathlib.Path)
parser.add_argument('--out',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parent)
args=parser.parse_args()
digest=hashlib.sha256()
with args.archive.open('rb') as source:
    for block in iter(lambda:source.read(1024*1024),b''): digest.update(block)
if digest.hexdigest()!=EXPECTED: raise SystemExit('Expected original archive SHA-256 '+EXPECTED)
args.out.mkdir(parents=True,exist_ok=True)
def save(name,value):
    (args.out/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def stamp(value):
    try: return dt.datetime.fromisoformat(value).replace(tzinfo=dt.timezone.utc).timestamp()
    except (ValueError,TypeError): return None

with tarfile.open(args.archive) as tar:
    members=tar.getmembers()
    names=[m.name for m in members]
    assert len(set(names))==len(names)
    assert all(m.isfile() and not m.name.startswith('/') and '..' not in pathlib.PurePosixPath(m.name).parts for m in members)
    files={m.name:m for m in members}
    manifest=json.load(tar.extractfile(files[RUN+'/export-manifest.json']))
    assert set(files)-{RUN+'/export-manifest.json'}=={f['archive_path'] for f in manifest['files']}
    assert len(manifest['files'])==len(files)-1
    cached={}; hashes={}; sample_summary={}
    for item in manifest['files']:
        name=item['archive_path']; data=tar.extractfile(files[name]).read()
        assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256'],name
        if not name.startswith(PREFIX): continue
        rel=name[len(PREFIX):]; hashes[rel]=item['sha256']
        # Large sampling streams are reduced while reading, with their original hashes retained.
        if rel.startswith('jobs/') and re.fullmatch(r'jobs/[^/]+/[^/]+/events.jsonl',rel):
            samples=[]; positive_oom=[]; cpu=[]; host_peak=0; gpu_used=0; gpu_total=set(); uuids=set()
            for line in data.decode().splitlines():
                event=json.loads(line)
                if event.get('kind')!='sample': continue
                snap=event['data']; samples.append(snap['epoch'])
                usage=snap.get('cgroup_cpu_interval_percent')
                if usage is not None: cpu.append(usage)
                for scope in snap['cgroup'].get('memory.scopes',[]):
                    host_peak=max(host_peak,int(scope.get('memory.peak','0')))
                    if re.search(r'^(?:oom|oom_kill) [1-9]',scope.get('memory.events',''),re.M): positive_oom.append(event['time'])
                if snap.get('gpu',{}).get('exit')==0:
                    for row in csv.reader(snap['gpu']['output'].splitlines()):
                        if len(row)>=3 and row[0].strip().startswith('GPU-'):
                            uuids.add(row[0].strip()); gpu_total.add(float(row[1])); gpu_used=max(gpu_used,float(row[2]))
            sample_summary[rel]=dict(sha256=item['sha256'],samples=len(samples),positive_oom_times=positive_oom,
                mean_cgroup_cpu_percent=statistics.mean(cpu) if cpu else None,
                p95_cgroup_cpu_percent=sorted(cpu)[int(len(cpu)*.95)] if cpu else None,
                peak_host_bytes=host_peak,peak_sampled_gpu_used_mib=gpu_used,
                gpu_memory_total_mib=sorted(gpu_total),gpu_uuids=sorted(uuids))
        elif rel.endswith('.json') or '/' not in rel or rel.startswith('evidence/') or rel.startswith('templates/'):
            cached[rel]=data
        elif rel.endswith(('.scontrol.txt','hardware.txt','local-storage-mount.txt','preflight.txt')):
            cached[rel]=data
    def get(name,default=None):
        return json.loads(cached[name]) if name in cached else default
    cfg=get('config.json'); state=get('state.json'); results=get('results.json')
    assert hashes['capella_audit.sh']==cfg['script_sha256']
    assert cfg['script_sha256']=='1807fe8666b82f0aa386dfdd4932e5cb772acf1585e8ba69cb4e0d2698f87176'
    for name in ['config.json','state.json','coverage.json','REPORT.md','findings.json','results.csv',
                 'training-measurements.json','memory-pressure.json','job-concurrency.json']:
        (args.out/('original-'+name)).write_bytes(cached[name])
    for name,data in cached.items():
        if name.startswith('templates/'):
            target=args.out/name; target.parent.mkdir(exist_ok=True); target.write_bytes(data)

    reviewed=[]; allocations=[]; queue=collections.defaultdict(list); accounting_states=collections.Counter()
    children=[]; launchers=[]; filesystem=[]; io_results=[]; selected={}; resource_snapshots=[]
    for cid,s in state['cases'].items():
        rows=get('jobs/'+cid+'/sacct.json',[]); c=get('cases/'+cid+'.json')
        reviewed.append(dict(case=cid,request=c,controller=s,accounting=rows))
        for a in rows:
            accounting_states[(a['State'],a['ExitCode'])]+=1
            if '.' in a['JobID'] or not stamp(a['Start']): continue
            assert a['State']=='COMPLETED' and a['ExitCode']=='0:0'
            match=re.search(r'(?:^|,)gres/gpu=(\d+)(?:,|$)',a['AllocTRES']); assert match
            gpus=int(match.group(1)); began=stamp(a['Start']); ended=stamp(a['End'])
            queue[gpus].append(began-stamp(a['Submit']))
            allocations.append(dict(case=cid,job=a['JobID'],node=a['NodeList'],start=a['Start'],end=a['End'],
                gpus=gpus,cpus=int(a['AllocCPUS']),requested_memory=a['ReqMem'],
                gpu_hours=(ended-began)*gpus/3600,queue_seconds=queue[gpus][-1]))
    for name,data in cached.items():
        if re.fullmatch(r'jobs/[^/]+/[^/]+/child-[^/]+/result.json',name):
            child=json.loads(data); children.append(dict(file=name,sha256=hashes[name],**child))
        if re.fullmatch(r'jobs/[^/]+/[^/]+/launcher.result.json',name):
            launchers.append(dict(file=name,**json.loads(data)))
        if name.startswith('jobs/') and name.endswith(('.cat.json','.home.json')):
            filesystem.append(dict(file=name,**json.loads(data)))
        if name.endswith('/io.json'): io_results.append(dict(file=name,results=json.loads(data)))
        keep=name in ['controller.log','evidence/partition.txt','evidence/node-sample.txt']
        keep |= name.startswith('evidence/node-')
        keep |= name.endswith('/io.json') or bool(re.fullmatch(r'jobs/f2-c104-[^/]+/[^/]+/[^/]+\.(?:cat|home)\.json',name))
        critical=['p5-S-throughput-long','p5-M-throughput-long','p5-L-throughput-long',
                  'f6-S-four-n12-r2','f6-L-local-pipeline','f6-L-cat-pipeline','f5-ballast4096-n12-r2']
        keep |= any(name.startswith('jobs/'+cid+'/') for cid in critical) and name.endswith(
            ('submission.json','launcher.result.json','hardware.txt','running.scontrol.txt','child-g0-p0/result.json'))
        if keep: selected[name]=dict(sha256=hashes[name],content=data.decode(errors='replace'))
    for line in cached['events.jsonl'].decode().splitlines():
        e=json.loads(line)
        if e['kind']=='node_resources': resource_snapshots.append(e)
    assert len(children)==816 and all(c['ok'] and c['exit_code']==0 and c['binding_verified'] for c in children)
    child_exits=[x for name in cached if name.endswith('/child-exits.json') for x in get(name)]
    assert len(child_exits)==816 and all(x['exit_code']==0 for x in child_exits)
    assert all(x['rw']=='PASS' for x in filesystem)
    assert all(l['ok'] for l in launchers)
    assert not any(x['positive_oom_times'] for x in sample_summary.values())
    hours=math.fsum(a['gpu_hours'] for a in allocations)
    assert abs(hours-results['gpu_hours_observed'])<1e-9
    physical=collections.Counter((c['gpu_name'],c['gpu_total_bytes'],c['torch'],c['cuda']) for c in children)
    matrix=[]
    for model in ['S','M','L']:
        for n in [1,2,3,4,8,12]:
            for mode in ['off','on']:
                cases=[]
                for rep in [1,2]:
                    cid=f'p5-{model}-n{n}-{mode}-r{rep}'
                    st=state['cases'][cid]; lr=get(f'jobs/{cid}/{st["job_id"]}_0/launcher.result.json')
                    assert st['pass'] and lr['ok'] and lr['actual_peak_training_processes']==n
                    cases.append(dict(case=cid,job=st['job_id'],throughput=lr['total_items_per_second'],
                        overlap_seconds=lr['all_training_overlap_seconds']))
                matrix.append(dict(model=model,n=n,mps=mode=='on',repetitions=cases))
    pipelines=[]
    for name in cached:
        if name.endswith('/pipeline-summary.json'):
            p=get(name); rr=p['children']; assert p['ok'] and all(c['stable_seconds']>=3600 for c in rr)
            pipelines.append(dict(file=name,ok=p['ok'],processes=len(rr),minimum_stable_seconds=min(c['stable_seconds'] for c in rr)))
    summary=dict(run_id=RUN,archive_name=args.archive.name,archive_bytes=args.archive.stat().st_size,archive_sha256=EXPECTED,
        archive_members=len(members),verified_payload_files=len(manifest['files']),complete_logs=manifest['complete_logs'],gaps=manifest['gaps'],
        source_commit='74f9a14',script_sha256=cfg['script_sha256'],start_utc=cfg['launch_time'],end_utc=state['finished'],
        duration_seconds=stamp(state['finished'])-stamp(cfg['launch_time']),case_outcomes=dict(collections.Counter(s.get('outcome',s['status']) for s in state['cases'].values())),
        cases=len(reviewed),submitted_cases=sum(bool(s.get('job_id')) for s in state['cases'].values()),allocated_cases=len(allocations),
        allocated_nodes=sorted({a['node'] for a in allocations}),allocated_runtime_failures=0,
        accounting_states=[dict(state=k[0],exit_code=k[1],records=n) for k,n in sorted(accounting_states.items())],
        gpu_hours_observed=hours,reserved_gpu_hour_upper_bound=state['reserved_gpu_hours'],
        actual_peak_gpus=results['global_actual_peak_gpus'],maximum_training_processes=max(l['actual_peak_training_processes'] for l in launchers),
        children=len(children),child_exit_zero=len(child_exits),binding_verified=len(children),mps_verified_launchers=sum(l.get('mps_verified') is True and get('cases/'+l['file'].split('/')[1]+'.json').get('mps',False) for l in launchers),
        physical_devices=[dict(name=k[0],torch_total_bytes=k[1],torch=k[2],cuda=k[3],child_records=n) for k,n in physical.items()],
        filesystem_checks=dict(collections.Counter(('cat' if x['file'].endswith('.cat.json') else 'home')+':'+x['rw'] for x in filesystem)),
        all_scoped_sample_oom_counters_zero=True,
        queue_by_gpus={str(g):dict(allocated=len(v),median_seconds=statistics.median(v),maximum_seconds=max(v)) for g,v in sorted(queue.items())},
        node_matrix=state['node_coverage'],resource_matrix_cases=[cid for cid in state['cases'] if cid.startswith('f3-')],
        candidates=state['candidates'],four_gpu_candidates=state['four_gpu_candidates'],pipelines=pipelines,io=io_results,
        single_gpu_process_matrix=matrix,job_concurrency=get('job-concurrency.json'))
    save('summary.json',summary); save('reviewed-cases.json',reviewed); save('selected-evidence.json',selected)
    save('sampling-summary.json',sample_summary); save('node-resource-snapshots.json',resource_snapshots)
    save('child-summary.json',[{k:c[k] for k in ['file','sha256','child','ok','exit_code','binding_verified','observed_uuid','model','concurrency','mps','threads','workers','stable_seconds','torch_peak_reserved','maxrss_kib']} for c in children])
print(json.dumps({k:summary[k] for k in ['case_outcomes','allocated_cases','gpu_hours_observed','maximum_training_processes','children','filesystem_checks']},ensure_ascii=False,indent=2))
