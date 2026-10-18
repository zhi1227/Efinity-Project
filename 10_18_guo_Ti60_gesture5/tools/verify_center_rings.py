"""ding 2026-10-15: evidence for the central colour-shading retune only.

Retained non-camera regressions belong to the previous revision, not this run.
No programming or optical acceptance is performed by this tool.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re, xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/center_rings'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def input_sha(p):
    if p.name != 'Ti60_Demo.xml': return sha(p)
    root = ET.fromstring(p.read_bytes())
    for k in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):
        root.attrib.pop(k, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()

run = read(R/'run_started.json')
started = datetime.fromisoformat(run['started_utc']).timestamp()
backup = Path(run['backup'])
old_inputs = read(backup/'reports/vision8/build_input_sha256.json')
changed = [rel for rel,digest in old_inputs.items() if input_sha(P/rel) != digest]
assert set(changed) == {'rtl/camera_rgb_balance.v','src/parallel/rgb_balance_config.vh'}, changed

protected = {}
baseline = read(P/'reports/provenance/10_13_liu__Ti60_Vision8_Gesture_ROI_Integrated.json')
for rel,digest in baseline.items():
    first = rel.split('/')[0]
    if first in ('src','rtl','firmware','image','vendor','ip','tb') or ('/' not in rel and (rel.endswith(('.hex','.bin','.sdc')) or rel=='Ti60_Demo.peri.xml')):
        assert sha(P/rel)==digest, 'Retained baseline changed: '+rel
        protected[rel]=digest

logs = ['reports/rgb_balance/'+n+'/tb_camera_rgb_balance.log' for n in
        ('center_rings_trial','center_rings_disabled','center_rings_legacy','center_rings_custom')]
fifo = read(P/'reports/rgb_balance/camera_fifo_results.json')
assert len(fifo['tests'])==4
logs += [test['log'] for test in fifo['tests']]
tests=[]
for rel in logs:
    f=P/rel
    assert f.stat().st_mtime>=started, 'Stale test: '+rel
    text=f.read_text(encoding='utf-8-sig',errors='replace')
    assert 'PASS:' in text and not re.search(r'Fatal:|Error:|^ERROR:',text,re.M),rel
    tests.append({'log':rel,'status':'PASS','sha256':sha(f)})
assert 'PROFILE=1' in (P/logs[0]).read_text(errors='replace')
assert 'PROFILE=0' in (P/logs[2]).read_text(errors='replace')

build=read(P/'reports/build_verified.json')
manifest=P/'reports/vision8/build_input_sha256.json'
assert sha(manifest)==build['build_input_manifest_sha256']
inputs=read(manifest)
for rel,digest in inputs.items():assert input_sha(P/rel)==digest,'Build input mismatch: '+rel
for ext in ('bit','hex'):
    f=P/('outflow/Ti60_Demo.'+ext)
    assert f.stat().st_mtime>=started and sha(f)==build[ext+'_sha256'],ext
assert build['min_setup_slack_ns']>=0 and build['min_hold_slack_ns']>=0
assert build['resources']['Memory Blocks']['used']<=230
for item in build['resources'].values():assert item['used']<=item['available']

config=(P/'src/parallel/rgb_balance_config.vh').read_text()
gains={k:int(v) for k,v in re.findall(r'^`define\s+RGB_BALANCE_(\w+)\s+(\d+)\s*$',config,re.M)}
assert len(gains)==17 and gains['PROFILE_ENABLE']==1
for rel,digest in read(backup/'backup_sha256.json').items():
    assert sha(backup/rel)==digest,'Backup changed: '+rel

result=dict(author='ding',date='2026-10-15',revision='central_three_region_trial_v2',
    project=str(P),completed_utc=datetime.now(timezone.utc).isoformat(),backup=str(backup),
    changed_build_inputs=changed,retained_baseline_files_unchanged=len(protected),
    test_count=len(tests),tests=tests,build=build,build_input_count=len(inputs),
    fixed_rgb_gains_q8_8=gains,protected_weight_range=[0,64],profile_knots=[128,192,256],
    previous_hardware_observation='User white-background monitor photographs from previous revision',
    physical_board_test='not performed for this revision',hardware_programming='not performed',
    optical_calibration='experimental conservative retune; white/grey target and coloured objects pending',
    previous_full_regressions='Archived with the previous revision; not claimed as rerun for this retune')
(R/'final_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
pointer=dict(current_revision='central_three_region_trial_v2',current_validation='reports/center_rings/final_validation.json',
    test_count=len(tests),build=build,previous_full_validation=str(backup/'reports/rgb_balance/final_validation.json'),
    physical_board_test='not performed for this revision')
(P/'reports/rgb_balance/final_validation.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'test_count':len(tests),'changed_build_inputs':changed,'retained_files':len(protected),
    'resources':build['resources'],'setup_ns':build['min_setup_slack_ns'],'hold_ns':build['min_hold_slack_ns'],
    'bit_sha256':build['bit_sha256'],'physical_board_test':result['physical_board_test']},ensure_ascii=False,indent=2))
