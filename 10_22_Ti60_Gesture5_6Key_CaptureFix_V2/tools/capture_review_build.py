"""Fresh ASCII Efinity build and hash-bound collection; never programs hardware.

Use prepare STAGE, build STAGE, collect STAGE.  STAGE must be new and ASCII.
build must be invoked with the host's elevated tool permission when required by
Efinity installation access.  PYTHONHOME is local to the child PowerShell only.
Existing build_fpga.ps1 and verify_build.py are used without editing their rules.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, shutil, subprocess, sys, uuid
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/capture_review'
VOLATILE = ('last_change', 'last_run_state', 'last_run_flow',
            'config_result_in_sync', 'design_ood', 'place_ood', 'route_ood')
EXT = {'.v', '.sv', '.vh', '.hex', '.bin', '.xml', '.sdc', '.mem'}
ROOTS = {'rtl', 'src', 'vendor', 'ip', 'image'}
BUILD_TOOLS = {'build_fpga.ps1', 'verify_build.py', 'capture_review_build.py'}

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): h.update(block)
    return h.hexdigest()

def input_sha(path):
    if path.name != 'Ti60_Demo.xml': return sha(path)
    root = ET.fromstring(path.read_bytes())
    for key in VOLATILE: root.attrib.pop(key, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()

def production_files(base):
    return sorted(p for p in base.rglob('*') if p.is_file()
                  and '__pycache__' not in p.parts
                  and p.suffix.lower() in EXT
                  and (p.relative_to(base).parts[0] in ROOTS or len(p.relative_to(base).parts) == 1))

def inputs(base):
    return {p.relative_to(base).as_posix(): input_sha(p) for p in production_files(base)}

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
def now(): return datetime.now(timezone.utc).isoformat()

def stage_record(stage):
    record = read(stage / 'inline_build_stage.json')
    assert Path(record['project']).resolve() == P
    assert Path(record['stage']).resolve() == stage
    return record

def validate_sources(stage, record):
    assert inputs(P) == record['production_inputs'], 'Current production sources changed; prepare a fresh stage'
    assert inputs(stage) == record['production_inputs'], 'Staged production sources changed'
    for rel, expected in record['build_tools'].items():
        assert sha(P/rel) == expected and sha(stage/rel) == expected, 'Build tool changed: '+rel

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=('prepare','build','collect'))
    ap.add_argument('stage', type=Path)
    ap.add_argument('--efinity', type=Path, default=Path(r'C:\Efinity\2025.1'))
    args = ap.parse_args(); stage = args.stage.resolve()
    assert str(stage).isascii(), 'Use a fresh ASCII directory'
    assert stage != P and not stage.is_relative_to(P) and not P.is_relative_to(stage)
    R.mkdir(parents=True, exist_ok=True)
    if args.action == 'prepare':
        assert not stage.exists(), 'Never reuse an old build directory'
        stage.mkdir(parents=True)
        sources = production_files(P) + [P/'tools'/name for name in sorted(BUILD_TOOLS)]
        for source in sources:
            target = stage/source.relative_to(P); target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            assert sha(target) == sha(source)
        (stage/'reports/vision8').mkdir(parents=True)
        record = {'project':str(P),'stage':str(stage),'prepared_utc':now(),
                  'production_inputs':inputs(P),
                  'build_tools':{'tools/'+n:sha(P/'tools'/n) for n in sorted(BUILD_TOOLS)},
                  'hardware_programming':'not performed'}
        assert inputs(stage) == record['production_inputs']
        write(stage/'inline_build_stage.json', record)
        write(R/'build_stage.json', record)
        print('PASS: fresh ASCII inputs copied and verified:',stage,len(record['production_inputs']))
    elif args.action == 'build':
        record = stage_record(stage); validate_sources(stage, record)
        assert not (stage/'outflow').exists(), 'Stage already has build outputs; prepare another directory'
        assert (args.efinity/'scripts/efx_run.py').is_file()
        record['build_started_utc'] = now(); write(stage/'inline_build_stage.json',record)
        command = ['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',
                   str(stage/'tools/build_fpga.ps1'),'-Efinity',str(args.efinity)]
        # Efinity's old wrapper can return 0 despite failure. build_fpga.ps1
        # additionally requires every stage PASS and executes verify_build.py.
        run = subprocess.run(command,cwd=stage)
        record['build_exit_code'] = run.returncode; record['build_completed_utc'] = now()
        write(stage/'inline_build_stage.json',record)
        assert run.returncode == 0, 'Build failed; retain stage/logs and use a new stage for retry'
        validate_sources(stage,record)
        result = read(stage/'reports/build_verified.json')
        assert sha(stage/'outflow/Ti60_Demo.bit') == result['bit_sha256']
        assert sha(stage/'outflow/Ti60_Demo.hex') == result['hex_sha256']
        print('PASS: full build and existing resource/timing checker; no hardware programmed')
    else:
        record = stage_record(stage); validate_sources(stage,record)
        assert record.get('build_exit_code') == 0 and record.get('build_completed_utc')
        assert not (P/'outflow').exists(), 'Refuse to overwrite any current outputs'
        result = read(stage/'reports/build_verified.json')
        for suffix in ('bit','hex'):
            assert sha(stage/f'outflow/Ti60_Demo.{suffix}') == result[suffix+'_sha256']
        manifest = read(stage/'reports/vision8/build_input_sha256.json')
        assert all(record['production_inputs'].get(n)==h for n,h in manifest.items())
        # Recheck all PASS/failure markers from the completed child log.
        raw = (stage/'reports/efinity_build.log').read_bytes()
        log = raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
        for name in ('map','interface','pnr','pgm'):
            assert re.search(r'^\s*'+name+r'\s*:\s*PASS',log,re.M),name
        out = P/'outflow'
        assembled=R/('collected_outflow_'+uuid.uuid4().hex)
        assembled.mkdir()
        output_hashes = {}
        for source in sorted((stage/'outflow').iterdir()):
            if source.is_file():
                target=assembled/source.name;shutil.copy2(source,target)
                assert sha(source)==sha(target)
                output_hashes['outflow/'+source.name] = sha(target)
        evidence=R/'build'; evidence.mkdir(exist_ok=False)
        for rel in ('reports/efinity_build.log','reports/build_verified.json','reports/vision8/build_input_sha256.json','inline_build_stage.json'):
            dest=evidence/Path(rel).name;shutil.copy2(stage/rel,dest)
        # Atomic directory rename exposes either a complete verified set or none.
        assert not out.exists()
        assembled.rename(out)
        selected={'status':'PASS','collected_utc':now(),'stage':str(stage),'build':result,
                  'production_inputs':record['production_inputs'],'outputs':output_hashes,
                  'evidence':{p.relative_to(P).as_posix():sha(p) for p in sorted(evidence.iterdir()) if p.is_file()},
                  'hardware_programming':'not performed'}
        write(R/'selected_build.json',selected)
        print(json.dumps({'status':'PASS','outputs':len(output_hashes),'build':result},indent=2))
    return 0

if __name__ == '__main__': sys.exit(main())
