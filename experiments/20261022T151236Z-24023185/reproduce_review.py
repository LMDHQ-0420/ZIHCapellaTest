"""Archive data reader only. Does not extract paths, import archive code or contact Slurm."""
from pathlib import Path
import tarfile,json,hashlib,csv,collections,re,datetime
import argparse
parser=argparse.ArgumentParser(description='Reproduce the reviewed records for run 20261022T151236Z-24023185; reads archive data only, never executes it.')
parser.add_argument('archive',type=Path)
parser.add_argument('--out',type=Path,default=Path(__file__).resolve().parent)
args=parser.parse_args(); src=args.archive; dst=args.out
expected='718735d933644d9ba00c6e18375a7df50d1b57d0cc615248c204b49a81216c77'
if hashlib.sha256(src.read_bytes()).hexdigest()!=expected:
    raise SystemExit('This review requires the exact original archive SHA-256: '+expected)
dst.mkdir(parents=True,exist_ok=True)
with tarfile.open(src) as tar:
    members={m.name:m for m in tar if m.isfile()}
    prefix='20261022T151236Z-24023185/'
    def data(n): return tar.extractfile(members[prefix+n]).read()
    def get(n,default=None):
        return json.loads(data(n)) if prefix+n in members else default
    def save(n,obj): (dst/n).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
    cfg=get('config.json');state=get('state.json');results=get('results.json')
    for n in ['config.json','results.csv']:(dst/('original-'+n)).write_bytes(data(n))
    evidence={};longs=[];cases=[]
    for case,s in state['cases'].items():
        jid=s.get('job_id'); c=get('cases/'+case+'.json',{}); b=f'jobs/{case}/{jid}_0'
        rows=[r for r in results['experiments'] if r['case']==case]
        category='PASS' if s.get('pass') else 'NO_RESOURCES' if s.get('outcome')=='NO_RESOURCES' else 'IPC_TEMP_PATH_TOO_LONG' if 'tune-workers2' in case else 'CAT_MOUNT_NOT_VISIBLE' if case.startswith('p3-g4-exclusive') else 'CAT_PATH_UNUSABLE' if case.startswith('p6-') else 'UNCLASSIFIED'
        cases.append(dict(case=case,job_id=jid,original_outcome=s.get('outcome'),reviewed_classification=category,request=c,
                          allocation_rows=[r for r in rows if '.' not in r.get('job','')],
                          child_exits=get(b+'/child-exits.json'),batch_result=get(b+'/batch.result.json')))
        if not s.get('pass'):
            for tail0 in ['submission.json','latest.scontrol.json']:
                name=f'jobs/{case}/{tail0}'
                if prefix+name in members:
                    content=data(name);evidence[name]={'sha256':hashlib.sha256(content).hexdigest(),'content':content.decode(errors='replace')}
            for tail in ['launcher.error.json','child-exits.json','step.cat.json','step.home.json','batch.context.json','step.context.json','batch.result.json','events.jsonl','job-start.txt']:
                name=b+'/'+tail
                if prefix+name in members:
                    content=data(name)
                    if tail=='events.jsonl' and len(content)>12000:continue
                    evidence[name]={'sha256':hashlib.sha256(content).hexdigest(),'content':content.decode(errors='replace')}
            for n in members:
                if n.startswith(prefix+b+'/g') and n.endswith('.log'):
                    content=data(n[len(prefix):]);text=content.decode(errors='replace')
                    if 'AF_UNIX path too long' in text:
                        marker=text.index('AF_UNIX path too long');evidence[n[len(prefix):]]={'sha256':hashlib.sha256(content).hexdigest(),
                            'excerpt_only':True,'content':text[max(0,marker-600):marker+180]};break
        if case in ['p3-g4-exclusive-base-r1','p3-g4-exclusive-ntpn-r1','p3-g4-exclusive-base-r2']:
            name=b+'/step.mountinfo.txt';text=data(name).decode()
            evidence[name]={'sha256':hashlib.sha256(data(name)).hexdigest(),'excerpt_only':True,
                'content':'\n'.join(l for l in text.splitlines() if ' /data/cat ' in l or ' / / ' in l or 'nvme0n1p2' in l)}
        if case.endswith('-long'):
            lr=get(b+'/launcher.result.json'); children=[]
            for n in members:
                if n.startswith(prefix+b+'/child-') and n.endswith('/result.json'):
                    r=json.loads(tar.extractfile(members[n]).read());children.append(r)
            samples=[]
            for line in data(b+'/events.jsonl').splitlines():
                r=json.loads(line)
                if r.get('kind')=='sample':samples.append(r['data'])
            peaks=[];limits=[];cpu=[];oom=[];gpu=[];power=[]
            for s0 in samples:
                mem=s0['cgroup'].get('effective_memory',s0['cgroup'])
                peaks.append(int(mem.get('memory.peak',mem.get('memory.current',0))))
                if str(mem.get('memory.max','')).isdigit():limits.append(int(mem['memory.max']))
                cpu.append(s0.get('cgroup_cpu_interval_percent',s0.get('cpu_total_percent',0)))
                oom.append(mem.get('memory.events',''))
                for row in csv.reader(s0.get('gpu',{}).get('output','').splitlines()):
                    if len(row)>=5:
                        gpu.append(float(row[2])/float(row[1]));power.append(float(row[4]))
            parent=next(r for r in rows if r.get('job')==jid)
            longs.append(dict(case=case,job_id=jid,node=parent['node'],model=c['model'],n=c['concurrency'],mps=c['mps'],threads=c['threads'],workers=c['workers'],
                 launcher=lr,child_results=children,sample_count=len(samples),host_effective_peak_bytes=max(peaks),host_effective_limit_bytes=min(limits),
                 mean_cpu_percent=sum(cpu)/len(cpu),maximum_sampled_gpu_memory_fraction=max(gpu),mean_sampled_gpu_power_watts=sum(power)/len(power),
                 max_oom_kill=max([int(m.group(1)) for text in oom for m in [re.search(r'^oom_kill (\d+)$',text,re.M)] if m] or [0]),
                 torch_per_process_max_reserved_bytes=max(r['torch_peak_reserved'] for r in children),
                 allocation=parent))
    # Additional raw, bounded, explicitly selected hardware proof.
    for name in ['jobs/p4-own-4gpu/4451753_0/hardware.txt','jobs/p4-own-4gpu/4451753_0/launcher.context.json','jobs/p4-own-4gpu/4451753_0/launcher.result.json',
                 'jobs/p5-S-n12-on-r1/4452070_0/launcher.result.json','jobs/p3-g4-exclusive-base-r2/4451688_0/step.cat.json']:
        content=data(name);evidence[name]={'sha256':hashlib.sha256(content).hexdigest(),'content':content.decode(errors='replace')}
    save('reviewed-cases.json',cases);save('long-measurements.json',longs);save('selected-evidence.json',evidence)
    save('provenance.json',dict(run_id=cfg['run_id'],archive_name=src.name,archive_bytes=src.stat().st_size,
        archive_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),archive_regular_files=len(members),
        script_sha256=hashlib.sha256(data('capella_audit.sh')).hexdigest(),source_revision='dfefda2532bab859ff861461250ca0f75ada27e9',
        config_script_sha256=cfg['script_sha256'],start_utc=cfg['launch_time'],end_utc=state['finished'],
        case_outcomes=dict(collections.Counter(s.get('outcome') for s in state['cases'].values())),
        reviewed_classification=dict(collections.Counter(c['reviewed_classification'] for c in cases)),
        accounting_rows=len(results['experiments']),allocation_rows=sum('.' not in r.get('job','') for r in results['experiments']),
        allocated_parent_elements=sum('.' not in r.get('job','') and bool(re.match(r'^\d{4}-',str(r.get('start','')))) for r in results['experiments']),
        gpu_hours_observed=results['gpu_hours_observed'],reserved_gpu_hour_upper_bound=results['reserved_gpu_hour_upper_bound'],
        maximum_actual_gpu_overlap=results['global_actual_peak_gpus'],
        archive_scope='Original v2 HOME archive with bounded cat excerpts; not a complete raw cat export.',
        evidence_scope='selected-evidence.json preserves selected raw content and explicitly marked excerpts with original file hashes; original-results.csv preserves all accounting rows.'))
for r in longs:
 print(r['model'],r['n'],r['mps'],r['threads'],r['launcher']['total_items_per_second'],r['host_effective_peak_bytes']/2**30,r['mean_cpu_percent'],r['maximum_sampled_gpu_memory_fraction'],r['mean_sampled_gpu_power_watts'])
