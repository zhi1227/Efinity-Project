"""Finalize only real complete, current-source, SHA-bound inline-threshold tests."""
from pathlib import Path
import datetime as dt,hashlib,json,re,shutil
from inline_threshold_build import inputs
P=Path(__file__).resolve().parents[1];R=P/'reports/inline_threshold'
def read(f):return json.loads(f.read_text(encoding='utf-8-sig'))
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def source_list(value):
 if isinstance(value,dict):return [{'path':k,'sha256':v.lower()} for k,v in value.items()]
 return [{'path':x['path'],'sha256':x['sha256'].lower()} for x in value]
checks=[]
def add(name,logs,sources):
 sources=source_list(sources)
 for item in sources:assert sha(P/item['path'])==item['sha256'],'Source drift: '+item['path']
 record=dict(name=name,status='PASS',logs=[],expected_log_sha256={},completion_markers={},sources=sources)
 for path,expected,markers in logs:
  f=P/path;data=f.read_bytes();text=data.decode('utf-8-sig',errors='replace')
  assert sha(f)==expected.lower(),'Log SHA drift: '+path
  assert all(m in text for m in markers),'Incomplete test: '+path
  assert not re.search(r'Fatal:|FATAL|Error:|^ERROR:',text,re.M),'Failed test: '+path
  dst=R/'final_logs'/name/f.name
  rel=dst.relative_to(P).as_posix()
  record['logs'].append(rel);record['expected_log_sha256'][rel]=expected.lower();record['completion_markers'][rel]=markers
  # Defer copying until ALL required groups are actually complete.
  record.setdefault('_copies',[]).append((f,dst))
 checks.append(record)
ctrl=read(R/'controls/inputs.json')
f=R/'controls/tb_inline_controls.log'
add('controls_95',[(f.relative_to(P).as_posix(),sha(f),['PASS: INLINE_CONTROLS_COMPLETE checks=95 frames=7;','$finish called'])],ctrl)
f=R/'controls/tb_vision8_key_boundary.log'
add('io28_boundaries',[(f.relative_to(P).as_posix(),sha(f),['PASS: vision8_key same-edge NBA context changes mask pending short/long','$finish called'])],ctrl)
video=read(R/'video/results.json');assert video['status']=='PASS','Video suite still incomplete'
for row in video['results']:
 name='video_dynamic' if row['bench']=='tb_inline_video_dynamic' else 'video_defaults'
 add(name,[(row['log'],row['sha256'],row['completion_markers'])],video['sources'])
assert len(video['results'])==2
ui=read(P/'reports/fourkey/ui/results.json');assert ui['status']=='PASS'
for row in ui['logs']:
 add('font_dualclock' if row['name']=='font' else 'ui_pixels',[(row['path'],row['sha256'],[row['completion_marker'],'$finish called'])],ui['input_sha256'])
cap=read(R/'capture/summary.json');assert cap['status']=='PASS'
cap_sources=read(R/'capture/input_sha256.json')
row=cap['results'][0]
add('capture_binding',[('reports/inline_threshold/capture/'+row['log'],row['log_sha256'],row['completion_markers'])],cap_sources)
retained=read(R/'retained/results.json');retained_sources=read(R/'retained/input_sha256.json')
expected={'tb_vision8_key_boundary','tb_vision8_fifo','tb_vision8_ddr','tb_vision8_frames','tb_vision8_faces','tb_io29_freeze_ddr','tb_vision8_gesture','tb_h5_palm','tb_h5_wave','tb_gesture5_controls_new','tb_gesture5_templates_ramopt','tb_gesture5_rgb_ramopt','tb_gesture5_shared_overlay_ramopt','tb_h4_skin','tb_h4_overlay','tb_controls6','tb_matrix5_ramopt','tb_h5_ui','tb_i2c6','tb_health6','tb_frame_path','tb_menu_cdc6','tb_camera_rgb_fifo'}
assert {x['bench'] for x in retained}==expected,'Retained suite incomplete'
for row in retained:
 assert row['status']=='PASS'
 add('retained_'+row['bench'],[('reports/inline_threshold/retained/'+row['log'],row['log_sha256'],row['completion_markers'])],retained_sources)
for kind,name in [('cpu8','cpu8_real'),('epaper','epaper_real')]:
 group=read(R/kind/'results.json');assert group['status']=='PASS',kind+' incomplete'
 add(name,[(x['path'],x['sha256'],[x['completion_marker'],'$finish called']) for x in group['logs']],group['input_sha256'])
assert len(checks)==32,'Unexpected check coverage'
for c in checks:
 for src,dst in c.pop('_copies'):
  dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
  assert sha(dst)==c['expected_log_sha256'][dst.relative_to(P).as_posix()]
meta=read(R/'protection.json')
summary={'status':'PASS','started_utc':meta['created_utc'],'completed_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'production_inputs':inputs(P),'checks':checks,'hardware_programming':'not performed','physical_board_test':'not performed'}
(R/'tests.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: 32 complete source-bound inline-threshold checks archived and finalized')
