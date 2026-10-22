#!/usr/bin/env bash
# Standalone synthetic Capella audit. Own workspaces, software, data and jobs only.
set -euo pipefail
unset PYTHONPATH PYTHONHOME VIRTUAL_ENV CONDA_PREFIX LD_LIBRARY_PATH LD_PRELOAD
unset CUDA_VISIBLE_DEVICES CUDA_MPS_PIPE_DIRECTORY CUDA_MPS_LOG_DIRECTORY
unset BASH_ENV ENV PYTHONUSERBASE PIP_CONFIG_FILE PIP_TARGET PIP_PREFIX PIP_USER
export PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
exec /usr/bin/python3 -I - "$0" "$@" <<'CAPELLA_PY'
import argparse, collections, contextlib, csv, datetime as dt, fcntl, hashlib
import json, math, os, pathlib, re, shlex, shutil, signal
import subprocess as sp, sys, tarfile, time, traceback, uuid

SELF = pathlib.Path(sys.argv[1] if len(sys.argv)>1 else sys.argv[0]).resolve()
ARGS = sys.argv[2:]
UTC = dt.timezone.utc
def now(): return dt.datetime.now(UTC).isoformat()
def atomic(p, obj):
    p = pathlib.Path(p); p.parent.mkdir(parents=True, exist_ok=True)
    q = p.with_name(p.name + '.tmp')
    with q.open('w') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False); f.flush(); os.fsync(f.fileno())
    os.replace(q, p)
def read(p, default=None):
    try: return json.loads(pathlib.Path(p).read_text())
    except (OSError, ValueError): return default
def event(root, kind, **kw):
    p = pathlib.Path(root) / 'events.jsonl'; p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(json.dumps(dict(time=now(), epoch=time.time(), kind=kind, **kw), ensure_ascii=False)+'\n')
        f.flush()
def command(argv, timeout=30, cwd=None):
    try:
        env=None
        if str(argv[0])=='sbatch':
            # Inherited SBATCH_* could silently invalidate a one-factor comparison.
            env={k:v for k,v in os.environ.items() if not k.startswith(('SBATCH_','SLURM_'))}
        r = sp.run([str(a) for a in argv], cwd=cwd, text=True, stdout=sp.PIPE,
                   stderr=sp.STDOUT, timeout=timeout,env=env)
        return r.returncode, r.stdout
    except sp.TimeoutExpired as e:
        out=e.stdout or b''
        return 124, (out.decode(errors='replace') if isinstance(out,bytes) else out)+'\nCOMMAND_TIMEOUT\n'
    except OSError as e: return 127, str(e)+'\n'
def capture(path, argv, timeout=30):
    rc, out = command(argv, timeout)
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(path).write_text('$ '+shlex.join([str(a) for a in argv])+'\n'+out[:2_000_000]+f'\nEXIT={rc}\n')
    return rc, out
def field(text, key):
    m=re.search(r'(?:^|\s)'+re.escape(key)+r'=(.*?)(?=\s[A-Za-z][A-Za-z0-9_:/]*=|$)',text,re.S)
    return m.group(1).strip() if m else ''
def stamp(x):
    try: return dt.datetime.fromisoformat(x).replace(tzinfo=UTC).timestamp()
    except (ValueError,TypeError): return None
def number(x, default=0):
    try: return int(x)
    except (ValueError,TypeError): return default
def bounded_excerpt(src, dst):
    try:
        p=pathlib.Path(src)
        if not p.is_file(): raise OSError('not a regular file')
        with p.open('rb') as f:
            start=f.read(32768); size=f.seek(0,2); f.seek(max(32768,size-65536)); end=f.read(65536)
        pathlib.Path(dst).write_bytes(start+(b'\n...BOUNDED EXCERPT...\n' if size>32768 else b'')+end)
    except OSError as e: pathlib.Path(dst).write_text('UNAVAILABLE: '+str(e))

DEFAULT = dict(account='swtest', partition='capella', expected_user='chwu350f',
    workspace_days=3, max_gpus=4, queue_timeout=1800, max_job_seconds=4500, total_seconds=129600,
    gpu_hour_budget=64, poll_seconds=15, sample_seconds=5, short_seconds=90, long_seconds=3600,
    repeats=2, models=['S','M','L'], threads=1, workers=0, tune_threads=[2], tune_workers=[2],
    paired_nodes=[], min_gpu_headroom=.20, min_host_headroom=.20, stages=[1,2,3,4,5,6],
    documented_cpus_per_gpu=14, documented_mem_mib_per_gpu=193250)

BATCH = r'''#!/usr/bin/env bash
set -uo pipefail
root=$1; case_id=$2
key=${SLURM_ARRAY_JOB_ID:-$SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID:-0}
# First instruction after shell setup: also visible if HOME/helper access fails.
printf 'CAPELLA_BATCH_FIRST %s %s %s\n' "$(date -u +%FT%TZ)" "$key" "$(hostname)"
mkdir -p "$root/jobs/$case_id/markers"
printf '%s\n' "$(date -u +%FT%TZ)" > "$root/jobs/$case_id/markers/$key.batch"
export SLURM_EXPORT_ENV=ALL
exec /usr/bin/python3 -I "$root/runtime.py" --batch "$root" "$case_id"
'''


def cgroup_snapshot():
    out={}
    try:
        out['proc_self_cgroup']=pathlib.Path('/proc/self/cgroup').read_text()
        # Resolve the process's own cgroup; never read other users' process trees.
        for line in out['proc_self_cgroup'].splitlines():
            _, controllers, rel=line.split(':',2)
            jid=os.environ.get('SLURM_JOB_ID','')
            own_scope=lambda p: bool(jid) and any(re.fullmatch(r'job[_-]?'+re.escape(jid),part) for part in p.parts)
            if not own_scope(pathlib.Path(rel)):
                out['scope_warning']='Cannot identify own allocation cgroup; broader scopes are not sampled'
                continue
            if not controllers:
                base=pathlib.Path('/sys/fs/cgroup')/rel.lstrip('/')
                for name in ['memory.current','memory.max','memory.peak','memory.events',
                             'cpu.max','cpu.stat','cpuset.cpus.effective','pids.current','pids.max']:
                    try: out[name]=(base/name).read_text().strip()
                    except OSError: pass
                scopes=[]
                for scope in [base]+list(base.parents):
                    if not own_scope(scope): break
                    if str(scope) not in ['/sys/fs/cgroup'] and not str(scope).startswith('/sys/fs/cgroup/'): break
                    values={'path':str(scope)}
                    for name in ['memory.current','memory.max','memory.peak','memory.events']:
                        try: values[name]=(scope/name).read_text().strip()
                        except OSError: pass
                    scopes.append(values)
                out['memory.scopes']=scopes
                finite=[s for s in scopes if s.get('memory.max','').isdigit() and int(s['memory.max'])>0]
                if finite: out['effective_memory']=min(finite,key=lambda s:int(s['memory.max']))
            elif 'memory' in controllers.split(','):
                base=pathlib.Path('/sys/fs/cgroup/memory')/rel.lstrip('/')
                for name in ['memory.usage_in_bytes','memory.limit_in_bytes','memory.max_usage_in_bytes','memory.failcnt','memory.oom_control']:
                    try: out[name]=(base/name).read_text().strip()
                    except OSError: pass
                scopes=[]
                for scope in [base]+list(base.parents):
                    if not own_scope(scope): break
                    if str(scope)!='/sys/fs/cgroup/memory' and not str(scope).startswith('/sys/fs/cgroup/memory/'): break
                    values={'path':str(scope)}
                    for source,target in [('memory.usage_in_bytes','memory.current'),('memory.limit_in_bytes','memory.max'),('memory.max_usage_in_bytes','memory.peak'),('memory.failcnt','memory.failcnt')]:
                        try: values[target]=(scope/source).read_text().strip()
                        except OSError: pass
                    scopes.append(values)
                out['memory.scopes']=scopes
                finite=[s for s in scopes if s.get('memory.max','').isdigit() and 0<int(s['memory.max'])<(1<<60)]
                if finite: out['effective_memory']=min(finite,key=lambda s:int(s['memory.max']))
    except (OSError,ValueError): pass
    return out

def context_snapshot():
    return dict(time=now(), epoch=time.time(), hostname=os.uname().nodename, pid=os.getpid(),
        uid=os.getuid(), gid=os.getgid(), cwd=os.getcwd(), affinity=sorted(os.sched_getaffinity(0)),
        env={k:v for k,v in os.environ.items() if k.startswith(('SLURM_','CUDA_'))
             or k in ['OMP_NUM_THREADS','MKL_NUM_THREADS','OPENBLAS_NUM_THREADS']},
        namespaces={k:os.readlink('/proc/self/ns/'+k) for k in ['mnt','pid','user']},
        cgroup=cgroup_snapshot())

def fs_probe(root, case_id, layer):
    root=pathlib.Path(root); cfg=read(root/'config.json'); c=read(root/'cases'/f'{case_id}.json')
    key=job_key(); out=root/'jobs'/case_id/key; out.mkdir(parents=True,exist_ok=True)
    event(out,layer+'_start'); atomic(out/f'{layer}.context.json',context_snapshot())
    rc=0
    for label,p in [('home',root/'fs'),('cat',pathlib.Path(cfg['cat_dir']))]:
        report={'path':str(p),'layer':layer}
        for tool,args in [('namei',['-l',str(p)]),('findmnt',['-T',str(p)]),('stat',['-c','%a %U %G %u %g %n',str(p)])]:
            code,txt=command([tool]+args,8); report[tool]={'exit':code,'output':txt}
        # Do not mkdir on an unmounted /data/cat: the login controller made this exact directory.
        f=p/f'{case_id}-{key}-{layer}-{uuid.uuid4().hex}.probe'
        try:
            payload=os.urandom(4096)
            with f.open('xb') as h: h.write(payload); h.flush(); os.fsync(h.fileno())
            loaded=f.read_bytes()
            if loaded != payload: raise OSError('readback mismatch')
            report.update(rw='PASS',sha256=hashlib.sha256(loaded).hexdigest())
        except OSError as e: report.update(rw='FAIL',error=str(e)); rc=rc or (71 if label=='home' else 72)
        finally:
            try: f.unlink()
            except FileNotFoundError: pass
            except OSError as e: report['delete_error']=str(e); rc=rc or 73
        atomic(out/f'{layer}.{label}.json',report)
    capture(out/f'{layer}.mountinfo.txt',['cat','/proc/self/mountinfo'])
    args=gpu_command('index,uuid,name,memory.total,driver_version,power.limit')
    if args: capture(out/f'{layer}.hardware.txt',args)
    else: (out/f'{layer}.hardware.txt').write_text('No verified allocation GPU selector; not querying node GPUs')
    capture(out/f'{layer}.job.txt',['scontrol','show','job',os.environ['SLURM_JOB_ID'],'-dd'])
    event(out,layer+'_end',exit_code=rc)
    time.sleep(c.get('hold',0))
    return rc

def job_key():
    return os.environ.get('SLURM_ARRAY_JOB_ID',os.environ.get('SLURM_JOB_ID','local'))+'_'+os.environ.get('SLURM_ARRAY_TASK_ID','0')

def own_processes():
    start=number(os.environ.get('AUDIT_LAUNCHER_PID'),os.getpid()); pending=[start]; owned=set()
    while pending:
        pid=pending.pop()
        if pid in owned: continue
        try:
            if pathlib.Path(f'/proc/{pid}').stat().st_uid!=os.getuid(): continue
            owned.add(pid)
            pending.extend(int(p) for p in pathlib.Path(f'/proc/{pid}/task/{pid}/children').read_text().split())
        except (OSError,ValueError): pass
    return owned

def gpu_command(fields,processes=False,devices=None):
    devices=devices or os.environ.get('AUDIT_GPU_UUIDS') or os.environ.get('SLURM_JOB_GPUS','')
    if not devices or any(not re.fullmatch(r'(?:\d+|GPU-[a-fA-F0-9-]{36})',d) for d in devices.split(',')): return None
    query='--query-compute-apps=' if processes else '--query-gpu='
    return ['nvidia-smi','--id='+devices,query+fields,'--format=csv,noheader,nounits']

def sampler(out, stop, interval):
    out=pathlib.Path(out)
    cfg=read(out.parents[2]/'config.json',{})
    previous_cpu=None
    while not pathlib.Path(stop).exists():
        tick=time.monotonic()
        sample=dict(time=now(),epoch=time.time(),cgroup=cgroup_snapshot())
        cpu_usage=re.search(r'usage_usec\s+(\d+)',sample['cgroup'].get('cpu.stat',''))
        if cpu_usage:
            current_cpu=int(cpu_usage.group(1))
            if previous_cpu:
                sample['cgroup_cpu_interval_percent']=(current_cpu-previous_cpu[0])/1e6/(tick-previous_cpu[1])*100
            previous_cpu=(current_cpu,tick)
        owned=own_processes()
        for name,args in [
            ('gpu',gpu_command('uuid,memory.total,memory.used,utilization.gpu,power.draw')),
            ('gpu_processes',gpu_command('gpu_uuid,pid,used_gpu_memory',processes=True)),
            ('cpu',['ps','-p',','.join(str(p) for p in sorted(owned)),'-o','pid,ppid,pcpu,pmem,rss,nlwp,etimes,comm','--no-headers']),
            ('shm',['df','-B1','/dev/shm'])]:
            code,txt=command(args,4) if args else (1,'No owned resource selector')
            if name=='gpu_processes': txt='\n'.join(l for l in txt.splitlines() if len(l.split(','))>=2 and number(l.split(',')[1].strip(),-1) in owned)
            sample[name]={'exit':code,'output':txt}
        cpurows=[l.split() for l in sample['cpu']['output'].splitlines() if len(l.split())>=8]
        with contextlib.suppress(ValueError):
            sample.update(cpu_total_percent=sum(float(r[2]) for r in cpurows),
                          rss_sum_kib=sum(int(r[4]) for r in cpurows),
                          thread_total=sum(int(r[5]) for r in cpurows),job_process_count=len(cpurows),
                          dataloader_worker_processes=sum(1 for r in cpurows if r[7].startswith('pt_data_worker')))
        if os.environ.get('CUDA_MPS_PIPE_DIRECTORY'):
            code,servers=mps_query(cfg,'get_server_list'); clients=[]; raw={}
            for server in servers.splitlines():
                if server.strip().isdigit():
                    cr,ct=mps_query(cfg,'get_client_list '+server.strip())
                    raw[server.strip()]={'exit':cr,'output':ct}
                    clients.extend(int(x) for x in ct.splitlines() if x.strip().isdigit())
            sample['mps_client_pids']=clients; sample['mps_servers']={'exit':code,'output':servers,'clients':raw}
        event(out,'sample',data=sample)
        time.sleep(max(0,interval-(time.monotonic()-tick)))

def io_test(root,case_id):
    import multiprocessing as mp
    root=pathlib.Path(root); cfg=read(root/'config.json'); out=root/'jobs'/case_id/job_key()
    result=[]
    for label,base in [('home',root/'io'),('cat',pathlib.Path(cfg['cat_dir'])/'io')]:
        base=base/case_id/job_key(); base.mkdir(parents=True,exist_ok=True)
        def child(i):
            try:
                work=base/f'task-{i}'; work.mkdir(exist_ok=True)
                with (work/'run.lock').open('w') as lock:
                    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                    # Independent contender must see the lock and SKIP normally.
                    contender=sp.run([sys.executable,'-c',
                        'import fcntl,sys\nf=open(sys.argv[1],"a")\ntry: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(1)\n',str(work/'run.lock')])
                    if contender.returncode != 1: raise RuntimeError('duplicate lock admitted or flock unavailable')
                    # Completed records permit idempotent skip on repeated invocation.
                    if not (work/'done.json').exists():
                        with (work/'own.jsonl').open('x') as own:
                            for j in range(100):
                                item={'task':i,'record':j}; own.write(json.dumps(item)+'\n')
                                atomic(work/'checkpoint.json',item)
                                with (base/'shared.jsonl').open('a') as shared:
                                    fcntl.flock(shared,fcntl.LOCK_EX); shared.write(json.dumps(item)+'\n'); shared.flush()
                        atomic(work/'done.json',{'records':100})
                    # Simulated restart resumes persisted checkpoint and skips completed output.
                    assert read(work/'checkpoint.json')['record']==99
                    assert read(work/'done.json')['records']==100
                atomic(work/'exit.json',{'exit_code':0})
            except Exception:
                atomic(base/f'child-{i}.error.json',{'error':traceback.format_exc()}); raise
        ctx=mp.get_context('fork'); children=[ctx.Process(target=child,args=(i,)) for i in range(8)]
        for p in children: p.start()
        deadline=time.monotonic()+60
        for p in children: p.join(max(0,deadline-time.monotonic()))
        exits=[]
        for p in children:
            if p.is_alive(): p.terminate(); p.join(5)
            exits.append(p.exitcode)
        # Actually invoke every completed task again; it must skip without appending.
        restarts=[ctx.Process(target=child,args=(i,)) for i in range(8)]
        for p in restarts: p.start()
        deadline=time.monotonic()+60
        for p in restarts: p.join(max(0,deadline-time.monotonic()))
        for p in restarts:
            if p.is_alive(): p.terminate(); p.join(5)
        restart_exits=[p.exitcode for p in restarts]
        atomic(out/f'io-{label}-child-exits.json',{'initial':exits,'restart':restart_exits})
        records=[]; invalid=[]; own=[]
        try:
            for line in (base/'shared.jsonl').read_text().splitlines():
                try:
                    value=json.loads(line)
                    if not isinstance(value,dict) or not isinstance(value.get('task'),int) or not isinstance(value.get('record'),int): raise ValueError('record schema')
                    records.append(value)
                except ValueError as e: invalid.append(str(e))
        except OSError as e: invalid.append(str(e))
        keys={(x['task'],x['record']) for x in records}; expected={(i,j) for i in range(8) for j in range(100)}
        for i in range(8):
            try:
                lines=(base/f'task-{i}'/'own.jsonl').read_text().splitlines(); own.append(len(lines))
                local=[json.loads(x) for x in lines]
                if {(x['task'],x['record']) for x in local}!={(i,j) for j in range(100)}: invalid.append('own file key mismatch: '+str(i))
            except (OSError,ValueError,KeyError,TypeError) as e:
                if len(own)<=i: own.append(-1)
                invalid.append(str(e))
        ok=exits==[0]*8 and restart_exits==[0]*8 and len(records)==800 and keys==expected and own==[100]*8 and not invalid
        result.append(dict(filesystem=label,ok=ok,child_exits=exits,restart_exits=restart_exits,records=len(records),unique=len(keys),
                           duplicates=len(records)-len(keys),missing=len(expected-keys),unexpected=len(keys-expected),invalid_json=len(invalid),errors=invalid[:10],own_counts=own))
        atomic(out/'io.json',result)
    atomic(out/'io.json',result)
    return 0 if all(x['ok'] for x in result) else 75

class BuiltinWorkload:
    """Own synthetic data and CNNs; no imports, inputs or checkpoints from another workload."""
    def describe(self,ctx):
        width,depth={'S':(8,2),'M':(32,4),'L':(64,6)}[ctx['model']]
        return dict(model_id=f'cnn-{width}x{depth}-v1',data_id='random512x3x32x32-seed20261022-v1',batch_size=64,precision='fp32')
    def build(self,ctx):
        import torch
        d=self.describe(ctx); width,depth={'S':(8,2),'M':(32,4),'L':(64,6)}[ctx['model']]
        gen=torch.Generator().manual_seed(ctx['seed'])
        inputs=torch.randn(512,3,32,32,generator=gen); targets=torch.randint(0,10,(512,),generator=gen)
        root=pathlib.Path(ctx['output_dir']); root.mkdir(parents=True,exist_ok=True)
        lock=(root/'run.lock').open('w'); fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        atomic(root/'data.json',dict(d,seed=ctx['seed'],samples=512))
        layers=[]; channels=3
        for _ in range(depth):
            layers.extend([torch.nn.Conv2d(channels,width,3,padding=1),torch.nn.ReLU()]); channels=width
        layers.extend([torch.nn.AdaptiveAvgPool2d(1),torch.nn.Flatten(),torch.nn.Linear(width,10)])
        model=torch.nn.Sequential(*layers).cuda(); optimizer=torch.optim.AdamW(model.parameters(),lr=1e-3)
        args=dict(batch_size=64,shuffle=True,num_workers=ctx['workers'],pin_memory=True,
                  generator=torch.Generator().manual_seed(ctx['seed']))
        if ctx['workers']: args.update(multiprocessing_context='spawn',persistent_workers=True)
        loader=torch.utils.data.DataLoader(torch.utils.data.TensorDataset(inputs,targets),**args)
        return dict(model=model,optimizer=optimizer,loader=loader,iterator=iter(loader),
                    inputs=inputs[:64].cuda(),targets=targets[:64].cuda(),step=0,lock=lock)
    def train_step(self,ctx,state):
        import torch
        try: x,y=next(state['iterator'])
        except StopIteration: state['iterator']=iter(state['loader']); x,y=next(state['iterator'])
        x=x.cuda(non_blocking=True); y=y.cuda(non_blocking=True)
        state['model'].train(); state['optimizer'].zero_grad(set_to_none=True)
        loss=torch.nn.functional.cross_entropy(state['model'](x),y)
        if not torch.isfinite(loss).item(): raise RuntimeError('nonfinite synthetic loss')
        loss.backward(); state['optimizer'].step(); state['step']+=1
        return int(y.numel())
    def validate(self,ctx,state):
        import torch
        state['model'].eval()
        with torch.no_grad():
            pred=state['model'](state['inputs']); loss=torch.nn.functional.cross_entropy(pred,state['targets'])
        state['model'].train()
        return dict(ok=bool(torch.isfinite(loss).item()),loss=float(loss.item()))
    def save_load(self,ctx,state):
        import torch
        root=pathlib.Path(ctx['output_dir']); checkpoint=root/'checkpoint.pt'; tmp=root/'checkpoint.tmp'
        expected={k:v.detach().clone() for k,v in state['model'].state_dict().items()}
        torch.save(dict(model=state['model'].state_dict(),optimizer=state['optimizer'].state_dict(),step=state['step']),tmp)
        os.replace(tmp,checkpoint)
        with torch.no_grad(): next(state['model'].parameters()).add_(1)
        restored=torch.load(checkpoint,map_location='cuda',weights_only=True)
        state['model'].load_state_dict(restored['model']); state['optimizer'].load_state_dict(restored['optimizer'])
        ok=restored['step']==state['step'] and all(torch.equal(v,state['model'].state_dict()[k]) for k,v in expected.items())
        atomic(root/'resume.json',{'ok':ok,'step':restored['step']})
        return dict(ok=ok,checkpoint=str(checkpoint),restored_step=restored['step'])

def normalize_uuid(value):
    text=str(value)
    m=re.fullmatch(r'(?:GPU-)?([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})',text)
    return 'GPU-'+m.group(1).lower() if m else ''

def cuda_uuid(torch,index):
    value=normalize_uuid(getattr(torch.cuda.get_device_properties(index),'uuid',''))
    if value: return value
    # Older PyTorch versions omit .uuid. Read the CUDA driver's UUID, never map
    # an ordinal to nvidia-smi's potentially different numbering.
    import ctypes
    driver=ctypes.CDLL('libcuda.so.1')
    def check(code):
        if code: raise RuntimeError('CUDA driver UUID query failed: '+str(code))
    check(driver.cuInit(0)); count=ctypes.c_int(); check(driver.cuDeviceGetCount(ctypes.byref(count)))
    if count.value!=torch.cuda.device_count(): raise RuntimeError('Driver/PyTorch visible device count mismatch')
    device=ctypes.c_int(); check(driver.cuDeviceGet(ctypes.byref(device),index))
    buf=(ctypes.c_ubyte*16)(); fn=getattr(driver,'cuDeviceGetUuid_v2',driver.cuDeviceGetUuid)
    check(fn(ctypes.byref(buf),device)); return 'GPU-'+str(uuid.UUID(bytes=bytes(buf)))

def mps_query(cfg,text):
    try:
        r=sp.run(['nvidia-cuda-mps-control'],input=text+'\n',text=True,
                 timeout=5,stdout=sp.PIPE,stderr=sp.STDOUT)
        return r.returncode,r.stdout
    except (OSError,sp.TimeoutExpired) as e: return 124,str(e)

def training_barrier(out):
    atomic(out/'ready.json',{'time':now()})
    barrier=out.parent/'training-go.json'; deadline=time.monotonic()+240
    while not barrier.exists():
        if time.monotonic()>deadline: raise TimeoutError('concurrency warmup barrier')
        time.sleep(.1)

def torch_child(root,case_id,child_id,device_uuid):
    root=pathlib.Path(root); cfg=read(root/'config.json'); c=read(root/'cases'/f'{case_id}.json')
    out=root/'jobs'/case_id/job_key()/f'child-{child_id}'; out.mkdir(parents=True,exist_ok=True)
    event(out,'python_start'); atomic(out/'context.json',context_snapshot())
    result=dict(ok=False,child=child_id,requested_uuid=device_uuid,environment=c['environment'],
                model=c.get('model','ENV_SMOKE'),concurrency=c.get('concurrency',1),mps=c.get('mps',False),
                threads=c.get('threads',cfg['threads']),workers=c.get('workers',cfg['workers']))
    begin=time.monotonic()
    try:
        import torch
        import random
        random.seed(20261022); torch.manual_seed(20261022); torch.cuda.manual_seed_all(20261022)
        with contextlib.suppress(ImportError):
            import numpy as np
            np.random.seed(20261022)
        torch.set_num_threads(result['threads']); torch.set_num_interop_threads(1)
        result.update(python=sys.version,torch=torch.__version__,cuda=torch.version.cuda,
                      visible_devices=os.environ.get('CUDA_VISIBLE_DEVICES'),device_count=torch.cuda.device_count())
        event(out,'import_complete',**{k:result[k] for k in ['python','torch','cuda','device_count']})
        if torch.cuda.device_count()!=1: raise RuntimeError('child must see exactly one assigned GPU')
        torch.cuda.set_device(0); props=torch.cuda.get_device_properties(0)
        observed=cuda_uuid(torch,0)
        result.update(observed_uuid=observed,gpu_name=props.name,gpu_total_bytes=props.total_memory)
        # PyTorch UUID support varies. No matching UUID means unverified binding, never infer from cuda:0.
        canonical=lambda x: re.sub('[^a-f0-9]','',x.lower().removeprefix('gpu-'))
        result['binding_verified']=bool(observed) and canonical(observed)==canonical(device_uuid)
        x=torch.ones((32,32),device='cuda'); y=x@x; torch.cuda.synchronize()
        assert y[0,0].item()==32
        event(out,'cuda_initialized',uuid=observed,requested_uuid=device_uuid,binding_verified=result['binding_verified'])
        torch.cuda.reset_peak_memory_stats()
        if c['kind']=='smoke':
            net=torch.nn.Sequential(torch.nn.Linear(128,128),torch.nn.ReLU(),torch.nn.Linear(128,16)).cuda()
            opt=torch.optim.Adam(net.parameters()); data=torch.randn(64,128,device='cuda')
            training_barrier(out); started=time.monotonic(); steps=0; result['stable_start_epoch']=time.time()
            event(out,'stable_training_start',synthetic=True)
            while time.monotonic()-started<20:
                opt.zero_grad(set_to_none=True); loss=net(data).square().mean(); loss.backward(); opt.step()
                steps+=1
            torch.cuda.synchronize(); result['stable_end_epoch']=time.time()
            event(out,'training_complete',synthetic=True,steps=steps)
            net.eval()
            with torch.no_grad(): net(data)
            torch.save(net.state_dict(),out/'smoke.pt'); net.load_state_dict(torch.load(out/'smoke.pt',map_location='cuda',weights_only=True))
            result.update(items=64*steps,steps=steps,stable_seconds=time.monotonic()-started,synthetic=True)
        else:
            workload=BuiltinWorkload()
            artifacts=pathlib.Path(cfg['cat_dir'])/'training'/case_id/job_key()/child_id
            ctx=dict(model=c['model'],output_dir=str(artifacts/'results'),scratch_dir=os.environ['TMPDIR'],
                     cache_dir=os.environ['XDG_CACHE_HOME'],workers=result['workers'],threads=result['threads'],
                     seed=20261022,device='cuda:0',physical_uuid=device_uuid,
                     run_id=cfg['run_id'],child=child_id,seconds=c['seconds'])
            for k in ['output_dir','scratch_dir','cache_dir']: pathlib.Path(ctx[k]).mkdir(parents=True,exist_ok=True)
            # Fully embedded synthetic workload, with fixed model/data/batch/seed.
            description=workload.describe(ctx)
            if not isinstance(description,dict) or not all(k in description for k in ['model_id','data_id','batch_size','precision']):
                raise ValueError('describe must return model_id, data_id, batch_size, precision')
            result['workload']=description
            state=workload.build(ctx)
            for _ in range(5): workload.train_step(ctx,state)
            torch.cuda.synchronize(); event(out,'warmup_complete')
            training_barrier(out)
            started=time.monotonic(); items=steps=0; cycle=started; result['stable_start_epoch']=time.time()
            def validate_checkpoint():
                validation=workload.validate(ctx,state); checkpoint=workload.save_load(ctx,state)
                if not isinstance(validation,dict) or validation.get('ok') is not True: raise RuntimeError('validation contract failed')
                if not isinstance(checkpoint,dict) or checkpoint.get('ok') is not True: raise RuntimeError('checkpoint roundtrip contract failed')
                atomic(out/'last-validation.json',validation); atomic(out/'last-checkpoint.json',checkpoint)
            event(out,'stable_training_start')
            while time.monotonic()-started < c['seconds']:
                n=workload.train_step(ctx,state)
                if not isinstance(n,int) or n<=0: raise ValueError('train_step must return positive item count')
                items+=n; steps+=1
                if time.monotonic()-cycle>=300:
                    validate_checkpoint()
                    event(out,'validation_checkpoint_cycle',steps=steps); cycle=time.monotonic()
            torch.cuda.synchronize(); elapsed=time.monotonic()-started
            result['stable_end_epoch']=time.time()
            event(out,'stable_training_end',items=items,steps=steps,seconds=elapsed)
            validate_checkpoint(); event(out,'validation_complete'); event(out,'save_load_complete')
            result.update(items=items,steps=steps,stable_seconds=elapsed,items_per_second=items/elapsed,synthetic=True)
        torch.cuda.synchronize()
        result.update(ok=True,torch_peak_allocated=torch.cuda.max_memory_allocated(),
                      torch_peak_reserved=torch.cuda.max_memory_reserved())
    except BaseException as e:
        result.update(error_type=type(e).__name__,error=str(e),traceback=traceback.format_exc())
        event(out,'exception',error_type=type(e).__name__,error=str(e))
    finally:
        import resource
        with contextlib.suppress(Exception):
            import torch
            if torch.cuda.is_initialized():
                result.update(torch_peak_allocated=torch.cuda.max_memory_allocated(),torch_peak_reserved=torch.cuda.max_memory_reserved())
        result.update(duration=time.monotonic()-begin,maxrss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                      cgroup=cgroup_snapshot(),exit_code=0 if result['ok'] else 1)
        atomic(out/'result.json',result); event(out,'process_exit',exit_code=result['exit_code'])
    return result['exit_code']

def run_training(root,case_id):
    root=pathlib.Path(root); cfg=read(root/'config.json'); c=read(root/'cases'/f'{case_id}.json')
    out=root/'jobs'/case_id/job_key(); out.mkdir(parents=True,exist_ok=True)
    atomic(out/'launcher.context.json',context_snapshot())
    capture(out/'cpu.txt',['lscpu'])
    # Ask CUDA/PyTorch in the selected environment for allocation-visible UUIDs.
    # nvidia-smi -L can expose all node devices and is NOT an allocation selector.
    env_prefix=environment_prefix(root,c)
    rc,txt=command(env_prefix+[str(root/'runtime.py'),'--devices'],60)
    (out/'device_discovery.txt').write_text(txt)
    m=re.search(r'AUDIT_UUIDS=(\[[^\n]*\])',txt)
    devices=json.loads(m.group(1)) if m else []
    if rc or len(devices)!=c['gpus'] or any(not x.startswith('GPU-') for x in devices) or len(set(devices))!=len(devices):
        atomic(out/'launcher.result.json',dict(ok=False,error='Cannot verify allocation-visible physical UUIDs',exit_code=76)); return 76
    os.environ.update(AUDIT_GPU_UUIDS=','.join(devices),AUDIT_LAUNCHER_PID=str(os.getpid()))
    capture(out/'hardware.txt',gpu_command('index,uuid,name,memory.total,driver_version,power.limit'))
    stop=out/'sampler.stop'; stop.unlink(missing_ok=True)
    sample_log=(out/'sampler.log').open('w')
    monitor=None
    procs=[]; logs=[]; mps_started=False; pipe=None
    try:
        if c.get('mps'):
            # Private server, only allocation-visible UUIDs; never change compute mode or stop an existing server.
            pipe=pathlib.Path('/tmp')/('ca-mps-'+uuid.uuid4().hex[:16]); pipe.mkdir(mode=0o700)
            os.environ.update(CUDA_MPS_PIPE_DIRECTORY=str(pipe),CUDA_MPS_LOG_DIRECTORY=str(out/'mps'))
            os.environ['CUDA_VISIBLE_DEVICES']=','.join(devices)
            rc,txt=command(['nvidia-cuda-mps-control','-d'],20); (out/'mps-start.txt').write_text(txt)
            if rc: raise RuntimeError('private MPS server failed to start')
            mps_started=True
        monitor=sp.Popen(['/usr/bin/python3','-I',str(root/'runtime.py'),'--sample',str(out),str(stop),str(cfg['sample_seconds'])],stdout=sample_log,stderr=sp.STDOUT)
        started=time.monotonic()
        for g,device in enumerate(devices):
            for n in range(c.get('concurrency',1)):
                child=f'g{g}-p{n}'; env=os.environ.copy(); env['CUDA_VISIBLE_DEVICES']=device
                threads=str(c.get('threads',cfg['threads']))
                work=pathlib.Path(cfg['cat_dir'])/'processes'/case_id/job_key()/child
                env.update(OMP_NUM_THREADS=threads,MKL_NUM_THREADS=threads,OPENBLAS_NUM_THREADS=threads,
                           NUMEXPR_NUM_THREADS=threads,PYTHONUNBUFFERED='1',PYTHONDONTWRITEBYTECODE='1',
                           TMPDIR=str(work/'tmp'),XDG_CACHE_HOME=str(work/'cache'),
                           TORCH_HOME=str(work/'cache'/'torch'),HF_HOME=str(work/'cache'/'hf'),
                           MPLCONFIGDIR=str(work/'cache'/'mpl'))
                pathlib.Path(env['TMPDIR']).mkdir(parents=True); pathlib.Path(env['XDG_CACHE_HOME']).mkdir(parents=True)
                argv=environment_prefix(root,c,env)+[str(root/'runtime.py'),'--torch-child',str(root),case_id,child,device]
                f=(out/f'{child}.log').open('w'); logs.append(f)
                event(out,'child_spawn',child=child,uuid=device,argv=argv)
                p=sp.Popen(argv,stdout=f,stderr=sp.STDOUT,env=env); procs.append((child,p))
        if c['kind'] in ['train','smoke','pipeline']:
            deadline=time.monotonic()+220
            while not all((out/f'child-{child}'/'ready.json').exists() for child,p in procs):
                if any(p.poll() is not None for child,p in procs): raise RuntimeError('child exited before warmup barrier')
                if time.monotonic()>deadline: raise TimeoutError('children did not reach warmup barrier within setup budget')
                time.sleep(.2)
            atomic(out/'training-go.json',{'epoch':time.time(),'children':len(procs)})
        exits=[]
        # Every child is reaped and its own exit status retained.
        for child,p in procs: exits.append(dict(child=child,pid=p.pid,exit_code=p.wait()))
        elapsed=time.monotonic()-started
        results=[read(out/f'child-{child}'/'result.json',{}) for child,p in procs]
        training_intervals=[(r['stable_start_epoch'],r['stable_end_epoch']) for r in results if 'stable_start_epoch' in r and 'stable_end_epoch' in r]
        ev=sorted([(a,1) for a,b in training_intervals]+[(b,-1) for a,b in training_intervals]); active=peak=0
        for _,delta in ev: active+=delta; peak=max(peak,active)
        overlap=max(0,min(b for a,b in training_intervals)-max(a for a,b in training_intervals)) if training_intervals else 0
        mps_verified=not c.get('mps')
        if c.get('mps'):
            seen=set()
            for line in (out/'events.jsonl').read_text().splitlines():
                try:
                    sample=json.loads(line)
                    seen.update(sample.get('data',{}).get('mps_client_pids',[]))
                except ValueError: pass
            mps_verified=all(p.pid in seen for child,p in procs)
        same_workload=len({json.dumps(x.get('workload'),sort_keys=True) for x in results})==1
        concurrency_verified=peak==len(procs) and overlap>=c.get('seconds',20)*.90
        ok=all(x['exit_code']==0 for x in exits) and all(x.get('ok') and x.get('binding_verified') for x in results) and mps_verified and same_workload and concurrency_verified
        atomic(out/'launcher.result.json',dict(ok=ok,children=exits,wall_seconds=elapsed,
            total_items=sum(x.get('items',0) for x in results),
            total_items_per_second=sum(x.get('items',0) for x in results)/elapsed,
            exit_code=0 if ok else 77,devices=devices,mps_verified=mps_verified,
            actual_peak_training_processes=peak,all_training_overlap_seconds=overlap,same_workload=same_workload))
        return 0 if ok else 77
    except BaseException:
        atomic(out/'launcher.error.json',{'traceback':traceback.format_exc()}); return 78
    finally:
        for child,p in procs:
            if p.poll() is None: p.terminate()
        for child,p in procs:
            try: p.wait(timeout=10)
            except sp.TimeoutExpired: p.kill(); p.wait()
        atomic(out/'child-exits.json',[{'child':child,'pid':p.pid,'exit_code':p.returncode} for child,p in procs])
        for f in logs: f.close()
        stop.touch()
        if monitor:
            try: monitor.wait(timeout=30)
            except sp.TimeoutExpired: monitor.terminate(); monitor.wait()
        sample_log.close()
        if mps_started:
            # Environment points only at this job's private pipe.
            try: sp.run(['nvidia-cuda-mps-control'],input='quit\n',text=True,timeout=10,stdout=sp.PIPE,stderr=sp.STDOUT)
            except (OSError,sp.TimeoutExpired): pass
        if pipe:
            with contextlib.suppress(OSError): shutil.rmtree(pipe)

def prepare_runtime(root):
    root=pathlib.Path(root); target=root/'.venv'; python=target/'bin'/'python3'
    if (root/'runtime-ready.json').exists() and python.is_file(): return True
    rc,_=capture(root/'venv-create.log',['/usr/bin/python3','-I','-m','venv','--copies',str(target)],120)
    if rc: return False
    rc,_=capture(root/'pip-install.log',[str(python),'-I','-m','pip','--isolated','--disable-pip-version-check',
        'install','--no-cache-dir','--index-url','https://download.pytorch.org/whl/cu124','torch==2.5.1'],1200)
    if rc: return False
    rc,versions=capture(root/'packages.txt',[str(python),'-I','-m','pip','--isolated','freeze'],60)
    if rc: return False
    atomic(root/'runtime-ready.json',{'python':str(python),'torch':'2.5.1','cuda_wheel':'cu124','time':now()})
    return True

def environment_prefix(root,c,env=None):
    return [str(pathlib.Path(root)/'.venv'/'bin'/'python3'),'-I']

def batch(root,case_id):
    root=pathlib.Path(root); cfg=read(root/'config.json'); c=read(root/'cases'/f'{case_id}.json')
    out=root/'jobs'/case_id/job_key(); out.mkdir(parents=True,exist_ok=True)
    event(out,'batch_start'); atomic(out/'batch.context.json',context_snapshot())
    capture(out/'job-start.txt',['scontrol','show','job',os.environ['SLURM_JOB_ID'],'-dd'])
    mode=c['mode']; exits=[]
    if c['kind']=='fs':
        if mode in ['direct','both']: exits.append({'layer':'batch','exit_code':fs_probe(root,case_id,'batch')})
        if mode in ['step','both']:
            args=['srun','--ntasks=1','--cpus-per-task='+str(c['cpus'])]
            if c.get('gpt'): args+=['--gpus-per-task='+str(c['gpus'])]
            args+=['/usr/bin/python3','-I',str(root/'runtime.py'),'--fs',str(root),case_id,'step']
            event(out,'step_launch',argv=args)
            rc,txt=capture(out/'srun.log',args,c['wall_seconds']-10); exits.append({'layer':'step','exit_code':rc})
        rc=next((x['exit_code'] for x in exits if x['exit_code']),0)
    else:
        args=['/usr/bin/python3','-I',str(root/'runtime.py'),'--payload',str(root),case_id]
        if mode=='step': args=['srun','--ntasks=1','--cpus-per-task='+str(c['cpus']),'--gpus-per-task='+str(c['gpus'])]+args
        event(out,'step_launch' if mode=='step' else 'payload_launch',argv=args)
        rc,txt=capture(out/'payload.log',args,c['wall_seconds']-10); exits.append({'layer':mode,'exit_code':rc})
    atomic(out/'batch.result.json',{'exit_code':rc,'layers':exits}); event(out,'batch_end',exit_code=rc)
    return rc

def pipeline(root,case_id):
    # Full self-owned synthetic prepare/train/validate/checkpoint/aggregate path.
    rc=run_training(root,case_id)
    root=pathlib.Path(root); out=root/'jobs'/case_id/job_key()
    results=[read(p,{}) for p in out.glob('child-*/result.json')]
    ok=rc==0 and bool(results) and all(r.get('ok') and r.get('stable_seconds',0)>=3600 for r in results)
    summary={'ok':ok,'synthetic':True,'children':results,'time':now()}
    atomic(out/'pipeline-summary.json',summary)
    if read(out/'pipeline-summary.json')!=summary: return 79
    return 0 if ok else 79

class Controller:
    def __init__(self,root):
        self.root=pathlib.Path(root); self.cfg=read(self.root/'config.json')
        if self.cfg.get('schema_version')!=2: raise RuntimeError('Only standalone v2 run directories are supported')
        for name in ['tmp','cache']: (self.root/name).mkdir(exist_ok=True)
        os.environ.update(TMPDIR=str(self.root/'tmp'),XDG_CACHE_HOME=str(self.root/'cache'))
        self.state=read(self.root/'state.json',dict(created=time.time(),reserved_gpu_hours=0,cases={},notes=[]))
        self.stop=False
    def save(self): atomic(self.root/'state.json',self.state)
    def note(self,text):
        print(now(),text,flush=True); self.state['notes'].append({'time':now(),'text':text}); self.save()
    def snapshot(self):
        d=self.root/'evidence'; d.mkdir(exist_ok=True)
        # Site metadata only. No historical/current job inventory is requested.
        for name,args in [
            ('partition',['scontrol','show','partition',self.cfg['partition']]),
            ('licenses',['scontrol','show','licenses']),
            ('qos',['sacctmgr','-nP','show','qos','normal','format=Name,Flags,MaxWall,MaxTRESPU,MaxTRESPJ']),
            ('identity',['id']),('hostname',['hostname','-f']),('slurm-version',['scontrol','--version'])]:
            capture(d/(name+'.txt'),args)
        fmt='JobIDRaw,JobID,JobName,State,ExitCode,Submit,Eligible,Start,End,ElapsedRaw,NodeList,ReqCPUS,AllocCPUS,ReqMem,ReqTRES,AllocTRES,MaxRSS,TotalCPU,Reason'
        rc,available=command(['sacct','--helpformat'])
        fields=[f for f in fmt.split(',') if f.lower() in available.lower().split()]
        if rc or not all(x in fields for x in ['JobIDRaw','JobID','State','Start','End','ReqTRES','AllocTRES']):
            raise RuntimeError('Required accounting fields unavailable')
        self.cfg['sacct_fields']=fields; atomic(self.root/'config.json',self.cfg)
        self.state['evidence_complete']=True; self.save()

    def case(self,id,**kw):
        c=dict(id=id,stage=2,kind='fs',gpus=1,cpus=1,mem_mib=1024,exclusive=False,
               mode='both',chdir='/tmp',log='home',license='default',ntpn=False,gpt=False,
               array=1,throttle=1,wall_seconds=300,hold=0)
        c.update(kw); c['wall_seconds']=min(math.ceil(c['wall_seconds']/60)*60,self.cfg['max_job_seconds'])
        return c
    def guard(self,c):
        if (self.root/'stop.request').exists(): self.stop=True
        if self.stop: return 'CONTROLLER_STOPPED'
        if time.time()-self.state['created']>=self.cfg['total_seconds']: return 'TOTAL_WALL_BUDGET'
        maxgpu=min(c['array'],c['throttle'])*c['gpus']
        if maxgpu>self.cfg['max_gpus']: return 'GPU_CONCURRENCY_LIMIT'
        if c['cpus']>c['gpus']*self.cfg['documented_cpus_per_gpu']: return 'DOCUMENTED_CPU_CAP'
        if c['mem_mib']>c['gpus']*self.cfg['documented_mem_mib_per_gpu']: return 'DOCUMENTED_MEMORY_CAP'
        if c['exclusive'] and c['gpus']!=4: return 'EXCLUSIVE_REQUIRES_ALL_GPU'
        cost=c['array']*c['gpus']*c['wall_seconds']/3600
        if self.state['reserved_gpu_hours']+cost>self.cfg['gpu_hour_budget']: return 'GPU_HOUR_RESERVATION_BUDGET'
        return ''
    def query(self,jid):
        fields=self.cfg['sacct_fields']
        rc,txt=command(['sacct','-nP','-j',str(jid),'--format='+','.join(fields)],30)
        if rc: return None
        return [dict(zip(fields,line.split('|'))) for line in txt.splitlines() if line.strip()]
    def reconcile(self,c,s):
        # Persisted intent precedes sbatch. Recover the crash gap by unique Comment/JobName.
        name=c['job_name']; matches=set()
        rc,txt=command(['squeue','-h','-u',os.environ['USER'],'--name='+name,'-o','%A'],20)
        if rc: raise RuntimeError('Cannot reconcile squeue; refusing duplicate submission')
        matches.update(x.strip() for x in txt.splitlines() if x.strip().isdigit())
        start=dt.datetime.fromtimestamp(s['submit_epoch']-60,UTC).strftime('%Y-%m-%dT%H:%M:%S')
        rc,txt=command(['sacct','-nPX','-u',os.environ['USER'],'-S',start,'--name='+name,'--format=JobID'],30)
        if rc: raise RuntimeError('Cannot reconcile sacct; refusing duplicate submission')
        matches.update(re.split('[_.]',x.strip())[0] for x in txt.splitlines() if re.match(r'^\d',x.strip()))
        if len(matches)==1: s['job_id']=matches.pop(); s['reconciled']=True; s['status']='ACTIVE'; self.save()
        elif len(matches)>1: raise RuntimeError('Ambiguous submit intent; inspect '+name)
        else:
            # Accounting can lag after acceptance. Never automatically retry an uncertain submit.
            s['status']='SUBMISSION_UNCERTAIN'; self.save()
            raise RuntimeError('Uncertain previous sbatch; no matching record. No resubmission: '+name)
    def cancel(self,jid,c,reason):
        # Exact registry + UID + unique Comment. No scancel -u, partitions, names or historical jobs.
        s=self.state['cases'][c['id']]
        if str(s.get('job_id'))!=str(jid): raise RuntimeError('Cancellation registry mismatch')
        rc,txt=command(['scontrol','show','job',str(jid)],20)
        if rc: return False
        uid=field(txt,'UserId'); comment=field(txt,'Comment')
        if not uid.endswith('('+str(os.getuid())+')') or comment!=c['comment']:
            raise RuntimeError('Refusing cancellation: owner/comment mismatch '+str(jid))
        rc,txt=command(['scancel',str(jid)],20)
        event(self.root,'cancel',job_id=jid,reason=reason,exit_code=rc)
        s['cancel_reason']=reason; self.save(); return rc==0

    def cancel_element(self,element,c,reason):
        s=self.state['cases'][c['id']]; parent=str(s.get('job_id',''))
        if not re.fullmatch(re.escape(parent)+r'_\d+',element): raise RuntimeError('Array cancellation registry mismatch')
        rc,txt=command(['scontrol','show','job',element],15)
        if rc: return False
        if field(txt,'Comment')!=c['comment'] or not field(txt,'UserId').endswith('('+str(os.getuid())+')'):
            raise RuntimeError('Refusing array cancellation: owner/comment mismatch')
        rc,txt=command(['scancel',element],15)
        event(self.root,'cancel',job_id=element,reason=reason,exit_code=rc)
        if rc==0 and reason=='QUEUE_TIMEOUT':
            elements=s.setdefault('queue_timed_out_elements',[])
            if element not in elements: elements.append(element)
        self.save(); return rc==0

    def execute(self,c): return self.execute_group([c])[0]
    def execute_group(self,cases):
        # Groups are the ONLY place independent submissions overlap. Reserve every member first.
        if sum(min(c['array'],c['throttle'])*c['gpus'] for c in cases)>self.cfg['max_gpus']:
            for c in cases:
                atomic(self.root/'cases'/f'{c["id"]}.json',c)
                self.state['cases'].setdefault(c['id'],{'status':'SKIPPED','reason':'GPU_CONCURRENCY_LIMIT'})
            self.save(); return [False]*len(cases)
        live=[]; results=[]
        for c in cases:
            id=c['id']; c['job_name']='ca_'+self.cfg['run_id'][-16:]+'_'+hashlib.sha256(id.encode()).hexdigest()[:10]
            c['comment']='capella-audit:'+self.cfg['run_id']+':'+id
            atomic(self.root/'cases'/f'{id}.json',c)
            d=self.root/'jobs'/id; d.mkdir(parents=True,exist_ok=True)
            s=self.state['cases'].get(id)
            if s and s.get('status')=='DONE': results.append(s.get('pass',False)); continue
            if s and s.get('status')=='SUBMISSION_UNCERTAIN': self.reconcile(c,s)
            if s and s.get('status') in ['SKIPPED','REJECTED']:
                results.append(False); continue
            if s and not s.get('job_id'): self.reconcile(c,s)
            if not s:
                reason=self.guard(c)
                if reason:
                    self.state['cases'][id]={'status':'SKIPPED','reason':reason}; self.save(); results.append(False); continue
                logs=(self.root/'slurm') if c['log']=='home' else pathlib.Path(self.cfg['cat_dir'])/'slurm'
                args=['sbatch','--parsable','--no-requeue','--account='+self.cfg['account'],
                    '--partition='+self.cfg['partition'],'--nodes=1','--ntasks=1',
                    '--cpus-per-task='+str(c['cpus']),'--gres=gpu:'+str(c['gpus']),
                    '--mem='+str(c['mem_mib'])+'M','--time='+str(math.ceil(c['wall_seconds']/60)),
                    '--chdir='+c['chdir'],'--output='+str(logs/(id+'-%A_%a.out')),
                    '--error='+str(logs/(id+'-%A_%a.err')),'--job-name='+c['job_name'],
                    '--comment='+c['comment'],'--export=HOME='+str(pathlib.Path.home())+',PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin,LANG=C.UTF-8,TZ=UTC,PYTHONNOUSERSITE=1,PYTHONDONTWRITEBYTECODE=1']
                if c['license']!='default': args+=['--licenses='+c['license']]
                if c['ntpn']: args+=['--ntasks-per-node=1']
                if c['gpt']: args+=['--gpus-per-task='+str(c['gpus'])]
                if c['exclusive']: args+=['--exclusive']
                if c.get('node'): args+=['--nodelist='+c['node']]
                if c['array']>1: args+=['--array=0-'+str(c['array']-1)+'%'+str(c['throttle'])]
                args+=[str(self.root/'batch.sh'),str(self.root),id]
                atomic(d/'submission.json',{'argv':args,'shell':shlex.join(args),'time':now(),'config':c})
                rc,txt=capture(d/'preflight.txt',[args[0],'--test-only']+args[1:],30)
                if rc:
                    self.state['cases'][id]={'status':'REJECTED','reason':'SITE_TEST_ONLY_REJECTED','output':txt}; self.save(); results.append(False); continue
                s={'status':'SUBMIT_INTENT','submit_epoch':time.time(),'reserved_gpu_hours':c['array']*c['gpus']*c['wall_seconds']/3600}
                self.state['reserved_gpu_hours']+=s['reserved_gpu_hours']; self.state['cases'][id]=s; self.save()
                rc,txt=capture(d/'submit.txt',args,45)
                m=re.fullmatch(r'\s*(\d+)(?:;[^\s]+)?\s*',txt)
                if not m:
                    s['submission_returncode']=rc; self.save(); self.reconcile(c,s)
                else: s['job_id']=m.group(1); s['status']='ACTIVE'; self.save()
                self.note(id+' submitted '+s['job_id'])
            live.append((c,s))
        terminal={'BOOT_FAIL','CANCELLED','COMPLETED','DEADLINE','FAILED','NODE_FAIL','OUT_OF_MEMORY','PREEMPTED','REVOKED','TIMEOUT','SPECIAL_EXIT'}
        while live:
            if (self.root/'stop.request').exists(): self.stop=True
            remaining=[]
            for c,s in live:
                jid=s['job_id']; d=self.root/'jobs'/c['id']
                # Capture scontrol while jobs are still in slurmctld, including queued records.
                rc,txt=command(['scontrol','show','job',jid,'-dd'],20)
                if rc==0:
                    atomic(d/'latest.scontrol.json',{'time':now(),'text':txt})
                    if not (d/'first.scontrol.txt').exists(): (d/'first.scontrol.txt').write_text(txt)
                    if 'JobState=RUNNING' in txt and not (d/'running.scontrol.txt').exists(): (d/'running.scontrol.txt').write_text(txt)
                rows=self.query(jid)
                if rows is not None:
                    atomic(d/'sacct.json',rows)
                    # JobIDRaw is the numeric allocation ID, NOT always array-parent_task.
                    # JobID preserves the array relationship and step suffix.
                    alloc=[r for r in rows if re.fullmatch(re.escape(jid)+r'_\d+',r.get('JobID',''))] if c['array']>1 else [r for r in rows if r.get('JobIDRaw')==jid and '.' not in r.get('JobID','')]
                    done=len(alloc)>=c['array'] and all(r.get('State','').split()[0].split('+')[0] in terminal for r in alloc)
                    if done:
                        s.update(status='DONE',pass_slurm=all(r.get('State')=='COMPLETED' and r.get('ExitCode')=='0:0' for r in alloc),end_epoch=time.time())
                        # Accounting success alone never proves payload success.
                        payload=list(d.glob('*_*/batch.result.json'))
                        s['pass']=s['pass_slurm'] and len(payload)==c['array'] and all(read(p,{}).get('exit_code')==0 for p in payload)
                        s['outcome']='NO_RESOURCES' if s.get('cancel_reason')=='QUEUE_TIMEOUT' and not any(stamp(r.get('Start')) for r in alloc) else ('PASS' if s['pass'] else 'INCONCLUSIVE_OR_FAILED')
                        self.save(); results.append(s['pass']); continue
                    started=[stamp(r.get('Start')) for r in alloc]; started=[x for x in started if x]
                else: started=[]; alloc=[]
                # Query all array elements, not just their compressed parent, for actual state.
                qr,qt=command(['squeue','-h','-r','-j',jid,'-o','%i|%T|%S'],20)
                active_lines=[l for l in qt.splitlines() if l.strip()] if qr==0 else None
                s['last_squeue']=active_lines
                deadline=time.time()-self.state['created']>=self.cfg['total_seconds']
                if deadline or self.stop:
                    s.setdefault('control_deadline_epoch',time.time())
                    self.cancel(jid,c,'TOTAL_WALL_BUDGET' if deadline else 'CONTROLLER_STOP')
                    if time.time()-s['control_deadline_epoch']>180:
                        s.update(status='ACTIVE_UNRESOLVED',**{'pass':False},outcome='CONTROL_UNAVAILABLE_POSSIBLY_ACTIVE')
                        self.stop=True; self.save(); results.append(False); continue
                elif time.time()-s['submit_epoch']>self.cfg['queue_timeout'] and active_lines:
                    # Cancel pending elements individually; keep already-running array members.
                    for line in active_lines:
                        parts=line.split('|'); element=parts[0]
                        if len(parts)>1 and parts[1]=='PENDING' and re.fullmatch(re.escape(jid)+r'(?:_\d+)?',element):
                            # Parent ownership was verified once, then scancel only its concrete element.
                            if c['array']==1: self.cancel(jid,c,'QUEUE_TIMEOUT')
                            else:
                                self.cancel_element(element,c,'QUEUE_TIMEOUT')
                for allocation in alloc:
                    began=stamp(allocation.get('Start'))
                    if began and allocation.get('State','').split()[0] not in terminal and time.time()-began>c['wall_seconds']+120:
                        if c['array']>1: self.cancel_element(allocation['JobID'],c,'RUN_WATCHDOG')
                        else: self.cancel(jid,c,'RUN_WATCHDOG')
                # Wait for accounting lag; lack of a record is unknown, never a training failure.
                if active_lines==[]:
                    s.setdefault('absent_since',time.time())
                    if time.time()-s['absent_since']>180:
                        s.update(status='DONE',**{'pass':False},outcome='ACCOUNTING_UNAVAILABLE'); self.save(); results.append(False); continue
                else: s.pop('absent_since',None)
                remaining.append((c,s)); self.save()
            live=remaining
            if live: time.sleep(self.cfg['poll_seconds'])
        # Preserve input order even when jobs finish in another order.
        return [self.state['cases'].get(c['id'],{}).get('pass',False) for c in cases]

    def fs_matrix(self):
        baseline=[]
        for i in range(3): baseline.append(self.execute(self.case(f'p2-baseline-r{i+1}')))
        # A first-byte/chdir/namespace failure is a diagnostic stop before training.
        if not all(baseline):
            self.note('Minimal baseline did not pass all repeats; collecting path contrasts only.')
        for id,kw in [('cat-cwd',{'chdir':self.cfg['cat_dir']}),('cat-log',{'log':'cat'}),
                      ('license-cat',{'license':'cat'}),('batch-only',{'mode':'direct'}),('step-only',{'mode':'step'})]:
            self.execute(self.case('p2-'+id,**kw))
        for cap in [1,2,4]: self.execute(self.case('p2-array-'+str(cap),array=4,throttle=cap,hold=20))
        # Automatic node pairing only after a real path visibility difference.
        reports=[]
        for p in (self.root/'jobs').glob('p2-*/*_*/*.cat.json'):
            r=read(p,{}); ctx=read(p.with_name(p.name.split('.')[0]+'.context.json'),{})
            reports.append((r.get('rw'),ctx.get('hostname')))
        if len({r for r,n in reports if r})>1:
            nodes=self.cfg['paired_nodes'] or sorted({n.split('.')[0] for r,n in reports if n})[:2]
            for node in nodes:
                rc,txt=command(['sinfo','-N','-h','-n',node,'-p',self.cfg['partition'],'-o','%T'])
                if rc==0 and any(x.strip() in ['idle','mixed','allocated'] for x in txt.splitlines()):
                    for rep in [1,2]:
                        for lic in ['default','cat']:
                            self.execute(self.case(f'p2-pair-{node}-{lic}-r{rep}',node=node,license=lic))
        all_reports=[read(p,{}) for p in (self.root/'jobs').glob('p2-*/*_*/*.cat.json')]
        return all(baseline) and bool(all_reports) and all(x.get('rw')=='PASS' for x in all_reports)

    def resource_matrix(self):
        for gpu,cpu,mem,ex in [(1,14,184320,False),(2,28,368640,False),(4,56,716800,False),(4,56,716800,True)]:
            tag=f'g{gpu}'+('-exclusive' if ex else '')
            for rep in range(1,self.cfg['repeats']+1):
                base=dict(stage=3,gpus=gpu,cpus=cpu,mem_mib=mem,exclusive=ex,mode='step')
                # All variants differ in exactly one factor from base, rather than cumulative changes.
                for variant,delta in [('base',{}),('ntpn',{'ntpn':True}),('gpt',{'gpt':True}),('direct',{'mode':'direct'})]:
                    self.execute(self.case(f'p3-{tag}-{variant}-r{rep}',**dict(base,**delta)))
        for rep in range(1,self.cfg['repeats']+1):
            self.execute_group([self.case(f'p3-four-independent-r{rep}-{i}',stage=3,cpus=14,mem_mib=184320,mode='step',hold=20) for i in range(4)])
            self.execute(self.case(f'p3-one-four-r{rep}',stage=3,gpus=4,cpus=56,mem_mib=737280,mode='step',hold=20))

    def environment_matrix(self):
        if not prepare_runtime(self.root):
            self.note('Own virtual environment setup failed; GPU training skipped; see venv-create.log/pip-install.log')
            self.state['environments']={'standalone':False}; self.save(); return self.state['environments']
        ok=True
        for gpu in [1,4]:
            ok=self.execute(self.case(f'p4-own-{gpu}gpu',stage=4,kind='smoke',environment='standalone',
                gpus=gpu,cpus=14*gpu,mem_mib=184320*gpu if gpu<4 else 716800,mode='step',gpt=True,
                concurrency=1,wall_seconds=300)) and ok
        self.state['environments']={'standalone':ok}; self.save(); return self.state['environments']

    def train_case(self,id,model,n,mps=False,seconds=None,threads=None,workers=None,stage=5):
        sec=seconds or self.cfg['short_seconds']
        return self.case(id,stage=stage,kind='train',environment='standalone',mode='step',gpt=True,
            cpus=14,mem_mib=184320,model=model,concurrency=n,mps=mps,seconds=sec,
            threads=threads if threads is not None else self.cfg['threads'],
            workers=workers if workers is not None else self.cfg['workers'],wall_seconds=sec+300)

    def measure(self,cases):
        # Only successful observed runs are eligible. Sampling absence disqualifies recommendations.
        data=[]
        for c in cases:
            s=self.state['cases'].get(c['id'],{})
            if not s.get('pass'): continue
            ds=list((self.root/'jobs'/c['id']).glob('*_*/launcher.result.json'))
            if len(ds)!=1: continue
            d=ds[0].parent; lr=read(ds[0],{}); rr=[read(p,{}) for p in d.glob('child-*/result.json')]
            if len(rr)!=c['concurrency'] or not all(r.get('ok') and r.get('binding_verified') for r in rr): continue
            gpu_fraction=0.; host_fraction=0.; samples=0; oom=False; cpu=[]; threads=[]; rss=[]; utilization=[]; power=[]
            for line in (d/'events.jsonl').read_text().splitlines():
                r=json.loads(line)
                if r.get('kind')!='sample': continue
                samples+=1; snap=r['data']; cg=snap['cgroup']
                cpu.append(snap.get('cgroup_cpu_interval_percent',snap.get('cpu_total_percent',0))); threads.append(snap.get('thread_total',0)); rss.append(snap.get('rss_sum_kib',0))
                for row in csv.reader(snap['gpu']['output'].splitlines()):
                    if len(row)>=3 and row[0].strip() in lr.get('devices',[]):
                        try:
                            gpu_fraction=max(gpu_fraction,float(row[2])/float(row[1]))
                            if len(row)>=5: utilization.append(float(row[3])); power.append(float(row[4]))
                        except ValueError: pass
                memory=cg.get('effective_memory',cg)
                current=memory.get('memory.peak',memory.get('memory.current',memory.get('memory.max_usage_in_bytes','')))
                maximum=memory.get('memory.max',memory.get('memory.limit_in_bytes',''))
                try: host_fraction=max(host_fraction,int(current)/int(maximum))
                except ValueError: pass
                if re.search(r'oom_kill\s+[1-9]',memory.get('memory.events','')): oom=True
                if number(memory.get('memory.failcnt'))>0: oom=True
            # Per-process allocator peak guards against missed transient GPU peaks.
            peak_fraction=sum(r.get('torch_peak_reserved',0) for r in rr)/max(1,rr[0].get('gpu_total_bytes',0))
            gpu_fraction=max(gpu_fraction,peak_fraction)
            if samples<2 or gpu_fraction<=0 or host_fraction<=0: continue
            workload=json.dumps(rr[0].get('workload'),sort_keys=True)
            baseline=self.state.setdefault('workload_fingerprints',{}).setdefault(c['model'],workload)
            if workload!=baseline:
                self.state.setdefault('workload_mismatches',[]).append(c['id']); continue
            safe=(gpu_fraction<=1-self.cfg['min_gpu_headroom'] and host_fraction<=1-self.cfg['min_host_headroom'] and not oom)
            data.append(dict(case=c['id'],model=c['model'],n=c['concurrency'],mps=c['mps'],
                threads=c['threads'],workers=c['workers'],seconds=c['seconds'],
                throughput=lr['total_items_per_second'],gpu_fraction=gpu_fraction,host_fraction=host_fraction,
                samples=samples,safe=safe,requested_gpu_hours=c['wall_seconds']/3600,
                workload=rr[0].get('workload'),
                items_per_gpu_hour=lr['total_items_per_second']*3600,
                mean_cpu_percent=sum(cpu)/len(cpu),max_threads=max(threads),max_rss_sum_kib=max(rss),
                mean_gpu_utilization=sum(utilization)/len(utilization) if utilization else None,
                mean_gpu_power_watts=sum(power)/len(power) if power else None,
                child_speeds=[r.get('items_per_second',0) for r in rr]))
        return data

    def stress_matrix(self):
        candidates={}; observed=[]
        for model in self.cfg['models']:
            tested=[]
            for n in [1,2,3,4,8,12]:
                passed=True
                group=[]
                for rep in range(1,self.cfg['repeats']+1):
                    c=self.train_case(f'p5-{model}-n{n}-off-r{rep}',model,n); group.append(c); tested.append(c)
                    passed=self.execute(c) and passed
                measures=self.measure(group)
                if not passed or len(measures)!=len(group) or not all(x['safe'] for x in measures):
                    self.note(f'{model}: stop escalation at n={n}; failure, insufficient telemetry, or headroom gate.'); break
                # Isolate MPS as a single factor at exactly the same concurrency/model/thread/worker.
                for rep in range(1,self.cfg['repeats']+1):
                    c=self.train_case(f'p5-{model}-n{n}-on-r{rep}',model,n,True); tested.append(c); self.execute(c)
            measures=self.measure(tested); observed+=measures
            # Require every repetition of a configuration to pass the margin gate.
            grouped=collections.defaultdict(list)
            for r in measures: grouped[(r['n'],r['mps'],r['threads'],r['workers'])].append(r)
            eligible=[v for v in grouped.values() if len(v)==self.cfg['repeats'] and all(x['safe'] for x in v)]
            if not eligible: self.note(model+': no recommendation candidate'); continue
            fastest=max(eligible,key=lambda v:min(x['throughput'] for x in v))[0]
            # Tune workers then threads, each compared to the same chosen base.
            tuned=[]
            for name,values in [('threads',self.cfg['tune_threads']),('workers',self.cfg['tune_workers'])]:
                for value in values:
                    for rep in range(1,self.cfg['repeats']+1):
                        kw={name:value}; c=self.train_case(f'p5-{model}-tune-{name}{value}-r{rep}',model,fastest['n'],fastest['mps'],**kw)
                        tested.append(c); tuned.append(c); self.execute(c)
            measures=self.measure(tested); observed+=self.measure(tuned)
            grouped=collections.defaultdict(list)
            for r in measures: grouped[(r['n'],r['mps'],r['threads'],r['workers'])].append(r)
            eligible=[v for v in grouped.values() if len(v)==self.cfg['repeats'] and all(x['safe'] for x in v)]
            stable=min(eligible,key=lambda v:(v[0]['n'],v[0]['mps'],v[0]['workers'],v[0]['threads']))[0]
            fastest=max(eligible,key=lambda v:min(x['throughput'] for x in v))[0]
            candidates[model]={}
            for label,r in [('stable',stable),('throughput',fastest)]:
                c=self.train_case(f'p5-{model}-{label}-long',model,r['n'],r['mps'],
                    seconds=self.cfg['long_seconds'],threads=r['threads'],workers=r['workers'])
                ok=self.execute(c); long=self.measure([c])
                candidates[model][label]=dict(r,long_case=c['id'],long_pass=ok and bool(long) and long[0]['safe'])
        self.state['candidates']=candidates; atomic(self.root/'training-measurements.json',observed); self.save()
        return candidates

    def final_stage(self):
        io_ok=self.execute(self.case('p6-io',stage=6,kind='io',mode='step',cpus=14,mem_mib=8192))
        if not io_ok: self.note('Own I/O checks did not pass; synthetic pipeline blocked'); return
        for model,picks in self.state.get('candidates',{}).items():
            for label,pick in picks.items():
                if not pick['long_pass']: continue
                c=self.train_case(f'p6-{model}-{label}-pipeline',model,pick['n'],pick['mps'],
                    seconds=self.cfg['long_seconds'],threads=pick['threads'],workers=pick['workers'],stage=6)
                c.update(kind='pipeline',gpus=4,cpus=56,mem_mib=716800)
                self.execute(c)

    def report(self):
        # Bring bounded logs from this tool's exact cat directory into the HOME evidence bundle.
        cat=self.cfg.get('cat_dir')
        if cat:
            packaged=self.root/'cat-evidence'; packaged.mkdir(exist_ok=True)
            for id,s in self.state['cases'].items():
                c=read(self.root/'cases'/f'{id}.json',{})
                if c.get('log')=='cat' and s.get('job_id'):
                    for p in (pathlib.Path(cat)/'slurm').glob(id+'-'+str(s['job_id'])+'*'):
                        bounded_excerpt(p,packaged/p.name)
                if c.get('kind')=='io':
                    for result in (self.root/'jobs'/id).glob('*_*/io.json'):
                        base=pathlib.Path(cat)/'io'/id/result.parent.name
                        for relative in ['shared.jsonl']+[f'task-{i}/{name}' for i in range(8) for name in ['own.jsonl','checkpoint.json','done.json','exit.json']]:
                            dest=packaged/'io'/result.parent.name/relative; dest.parent.mkdir(parents=True,exist_ok=True)
                            bounded_excerpt(base/relative,dest)
            atomic(packaged/'location.json',{'cat_dir':cat,'note':'Model checkpoints, input data and caches remain on cat; only bounded diagnostic files are bundled.'})
        rows=[]; intervals=[]
        for id,s in self.state['cases'].items():
            c=read(self.root/'cases'/f'{id}.json',{})
            accounting=read(self.root/'jobs'/id/'sacct.json',[])
            for r in accounting:
                raw=r.get('JobID','') or r.get('JobIDRaw',''); start=stamp(r.get('Start')); end=stamp(r.get('End'))
                element=raw.split('.')[0]; key=element if '_' in element else element+'_0'
                d=self.root/'jobs'/id/key
                first=(self.root/'jobs'/id/'markers'/f'{key}.batch').exists()
                events=[]
                for p in [d/'events.jsonl']+list(d.glob('child-*/events.jsonl')):
                    if p.exists():
                        for line in p.read_text().splitlines():
                            with contextlib.suppress(ValueError): events.append(json.loads(line))
                stages={}
                for e in sorted(events,key=lambda e:e.get('epoch',0)): stages.setdefault(e['kind'],e['time'])
                layer=('exit' if 'batch_end' in stages else 'training' if 'stable_training_start' in stages or 'training_complete' in stages else
                       'cuda' if 'cuda_initialized' in stages else 'python' if 'python_start' in stages else
                       'step_launch' if 'step_launch' in stages else 'batch' if first else 'allocated_batch_first_missing' if start else 'queue')
                outcome=s.get('outcome',s['status'])
                if element in s.get('queue_timed_out_elements',[]) and not start: outcome='NO_RESOURCES'
                gm=re.search(r'(?:^|,)gres/gpu=(\d+)(?:,|$)',r.get('AllocTRES',''))
                actual_gpus=int(gm.group(1)) if gm else None
                allocation='.' not in raw and (c.get('array',1)==1 or bool(re.fullmatch(re.escape(str(s.get('job_id','')))+r'_\d+',raw)))
                row=dict(case=id,stage=c.get('stage'),kind=c.get('kind'),job=raw,submit=r.get('Submit'),eligible=r.get('Eligible'),
                    start=r.get('Start'),end=r.get('End'),queue_seconds=(start-stamp(r.get('Submit'))) if start and stamp(r.get('Submit')) else None,
                    node=r.get('NodeList'),state=r.get('State'),exit_code=r.get('ExitCode'),outcome=outcome,
                    layer=layer,batch_first=first,req_tres=r.get('ReqTRES'),alloc_tres=r.get('AllocTRES'),
                    max_rss=r.get('MaxRSS'),total_cpu=r.get('TotalCPU'),elapsed=r.get('ElapsedRaw'),timeline=stages,
                    actual_gpus=actual_gpus,requested_gpus=c.get('gpus'),requested_cpus=c.get('cpus'),requested_mem_mib=c.get('mem_mib'),
                    request=c,repeat_index=number(re.search(r'-r(\d+)',id).group(1)) if re.search(r'-r(\d+)',id) else 1,
                    gpu_hours=(end-start)*actual_gpus/3600 if start and end and allocation and actual_gpus is not None else None)
                rows.append(row)
                if allocation and start and end: intervals.append((id,raw,start,end,actual_gpus or 0))
            if not accounting: rows.append(dict(case=id,outcome=s.get('outcome',s['status']),reason=s.get('reason'),stage=c.get('stage')))
        overlap={}
        for id in {x[0] for x in intervals}:
            events=sorted([(a,1,g) for k,j,a,b,g in intervals if k==id]+[(b,-1,-g) for k,j,a,b,g in intervals if k==id])
            running=gpus=peak=peakg=0
            for _,dn,dg in events: running+=dn; gpus+=dg; peak=max(peak,running); peakg=max(peakg,gpus)
            overlap[id]={'actual_peak_jobs':peak,'actual_peak_gpus':peakg}
        # Overall overlap includes the four independently submitted allocations.
        ev=sorted([(a,g) for k,j,a,b,g in intervals]+[(b,-g) for k,j,a,b,g in intervals]); use=peak=0
        for _,delta in ev: use+=delta; peak=max(peak,use)
        findings={'confirmed':[],'clues':[],'unverified':[]}
        for id,s in self.state['cases'].items():
            d=self.root/'jobs'/id
            for p in d.glob('*_*/*.cat.json'):
                r=read(p,{})
                if r.get('rw')=='FAIL': findings['confirmed'].append({'case':id,'type':'cat_rw_failed','evidence':str(p.relative_to(self.root)),'error':r.get('error')})
            for p in d.glob('*_*/child-*/result.json'):
                r=read(p,{})
                if r.get('error'):
                    reason='CUDA_OOM' if 'out of memory' in r['error'].lower() and ('cuda' in r['error'].lower() or r.get('error_type')=='OutOfMemoryError') else 'APPLICATION_EXCEPTION'
                    findings['confirmed'].append({'case':id,'type':reason,'error_type':r.get('error_type'),'error':r['error'],'evidence':str(p.relative_to(self.root))})
            if s.get('status') in ['SKIPPED','SUBMISSION_UNCERTAIN','ACTIVE_UNRESOLVED']:
                findings['unverified'].append({'case':id,'status':s['status'],'reason':s.get('reason',s.get('outcome'))})
        for r in rows:
            if r.get('state')=='OUT_OF_MEMORY': findings['confirmed'].append({'case':r['case'],'job':r['job'],'type':'SLURM_HOST_OOM'})
            if r.get('layer')=='allocated_batch_first_missing' and '.' not in r.get('job',''):
                findings['clues'].append({'case':r['case'],'job':r['job'],'type':'ALLOCATED_BEFORE_BATCH_MARKER','node':r.get('node'),'start':r.get('start')})
        atomic(self.root/'findings.json',findings)
        atomic(self.root/'results.json',{'experiments':rows,'overlap':overlap,'global_actual_peak_gpus':peak,
            'allocation_gpu_count_missing':sum(1 for r in rows if r.get('start') and '.' not in r.get('job','') and r.get('actual_gpus') is None),
            'gpu_hours_observed':sum(x.get('gpu_hours') or 0 for x in rows),
            'reserved_gpu_hour_upper_bound':self.state['reserved_gpu_hours'],'candidates':self.state.get('candidates',{}),
            'stage_results':self.state.get('stage_results',{}),
            'repeat_summary':dict(collections.Counter(re.sub(r'-r\d+(?=-|$)','-r*',id) for id in self.state['cases']))})
        columns=['case','stage','job','kind','submit','eligible','start','end','queue_seconds','node','state','exit_code','outcome','layer','batch_first','requested_gpus','requested_cpus','requested_mem_mib','actual_gpus','req_tres','alloc_tres','max_rss','total_cpu','elapsed','gpu_hours','reason']
        with (self.root/'results.csv').open('w') as f:
            w=csv.DictWriter(f,columns,extrasaction='ignore'); w.writeheader(); w.writerows(rows)
        lines=['# Capella audit '+self.cfg['run_id'],'',f'Generated {now()} (all raw times UTC).',
            '', '## 已证实原因', '', '以下只证明对应测试的失败事件，底层根因需结合对照和服务端日志。']
        lines.extend('- '+json.dumps(x,ensure_ascii=False) for x in findings['confirmed'])
        if not findings['confirmed']: lines.append('无已证实失败原因；未执行不等于通过。')
        lines+=['', '## 相关线索', '', '|实验|结果|最后到达层|节点|作业|', '|---|---|---|---|---|']
        for r in rows:
            if '.' not in r.get('job',''): lines.append('|'+ '|'.join(str(r.get(k,'')) for k in ['case','outcome','layer','node','job'])+'|')
        lines+=['','## 尚未验证','','无 batch 首条标记只能定位到 batch 正文之前，不能区分 chdir、日志打开、prolog 或服务端故障。',
            '默认 license 自动包含全部文件系统；license 与挂载可见性分别核对。SKIP 不等于崩溃。',
            '全部结果仅适用于本工具自带的合成模型和数据；未运行的对照保持未知。',
            'MaxRSS 可能只在 step 有值，空值不是零；cgroup 与采样也可能遗漏峰值。',
            '', '## 推荐配置','','只输出重复短测、至少一小时持续测试且保留配置余量的候选。吞吐最高指已测试配置中的结果。']
        for model,picks in self.state.get('candidates',{}).items():
            for label,p in picks.items():
                lines.append(f"- {model}/{label}: n={p['n']}, MPS={p['mps']}, threads={p['threads']}, workers={p['workers']}; "
                    f"short throughput={p['throughput']:.3f} items/s; GPU peak fraction={p['gpu_fraction']:.3f}; host={p['host_fraction']:.3f}; long_pass={p['long_pass']}")
                if p['long_pass']: self.template(model,label,p)
        if not self.state.get('candidates'): lines.append('无已验证训练推荐；保持原因未定。')
        lines+=['','完整数据见 results.csv、results.json、training-measurements.json、jobs/ 和 evidence/。',
            f"Observed GPU hours={sum(x.get('gpu_hours') or 0 for x in rows):.4f}; reservation upper bound={self.state['reserved_gpu_hours']:.4f}.",
            f'Actual global GPU overlap={peak}; configured cap={self.cfg["max_gpus"]}.']
        (self.root/'REPORT.md').write_text('\n'.join(lines)+'\n')
        support=['# ZIH support evidence (draft only; never sent)',
            'Recipient: hpc-support@tu-dresden.de',f'Run: {self.cfg["run_id"]}',
            'Please inspect server-side slurmd/prolog/mount logs for these cases. Cause undetermined.',
            'Exact reproduction: jobs/<case>/submission.json; absolute HOME logs and /tmp baseline.',
            'Job/time/node records:']
        for r in rows:
            if r.get('layer')=='allocated_batch_first_missing' or ('p2-' in r['case'] and r.get('outcome')!='PASS'):
                support.append(json.dumps(r,ensure_ascii=False))
                submission=read(self.root/'jobs'/r['case']/'submission.json',{})
                if submission.get('shell'): support.append('Reproduce: '+submission['shell'])
        (self.root/'SUPPORT.txt').write_text('\n'.join(support)+'\n')
        self.save()
        archive=self.root.with_suffix('.tar.gz')
        with tarfile.open(archive,'w:gz') as tar:
            tar.add(self.root,arcname=self.root.name,filter=lambda info: None if '/.venv' in info.name or '/cache/' in info.name or info.name.endswith(('.pt','.pth')) else info)
        print('REPORT:',self.root/'REPORT.md','ARCHIVE:',archive,flush=True)

    def template(self,model,label,p):
        # Reproduce this run's own built-in synthetic workload.
        d=self.root/'templates'; d.mkdir(exist_ok=True)
        cid=p['long_case']; c=read(self.root/'cases'/f'{cid}.json')
        text='#!/usr/bin/env bash\n'+ '\n'.join([
            '#SBATCH --account='+self.cfg['account'],'#SBATCH --partition='+self.cfg['partition'],
            '#SBATCH --nodes=1','#SBATCH --ntasks=1','#SBATCH --gres=gpu:1','#SBATCH --gpus-per-task=1',
            '#SBATCH --export=HOME='+str(pathlib.Path.home())+',PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin,LANG=C.UTF-8,TZ=UTC,PYTHONNOUSERSITE=1,PYTHONDONTWRITEBYTECODE=1',
            '#SBATCH --cpus-per-task=14','#SBATCH --mem=180G',
            '#SBATCH --time='+str(math.ceil(c['wall_seconds']/60)), '#SBATCH --chdir=/tmp',
            '#SBATCH --output='+str(self.root/'slurm'/f'recommended-{model}-{label}-%j.out'),
            '#SBATCH --error='+str(self.root/'slurm'/f'recommended-{model}-{label}-%j.err')])+'\nset -euo pipefail\n'
        if c['license']!='default':
            # Directives must precede shell commands.
            text=text.replace('set -euo pipefail\n','#SBATCH --licenses='+c['license']+'\nset -euo pipefail\n')
        text+=f"# Observed candidate: {p['n']} processes/GPU; threads={p['threads']}; workers={p['workers']}; MPS={p['mps']}\n"
        text+='srun --ntasks=1 --cpus-per-task=14 --gres=gpu:1 --gpus-per-task=1 /usr/bin/python3 -I '+shlex.quote(str(self.root/'runtime.py'))+' --payload '+shlex.quote(str(self.root))+' '+shlex.quote(cid)+'\n'
        (d/f'{model}-{label}.sbatch').write_text(text)

    def run(self):
        self.root.mkdir(parents=True,exist_ok=True)
        with (self.root/'controller.lock').open('w') as lock:
            try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError: raise SystemExit('Controller already running')
            signal.signal(signal.SIGTERM,lambda *_:setattr(self,'stop',True))
            signal.signal(signal.SIGINT,lambda *_:setattr(self,'stop',True))
            try:
                stages=self.cfg['stages']
                self.state['stage_results']={str(s):'PENDING' if s in stages else 'NOT_REQUESTED' for s in range(1,7)}
                if not self.state.get('evidence_complete'): self.snapshot()
                self.state['stage_results']['1']='EVIDENCE_COLLECTED_WITH_RECORDED_GAPS'; self.save()
                if 2 in stages:
                    paths_ok=self.fs_matrix(); self.state['paths_ok']=paths_ok; self.save()
                    self.state['stage_results']['2']='PASS' if paths_ok else 'NOT_PROVEN_RELIABLE'
                else: paths_ok=self.state.get('paths_ok',False)
                if 3 in stages and paths_ok:
                    self.resource_matrix(); self.state['stage_results']['3']='MATRIX_ATTEMPTED_SEE_CASE_OUTCOMES'
                elif 3 in stages:
                    self.state['stage_results']['3']='UNVERIFIED_STARTUP_GATE'; self.note('Resource matrix skipped because minimal path/startup gate did not pass')
                if not paths_ok and any(s in stages for s in [4,5,6]):
                    for s in [4,5,6]:
                        if s in stages: self.state['stage_results'][str(s)]='UNVERIFIED_STARTUP_GATE'
                    self.note('Path/startup gate not passed. Training and I/O stages not executed; support evidence prepared.')
                else:
                    envs=self.environment_matrix() if 4 in stages else self.state.get('environments',{})
                    if 4 in stages: self.state['stage_results']['4']=envs
                    if 5 in stages:
                        if envs.get('standalone'):
                            self.stress_matrix(); self.state['stage_results']['5']='ATTEMPTED_SEE_LONG_PASS_AND_CASE_OUTCOMES'
                        else:
                            self.state['stage_results']['5']='UNVERIFIED_OWN_ENVIRONMENT'
                            self.note('Own environment did not pass: synthetic training unverified')
                    if 6 in stages:
                        self.final_stage(); self.state['stage_results']['6']='SEE_OWN_IO_AND_SYNTHETIC_PIPELINE_OUTCOMES'
                self.state['finished']=now(); self.save()
            except BaseException:
                (self.root/'controller-error.txt').write_text(traceback.format_exc())
                self.note('Controller interrupted/error. Registered jobs preserved for resume; inspect controller-error.txt.')
                raise
            finally: self.report()

def validate(cfg):
    for k in ['max_gpus','queue_timeout','max_job_seconds','total_seconds','gpu_hour_budget','poll_seconds',
              'sample_seconds','short_seconds','long_seconds','repeats']:
        if not isinstance(cfg[k],(int,float)) or cfg[k]<=0: raise ValueError(k+' must be positive')
    if not 1<=cfg['max_gpus']<=4: raise ValueError('max_gpus must be 1..4')
    if not 5<=cfg['sample_seconds']<=10: raise ValueError('sample_seconds must be 5..10')
    if cfg['poll_seconds']<10: raise ValueError('poll_seconds must be >=10')
    if cfg['long_seconds']<3600: raise ValueError('long_seconds must be >=3600; shorter runs cannot validate candidates')
    if cfg['max_job_seconds']<cfg['long_seconds']+600: raise ValueError('max_job_seconds must cover long_seconds + 600')
    if cfg['max_job_seconds']%60: raise ValueError('max_job_seconds must be a whole number of minutes')
    if cfg['repeats']<2: raise ValueError('repeats must be >=2')
    if cfg['threads']!=1 or cfg['workers']!=0: raise ValueError('baseline must use threads=1, workers=0; tune_* vary these later')
    for k in ['min_gpu_headroom','min_host_headroom']:
        if not .1<=cfg[k]<.9: raise ValueError(k+' must be 0.1..0.9')
    if not cfg['stages'] or any(s not in range(1,7) for s in cfg['stages']): raise ValueError('stages must be a subset of 1..6')
    if any(m not in ['S','M','L'] for m in cfg['models']): raise ValueError('models must be S, M, L')
    if not 2<=cfg['workspace_days']<=7: raise ValueError('workspace_days must be 2..7')
    if cfg['workspace_days']*86400<cfg['total_seconds']+3600: raise ValueError('workspace must outlive the test budget')

def start(config,foreground):
    supplied=read(config) if config else {}
    if not isinstance(supplied,dict): raise SystemExit('Configuration must be an existing valid JSON object')
    unknown=set(supplied)-set(DEFAULT)
    if unknown: raise SystemExit('Unsupported configuration keys: '+', '.join(sorted(unknown)))
    cfg=dict(DEFAULT); cfg.update(supplied); validate(cfg)
    if os.environ.get('USER')!=cfg['expected_user']: raise SystemExit('Expected user '+cfg['expected_user'])
    if not shutil.which('sbatch'): raise SystemExit('Run on a Capella login node')
    if os.environ.get('SLURM_JOB_ID'): raise SystemExit('Start outside an existing allocation')
    for key in list(os.environ):
        if key.startswith(('SLURM_','SBATCH_','SRUN_','SALLOC_')): os.environ.pop(key,None)
    run_id=dt.datetime.now(UTC).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]
    root=pathlib.Path.home()/'capella-audit'/run_id; root.mkdir(parents=True,mode=0o700)
    for name in ['slurm','fs','cases','jobs','evidence','tmp','cache']: (root/name).mkdir()
    os.environ.update(TMPDIR=str(root/'tmp'),XDG_CACHE_HOME=str(root/'cache'))
    catdir=None
    if any(s>1 for s in cfg['stages']):
        name='ca-'+run_id
        rc,txt=capture(root/'workspace-create.log',['ws_allocate','--filesystem','cat',name,str(cfg['workspace_days'])],60)
        candidates=[line.strip() for line in txt.splitlines() if line.strip().startswith('/data/cat/')]
        if rc or len(candidates)!=1: raise SystemExit('Own cat workspace allocation failed; see '+str(root/'workspace-create.log'))
        catdir=pathlib.Path(candidates[0]).resolve()
        if name not in catdir.name or not str(catdir).startswith('/data/cat/') or catdir.stat().st_uid!=os.getuid():
            raise SystemExit('Workspace ownership/name/path verification failed')
        rc,txt=command(['findmnt','-n','-T',str(catdir),'-o','TARGET,FSTYPE'],10)
        if rc or not txt.strip() or txt.split()[0]=='/': raise SystemExit('New workspace is not backed by a verified cat mount')
        (catdir/'slurm').mkdir(); atomic(catdir/'audit-owner.json',{'run_id':run_id,'uid':os.getuid()})
    cfg.update(schema_version=2,run_id=run_id,cat_dir=str(catdir) if catdir else '',home_dir=str(root),
               launch_time=now(),script_sha256=hashlib.sha256(SELF.read_bytes()).hexdigest())
    shutil.copyfile(SELF,root/'capella_audit.sh')
    source=SELF.read_text().split("<<'CAPELLA_PY'\n",1)[1].rsplit('\nCAPELLA_PY',1)[0]
    (root/'runtime.py').write_text(source); (root/'batch.sh').write_text(BATCH)
    atomic(root/'config.json',cfg)
    atomic(root/'manifest.json',{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.iterdir() if p.is_file()})
    print('RUN_DIR='+str(root)); print('CAT_DIR='+str(catdir or ''))
    launch(root,foreground)

def launch(root,foreground=False):
    root=pathlib.Path(root).resolve()
    if read(root/'config.json',{}).get('schema_version')!=2: raise SystemExit('Only standalone v2 runs can be resumed')
    if foreground: Controller(root).run(); return
    with (root/'controller.log').open('a') as log:
        p=sp.Popen(['bash',str(root/'capella_audit.sh'),'_controller',str(root)],
            stdout=log,stderr=sp.STDOUT,stdin=sp.DEVNULL,start_new_session=True,cwd=str(root))
    print('CONTROLLER_PID='+str(p.pid)); print('LOG='+str(root/'controller.log'))
    atomic(root/'controller.pid.json',{'pid':p.pid,'time':now()})
    print('Resume: bash '+shlex.quote(str(root/'capella_audit.sh'))+' resume '+shlex.quote(str(root)))

def main():
    # runtime.py is called directly on compute nodes, while the shell entry supplies its own filename.
    argv=ARGS if SELF.suffix=='.sh' else sys.argv[1:]
    if argv and argv[0]=='--devices':
        import torch
        print('AUDIT_UUIDS='+json.dumps([cuda_uuid(torch,i) for i in range(torch.cuda.device_count())])); return 0
    if argv and argv[0]=='--batch': return batch(*argv[1:])
    if argv and argv[0]=='--fs': return fs_probe(*argv[1:])
    if argv and argv[0]=='--sample': sampler(argv[1],argv[2],int(argv[3])); return 0
    if argv and argv[0]=='--torch-child': return torch_child(*argv[1:])
    if argv and argv[0]=='--payload':
        root,cid=argv[1:]; kind=read(pathlib.Path(root)/'cases'/f'{cid}.json')['kind']
        return io_test(root,cid) if kind=='io' else pipeline(root,cid) if kind=='pipeline' else run_training(root,cid)
    parser=argparse.ArgumentParser(description='Independent, resumable ZIH Capella audit. See README.md.')
    sub=parser.add_subparsers(dest='action',required=True)
    p=sub.add_parser('init-config'); p.add_argument('path')
    p=sub.add_parser('start'); p.add_argument('--config'); p.add_argument('--foreground',action='store_true')
    for a in ['resume','report','status','stop','_controller']:
        p=sub.add_parser(a); p.add_argument('run_dir'); p.add_argument('--foreground',action='store_true')
    args=parser.parse_args(argv)
    if args.action in ['resume','report','status','stop','_controller']:
        if read(pathlib.Path(args.run_dir)/'config.json',{}).get('schema_version')!=2:
            raise SystemExit('Only standalone v2 run directories are supported')
    if args.action=='init-config':
        p=pathlib.Path(args.path)
        if p.exists(): raise SystemExit('Refusing to overwrite '+str(p))
        atomic(p,DEFAULT); print('Edit '+str(p)+' before start.'); return 0
    if args.action=='start': start(args.config,args.foreground)
    elif args.action=='resume': launch(args.run_dir,args.foreground)
    elif args.action=='report': Controller(args.run_dir).report()
    elif args.action=='status':
        s=read(pathlib.Path(args.run_dir)/'state.json',{})
        print(json.dumps({'statuses':dict(collections.Counter(x.get('status') for x in s.get('cases',{}).values())),
                          'finished':s.get('finished'),'reserved_gpu_hours':s.get('reserved_gpu_hours'),
                          'active':{k:v for k,v in s.get('cases',{}).items() if v.get('status') in ['ACTIVE','SUBMIT_INTENT','ACTIVE_UNRESOLVED','SUBMISSION_UNCERTAIN']}},indent=2))
    elif args.action=='stop':
        p=pathlib.Path(args.run_dir).resolve()
        if not (p/'config.json').is_file(): raise SystemExit('Not an audit run directory')
        (p/'stop.request').touch(); print('Stop requested; running controller will cancel only verified owned jobs. If controller is down, resume this run to process the request.')
    else: Controller(args.run_dir).run()
    return 0

if __name__=='__main__':
    os.environ['TZ']='UTC'; time.tzset()
    os.environ['PYTHONDONTWRITEBYTECODE']='1'
    # Direct runtime invocation has sys.argv[1] as a mode, not the shell script path.
    if not str(sys.argv[0]).endswith('-'):
        SELF=pathlib.Path(sys.argv[0]).resolve(); ARGS=sys.argv[1:]
    sys.exit(main() or 0)
CAPELLA_PY
