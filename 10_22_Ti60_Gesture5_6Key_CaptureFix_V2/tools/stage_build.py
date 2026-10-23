"""Stage Efinity inputs in an ASCII directory; copy verified outputs back only.

Usage: python tools/stage_build.py prepare|collect ASCII_DIRECTORY
The separate directory avoids Efinity's Windows non-ASCII path error.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

project = Path(__file__).resolve().parents[1]
stage = Path(sys.argv[2]).resolve()
assert str(stage).isascii(), 'Efinity requires an ASCII build path'
assert stage != project and project not in stage.parents and stage not in project.parents
manifest = project / 'reports/rgb_balance/staged_inputs.json'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

if sys.argv[1] == 'prepare':
    # A new directory prevents an old bitstream from being mistaken for this build.
    stage.mkdir(parents=True, exist_ok=False)
    hashes = {}
    for source in project.rglob('*'):
        rel = source.relative_to(project)
        if not source.is_file() or '__pycache__' in rel.parts:
            continue
        # Stage only actual FPGA inputs and its build/verification entrypoints.
        # Tests and documentation can be finalized without changing build inputs.
        source_roots = ('src', 'rtl', 'vendor', 'ip', 'image')
        build_tools = ('build_fpga.ps1', 'verify_build.py', 'stage_build.py')
        if len(rel.parts) == 1:
            if source.suffix.lower() not in ('.v', '.sv', '.vh', '.hex', '.bin', '.xml', '.sdc'):
                continue
        elif rel.parts[0] == 'tools':
            if rel.name not in build_tools:
                continue
        elif rel.parts[0] not in source_roots:
            continue
        if source.suffix.lower() in ('.md', '.png', '.jpg', '.jpeg', '.pdf'):
            continue
        target = stage / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        hashes[rel.as_posix()] = digest(source)
    (stage / 'reports/vision8').mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({'stage':str(stage), 'files':hashes}, indent=2), encoding='utf-8')
    print(f'Staged {len(hashes)} files at {stage}')
elif sys.argv[1] == 'collect':
    data = json.loads(manifest.read_text(encoding='utf-8'))
    assert Path(data['stage']) == stage
    for rel, expected in data['files'].items():
        # Efinity modifies only bookkeeping attributes of the project XML.
        if rel != 'Ti60_Demo.xml':
            assert digest(project / rel) == expected, f'Local source changed during build: {rel}'
            assert digest(stage / rel) == expected, f'Staged source changed during build: {rel}'
    verified = json.loads((stage / 'reports/build_verified.json').read_text())
    assert digest(stage / 'outflow/Ti60_Demo.bit') == verified['bit_sha256']
    assert digest(stage / 'outflow/Ti60_Demo.hex') == verified['hex_sha256']
    (project / 'outflow').mkdir(exist_ok=True)
    for source in (stage / 'outflow').iterdir():
        if source.is_file(): shutil.copy2(source, project / 'outflow' / source.name)
    for rel in ('reports/efinity_build.log', 'reports/build_verified.json', 'reports/vision8/build_input_sha256.json'):
        shutil.copy2(stage / rel, project / rel)
    print('Collected verified bitstream, reports and source manifest')
else:
    raise SystemExit('Expected prepare or collect')
