"""Verify the two isolated ISP builds and fresh camera tests; no hardware I/O."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re, shutil, xml.etree.ElementTree as ET

P=Path(__file__).resolve().parents[1]
R=P/'reports/official_isp'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def inp(p):
    if p.name!='Ti60_Demo.xml': return sha(p)
    root=ET.fromstring(p.read_bytes())
    for k in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):
        root.attrib.pop(k,None)
    return hashlib.sha256(ET.tostring(root,encoding='utf-8')).hexdigest()

run=read(R/'run_started.json'); backup=Path(run['backup'])
started=datetime.fromisoformat(run['started_utc']).timestamp()
old=read(backup/'reports/vision8/build_input_sha256.json')
changed=[rel for rel,digest in old.items() if inp(P/rel)!=digest]
sensor='src/cmos_i2c/I2C_OV5640_1280720_Config.v'
assert set(changed)=={sensor,'src/parallel/rgb_balance_config.vh'},changed
cfg=(P/'src/parallel/rgb_balance_config.vh').read_text()
for macro in ('ENABLE','PROFILE_ENABLE'):
    assert re.search(r'^`define RGB_BALANCE_'+macro+r' 0$',cfg,re.M),macro
assert b"LENC_ENABLE  = 1'b0" in (P/sensor).read_bytes()
assert b'camera_rgb_balance camera_balance' in (P/'example_top.v').read_bytes()

ref=read(R/'official_reference.json')
assert sha(Path(ref['official_path']))==sha(P/ref['reference_copy'])==ref['sha256']
baseline=read(P/'reports/provenance/10_13_liu__Ti60_Vision8_Gesture_ROI_Integrated.json')
protected=[]
for rel,digest in baseline.items():
    first=rel.split('/')[0]
    if first in ('src','rtl','firmware','image','vendor','ip','tb') or ('/' not in rel and (rel.endswith(('.hex','.bin','.sdc')) or rel=='Ti60_Demo.peri.xml')):
        if rel==sensor: continue
        assert sha(P/rel)==digest,'Retained file changed: '+rel
        protected.append(rel)
for rel,digest in read(backup/'backup_sha256.json').items():
    assert sha(backup/rel)==digest,'Backup changed: '+rel

logs=[x['log'] for x in read(R/'sensor_tests.json')['tests']]
logs+=['reports/rgb_balance/official_isp_bypass/tb_camera_rgb_balance.log']
fifo=read(P/'reports/rgb_balance/camera_fifo_results.json')
assert len(fifo['tests'])==4
logs+=[x['log'] for x in fifo['tests']]
tests=[]
for rel in logs:
    f=P/rel; text=f.read_text(encoding='utf-8-sig',errors='replace')
    assert f.stat().st_mtime>=started,'Stale test: '+rel
    assert 'PASS:' in text and not re.search(r'Fatal:|Error:|^ERROR:',text,re.M),rel
    tests.append(dict(log=rel,status='PASS',sha256=sha(f)))
rgb=(P/logs[2]).read_text(errors='replace')
assert 'CONFIG: ENABLE=0' in rgb and 'CONFIG: PROFILE=0' in rgb
sensor_log=(P/logs[0]).read_text(errors='replace')
assert all(x in sensor_log for x in ('LENC=0 all 252','LENC=1 all 252','both 256-index ROM maps'))

stages=read(R/'stages.json'); builds={}; manifests={}
for label,stage_path in stages.items():
    stage=Path(stage_path)
    info=read(stage/'reports/build_verified.json')
    manifest=stage/'reports/vision8/build_input_sha256.json'
    assert sha(manifest)==info['build_input_manifest_sha256']
    inputs=read(manifest)
    for rel,digest in inputs.items():
        assert inp(stage/rel)==digest,'Staged input changed: '+label+':'+rel
        if rel!=sensor: assert inp(P/rel)==digest,'Unexpected A/B difference: '+rel
    current=(P/sensor).read_bytes(); staged=(stage/sensor).read_bytes()
    expected=current.replace(b"LENC_ENABLE  = 1'b0",b"LENC_ENABLE  = 1'b1",1) if label.startswith('A_') else current
    assert staged==expected,'Unexpected sensor difference: '+label
    for ext in ('bit','hex'):
        f=stage/('outflow/Ti60_Demo.'+ext)
        assert f.stat().st_mtime>=started and sha(f)==info[ext+'_sha256']
    assert info['min_setup_slack_ns']>=0 and info['min_hold_slack_ns']>=0
    assert all(v['used']<=v['available'] for v in info['resources'].values())
    builds[label]=info;manifests[label]=inputs
    shutil.copy2(stage/'reports/build_verified.json',R/(label+'_build_verified.json'))
    shutil.copy2(manifest,R/(label+'_build_inputs.json'))
    for name in ('Ti60_Demo.route.rpt','Ti60_Demo.timing.rpt'):
        shutil.copy2(stage/'outflow'/name,R/(label+'_'+name))
    shutil.copy2(stage/'reports/efinity_build.log',R/(label+'_efinity_build.log'))

assert set(manifests['A_official_lenc_on'])==set(manifests['B_candidate_lenc_off'])
assert [rel for rel in manifests['A_official_lenc_on'] if manifests['A_official_lenc_on'][rel]!=manifests['B_candidate_lenc_off'][rel]]==[sensor]
local=read(P/'reports/build_verified.json')
assert local==builds['B_candidate_lenc_off'],'Collect primary B build before verifying delivery'
for rel,digest in read(P/'reports/vision8/build_input_sha256.json').items():
    assert inp(P/rel)==digest,'Current build input changed: '+rel
downloads={}
for label,stage_path in stages.items():
    stem='Ti60_Demo_Camera_V3_'+('Official_LENC_On' if label.startswith('A_') else 'LENC_Off')
    downloads[label]={}
    for ext in ('bit','hex'):
        target=P/'outflow'/(stem+'.'+ext)
        shutil.copy2(Path(stage_path)/'outflow'/('Ti60_Demo.'+ext),target)
        assert sha(target)==builds[label][ext+'_sha256']
        downloads[label][ext]=target.relative_to(P).as_posix()
        if label.startswith('B_'): assert sha(P/'outflow'/('Ti60_Demo.'+ext))==sha(target)
result=dict(revision='official_isp_comparison_v3',completed_utc=datetime.now(timezone.utc).isoformat(),
    project=str(P),backup=str(backup),official_reference=ref,changed_build_inputs=changed,
    retained_baseline_files_unchanged=len(protected),intentional_baseline_exception=sensor,
    test_count=len(tests),tests=tests,builds=builds,download_files=downloads,
    default_variant='B_candidate_lenc_off',fpga_spatial_rgb_correction=False,
    A='Official sensor table, LENC on, FPGA gain bypass',B='Only 0x5000 bit7 cleared, LENC off, FPGA gain bypass',
    previous_board_feedback='User reports V2 colour rings remain',
    hardware_programming='not performed',physical_board_test='not performed for V3',
    optical_diagnosis='Lens-table mismatch is a hypothesis; pending controlled A/B board comparison')
(R/'final_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
(P/'reports/rgb_balance/final_validation.json').write_text(json.dumps(dict(
    current_revision=result['revision'],current_validation='reports/official_isp/final_validation.json',
    test_count=len(tests),build=local,physical_board_test=result['physical_board_test']),indent=2),encoding='utf-8')
print(json.dumps(dict(test_count=len(tests),retained_files=len(protected),changed_build_inputs=changed,
    download_files=downloads,builds=builds,physical_board_test=result['physical_board_test']),indent=2))
