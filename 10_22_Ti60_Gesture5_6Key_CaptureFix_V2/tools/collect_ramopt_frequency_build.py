"""Strictly collect the already-built, source-identical frequency-font staging build.

No source is generated or copied. Execute only after the owner has archived the
value-order build, installed the six frequency-font source assets in the parent,
and confirmed staging compilation has finished. Explicit --collect is required.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, shutil, subprocess, sys, xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P/'reports/ram_optimization_20261020'
S = R/'font_frequency_full_map'
OUTPUT = R/'frequency_build_collection.json'
VOLATILE = ('last_change','last_run_state','last_run_flow','config_result_in_sync',
            'design_ood','place_ood','route_ood')
SUFFIXES = {'.v','.sv','.vh','.hex','.bin','.mem','.xml','.sdc'}
REPORTS = ('reports/efinity_build.log','reports/build_verified.json',
           'reports/vision8/build_input_sha256.json')

def require(ok, message):
    if not ok: raise AssertionError(message)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))

def input_hash(path):
    if path.name != 'Ti60_Demo.xml': return sha(path)
    root = ET.fromstring(path.read_bytes())
    for key in VOLATILE: root.attrib.pop(key,None)
    return hashlib.sha256(ET.tostring(root,encoding='utf-8')).hexdigest()

def current_inputs(project):
    paths = [f for name in ('rtl','src','vendor','ip') for f in (project/name).rglob('*')
             if f.is_file() and f.suffix.lower() in SUFFIXES]
    paths += [f for f in project.iterdir() if f.is_file() and f.suffix.lower() in SUFFIXES]
    return {f.relative_to(project).as_posix():input_hash(f) for f in sorted(set(paths))}

def readonly_verify(project, expected_checker):
    require(sha(project/'tools/verify_build.py') == expected_checker, 'Staging/parent build checker is not the original checker')
    guarded = ('reports/build_verified.json','reports/vision8/build_input_sha256.json',
               'outflow/Ti60_Demo.bit','outflow/Ti60_Demo.hex')
    before = {n:sha(project/n) for n in guarded}
    code = r'''
from pathlib import Path
import json,runpy,sys
p=Path(sys.argv[1]).resolve();target=p/'reports/build_verified.json'
saved=json.loads(target.read_text(encoding='utf-8-sig'));seen=[]
def no_write(self,data,*args,**kwargs):
 assert self.resolve()==target.resolve(),'Unexpected checker write'
 assert json.loads(data)==saved,'Existing build_verified.json differs from current verified build'
 seen.append(str(self));return len(data)
Path.write_text=no_write
sys.argv=[str(p/'tools/verify_build.py')]
runpy.run_path(sys.argv[0],run_name='__main__')
assert len(seen)==1,'Checker did not reach final evidence validation'
'''
    result = subprocess.run([sys.executable,'-B','-c',code,str(project)],capture_output=True,
                            text=True,encoding='utf-8',errors='replace')
    require(result.returncode == 0, f'Read-only build verification failed: {project}\n{result.stdout}\n{result.stderr}')
    require(before == {n:sha(project/n) for n in guarded}, 'Read-only checker changed evidence')
    return json.loads(result.stdout)

def verify_parent_source_dates(bit):
    files = list((P/'rtl').glob('*.v'))+list((P/'src').rglob('*.v'))
    files += list((P/'src').rglob('*.vh'))+list((P/'vendor').glob('*.v'))
    files += [P/'example_top.v']+list(P.glob('*font*.hex'))+list(P.glob('EfxSapphireSoc*.bin'))
    late = [f.relative_to(P).as_posix() for f in files if f.stat().st_mtime > bit.stat().st_mtime]
    require(not late, 'Parent sources are newer than staging bit; no timestamp alteration is allowed: '+str(late))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collect',action='store_true',help='Validate then copy only staging output artifacts and three build reports')
    args = parser.parse_args()
    if not args.collect:
        print('No action taken. After archiving and installing matching parent source assets, invoke with --collect.')
        return 0
    record = {'status':'FAIL','started_utc':datetime.now(timezone.utc).isoformat(),
              'stage':str(S),'parent':str(P),'hardware_validation':'not performed',
              'copy_policy':'Only staging outflow files and three specified build reports; copy2 preserves timestamps; no source edits'}
    copied = []
    try:
        require(S.is_dir() and S.resolve().is_relative_to(R.resolve()), 'Unexpected/missing staging project')
        require(S.resolve() != P.resolve(), 'Staging is the parent itself')
        original = read(R/'original_before.json')
        checker_sha = original['files']['tools/verify_build.py']
        snapshot_path = S/'reports/vision8/build_input_sha256.json'
        snapshot = read(snapshot_path)
        require(len(snapshot)==504, f'Unexpected staging input set: {len(snapshot)}; this collector is bound to the 504-file build')
        require(current_inputs(S)==snapshot, 'Staging canonical inputs differ from its compiled input manifest')
        require(current_inputs(P)==snapshot, 'Parent canonical inputs differ from the staging compiled inputs; collection refused')
        record['source_input_files'] = len(snapshot)
        record['source_input_manifest_sha256'] = sha(snapshot_path)
        record['stage_verified'] = readonly_verify(S,checker_sha)
        require(record['stage_verified']['build_input_manifest_sha256']==sha(snapshot_path), 'Staging manifest hash mismatch')
        require(record['stage_verified']['bit_sha256']==sha(S/'outflow/Ti60_Demo.bit'), 'Staging bit mismatch')
        require(record['stage_verified']['hex_sha256']==sha(S/'outflow/Ti60_Demo.hex'), 'Staging hex mismatch')
        require(sha(P/'tools/verify_build.py')==checker_sha, 'Parent build checker changed')
        verify_parent_source_dates(S/'outflow/Ti60_Demo.bit')
        output_root = S/'outflow'
        files = [f for f in output_root.rglob('*') if f.is_file()]
        require(bool(files),'Staging outflow is empty')
        for required in ('Ti60_Demo.bit','Ti60_Demo.hex','Ti60_Demo.route.rpt','Ti60_Demo.timing.rpt'):
            require((output_root/required).is_file(),'Missing staging artifact: '+required)
        sources = [(f,'outflow/'+f.relative_to(output_root).as_posix()) for f in files]
        sources += [(S/name,name) for name in REPORTS]
        hashes = {name:sha(f) for f,name in sources}
        dates = {name:f.stat().st_mtime_ns for f,name in sources}
        # Every destination is confined to parent/outflow or the three exact
        # report paths. No recursive move/delete or source copying is used.
        for source,name in sorted(sources,key=lambda pair:pair[1]):
            require(source.resolve().is_relative_to(S.resolve()) and not source.is_symlink(),'Staging artifact resolves outside staging')
            destination = (P/name).resolve()
            require(destination.is_relative_to(P.resolve()),'Destination resolves outside parent')
            require(name.startswith('outflow/') or name in REPORTS,'Unexpected collection destination: '+name)
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,destination)
            require(sha(destination)==hashes[name],'Copied artifact hash mismatch: '+name)
            require(destination.stat().st_mtime_ns==dates[name],'Copied artifact timestamp mismatch: '+name)
            copied.append({'path':name,'sha256':hashes[name],'mtime_ns':dates[name]})
        require(hashes=={name:sha(f) for f,name in sources},'Staging outputs changed during collection')
        require(current_inputs(P)==snapshot,'Parent sources changed during collection')
        record['parent_verified'] = readonly_verify(P,checker_sha)
        require(record['parent_verified']==record['stage_verified'],'Parent and staging verified build data differ after collection')
        record['final_bit_sha256'] = sha(P/'outflow/Ti60_Demo.bit')
        record['final_hex_sha256'] = sha(P/'outflow/Ti60_Demo.hex')
        record['copied_files'] = copied
        record['status'] = 'PASS'
    except Exception as error:
        record['error'] = f'{type(error).__name__}: {error}'
        record['copied_files'] = copied
    record['ended_utc'] = datetime.now(timezone.utc).isoformat()
    OUTPUT.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'status':record['status'],'report':str(OUTPUT),'error':record.get('error'),
                      'copied_file_count':len(copied)},ensure_ascii=True,indent=2))
    return 0 if record['status']=='PASS' else 1

if __name__=='__main__':sys.exit(main())
