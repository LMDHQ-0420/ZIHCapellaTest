"""Review one exact diagnostic archive as data; never execute archived code or contact Slurm."""
import argparse, collections, hashlib, json, pathlib, re, tarfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive',type=pathlib.Path)
parser.add_argument('--out',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parent)
args=parser.parse_args(); run='20261023T154308Z-4364ef9b'
expected='516e3b6aa2af0f2d1ae222ea0705f867c721edd5ad97d3afe6768b73a7dbf2e1'
h=hashlib.sha256()
with args.archive.open('rb') as stream:
    for block in iter(lambda:stream.read(1024*1024),b''): h.update(block)
if h.hexdigest()!=expected: raise SystemExit('Expected original archive SHA-256 '+expected)
args.out.mkdir(parents=True,exist_ok=True)
def save(name,obj):
    (args.out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
with tarfile.open(args.archive) as tar:
    files={m.name:m for m in tar if m.isfile()}; prefix=run+'/home/'
    def raw(name): return tar.extractfile(files[prefix+name]).read()
    def get(name,default=None): return json.loads(raw(name)) if prefix+name in files else default
    manifest=json.load(tar.extractfile(files[run+'/export-manifest.json']))
    assert len(manifest['files'])==len(files)-1
    for item in manifest['files']:
        data=tar.extractfile(files[item['archive_path']]).read()
        assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
    state=get('state.json'); cfg=get('config.json'); results=get('results.json')
    assert hashlib.sha256(raw('capella_audit.sh')).hexdigest()==cfg['script_sha256']
    for name in ['config.json','state.json','REPORT.md','findings.json','results.csv']:
        (args.out/('original-'+name)).write_bytes(raw(name))
    reviewed=[]; selected={}
    for case,s in state['cases'].items():
        rows=[r for r in results['experiments'] if r['case']==case]
        reviewed.append(dict(case=case,request=get('cases/'+case+'.json'),controller=s,accounting=rows))
    for name in files:
        if not name.startswith(prefix): continue
        rel=name[len(prefix):]
        keep=rel in ['controller.log','evidence/node-sample.txt','evidence/nodes.txt','evidence/partition.txt','evidence/qos.txt','evidence/association.txt']
        keep |= bool(re.fullmatch(r'evidence/node-c\d+\.txt',rel))
        keep |= rel.endswith(('latest.scontrol.json','preflight.txt','submission.json'))
        keep |= bool(re.search(r'/[^/]+\.(?:cat|home)\.json$',rel))
        keep |= rel.startswith('jobs/p4-own-1gpu/') and rel.endswith(('launcher.result.json','hardware.txt','child-g0-p0/result.json','local-storage-mount.txt','batch.context.json','payload-preflight.context.json'))
        if keep:
            content=raw(rel); selected[rel]=dict(sha256=hashlib.sha256(content).hexdigest(),content=content.decode(errors='replace'))
    allocated=[r for r in results['experiments'] if '.' not in r.get('job','') and re.match(r'^\d{4}-',str(r.get('start','')))]
    cat_reports=[]
    for name in files:
        if name.startswith(prefix+'jobs/') and name.endswith('.cat.json'):
            value=json.loads(tar.extractfile(files[name]).read());cat_reports.append({'file':name[len(prefix):],**value})
    nodes={line.split('|')[0]:line.split('|')[1] for line in raw('evidence/node-sample.txt').decode().splitlines() if re.match(r'^c\d+\|',line)}
    outcomes=collections.Counter(s.get('outcome',s['status']) for s in state['cases'].values())
    c113=[s for c,s in state['cases'].items() if c.startswith('f2-c113-')]
    summary=dict(run_id=run,archive_name=args.archive.name,archive_bytes=args.archive.stat().st_size,archive_sha256=expected,
        archive_integrity='PASS',archive_files=len(files),verified_payload_files=len(manifest['files']),complete_logs=manifest['complete_logs'],gaps=manifest['gaps'],
        source_commit='1a83dc9',script_sha256=cfg['script_sha256'],start_utc=cfg['launch_time'],end_utc=state['finished'],
        case_outcomes=dict(outcomes),cases=len(reviewed),submitted_cases=sum(bool(s.get('job_id')) for s in state['cases'].values()),
        allocated_cases=len(allocated),allocated_nodes=sorted({r['node'] for r in allocated}),allocations=allocated,
        gpu_hours_observed=results['gpu_hours_observed'],maximum_gpu_overlap=results['global_actual_peak_gpus'],
        reserved_gpu_hour_upper_bound=results['reserved_gpu_hour_upper_bound'],cat_checks=collections.Counter(r['rw'] for r in cat_reports),
        cat_reports=cat_reports,node_states=dict(collections.Counter(nodes.values())),
        c113_controller_wait_seconds=max(s['end_epoch'] for s in c113)-min(s['submit_epoch'] for s in c113),
        stress_cases_allocated=sum(r.get('kind') in ['train','pipeline'] for r in allocated),
        single_gpu_smoke=get('jobs/p4-own-1gpu/4457110_0/launcher.result.json'),
        original_stage_results=state['stage_results'],reviewed_environment={'single_gpu':'PASS','four_gpu':'NO_RESOURCES'},
        confirmed_tool_defects=['sinfo mixed- excluded by exact string matching','four-card NO_RESOURCES invalidates successful single-card readiness','node variants repeat the same unavailable admission','baseline PASS reported without full node-matrix coverage'])
    save('reviewed-cases.json',reviewed);save('selected-evidence.json',selected);save('summary.json',summary)
print(json.dumps({'outcomes':dict(outcomes),'allocated':len(allocated),'nodes':summary['allocated_nodes'],'cat_checks':dict(summary['cat_checks']),'stress_cases_allocated':summary['stress_cases_allocated']},ensure_ascii=False,indent=2))
