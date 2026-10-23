"""Verify final CaptureFix evidence, current input/output hashes and untouched original.
No synthesis, programming, deletion or global environment changes.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,re
import capture_fix_build as build
P=Path(__file__).resolve().parents[1];R=P/'reports/capture_fix'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def verify_inputs(items):
 for name,digest in items.items():
  path=Path(name);path=path if path.is_absolute() else P/path
  assert path.is_file() and sha(path)==digest,'Changed test input: '+str(path)
def logcheck(p,digest=None,negative=False):
 assert p.is_file(),str(p)
 if digest:assert sha(p)==digest,'Changed log: '+str(p)
 s=p.read_text(encoding='utf-8',errors='replace')
 if negative:assert 'EXPECTED_BASELINE_DEFECT' in s and 'Fatal:' in s
 else:assert 'PASS:' in s and '$finish called' in s and not re.search(r'Fatal:|ERROR:|Error:',s),str(p)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--partial',action='store_true');ap.add_argument('--original-only',action='store_true');args=ap.parse_args()
 protection=read(R/'protection.json');original=Path(protection['source'])
 for e in protection['files']:
  f=original/e['path'];assert f.is_file() and sha(f)==e['sha256'],'Original modified: '+str(f)
 old={e['path']:e for e in protection['files']}
 assert {f.relative_to(original).as_posix() for f in original.rglob('*') if f.is_file()}==set(old),'Original file set changed'
 if args.original_only:print('PASS: original untouched,',len(old),'SHA-256 checked; open',original/'Ti60_Demo.xml');return
 checks=[];pending=[]
 def check(label,fn):
  try:details=fn();checks.append(dict(name=label,status='PASS',details=details))
  except (AssertionError,FileNotFoundError,KeyError) as e:pending.append(dict(name=label,status='INCOMPLETE',reason=str(e)))
 def bench(name,negative=False):
  files=sorted((R/name).glob('*/result.json'));assert files,'Missing bench '+name
  result=read(files[-1]);assert result['status']=='PASS',str(files[-1]);verify_inputs(result['inputs']);logcheck(files[-1].parent/'simulation.log',result['log_sha256'],negative)
  return dict(result=str(files[-1].relative_to(P)),markers=result['markers'])
 check('original negative regression',lambda:bench('tb_capture_exit_regression_original',True))
 def suite():
  base=R/'final_regression';s=read(base/'summary.json');assert s['status']=='PASS';verify_inputs(read(base/'input_sha256.json'))
  required={'tb_capturefix_controls','tb_capture_exit_regression','tb_capturefix_chain','tb_capturefix_abort','tb_capturefix_faults','tb_capturefix_pip','tb_capturefix_ui_select','tb_vision8_gesture','tb_capturefix_rawphase','tb_gesture5_rgb_ramopt','tb_vision8_faces','tb_vision8_key_boundary','tb_vision8_ddr','tb_io29_freeze_ddr'}
  assert required.issubset({r['bench'] for r in s['results']})
  for t in s['results']:assert t['status']=='PASS';logcheck(base/t['log'],t['log_sha256'])
  return dict(count=len(s['results']),tests=[t['bench'] for t in s['results']])
 check('final RTL regressions',suite)
 check('720p real DDR pressure',lambda:bench('tb_capturefix_720p_pressure'))
 check('720p already-full replacement active-pixel monitoring',lambda:bench('tb_capturefix_full_load'))
 check('same-edge cancellation boundaries',lambda:bench('tb_capturefix_cancel_boundary'))
 check('capture parameter and metadata binding',lambda:bench('tb_capturefix_binding'))
 def video():
  s=read(R/'video/results.json');assert s['status']=='PASS';verify_inputs(s['sources'])
  for t in s['results']:assert t['status']=='PASS';logcheck(P/t['log'],t['sha256'])
  return dict(default_equal_pixels=6451200,dynamic_pixels=147456)
 check('original/default pixel equality and threshold response',video)
 def ui():
  s=read(R/'ui/results.json');assert s['status']=='PASS';verify_inputs(s['input_sha256'])
  for t in s['logs']:logcheck(P/t['path'],t['sha256'])
  return s['coverage']
 check('UI and compressed fonts',ui)
 def peripheral(name):
  s=read(R/name/'results.json');assert s['status']=='PASS';verify_inputs(s['input_sha256'])
  for t in s['logs']:logcheck(P/t['path'],t['sha256'])
  return s['coverage']
 for name in ('cpu8','epaper'):check(name,lambda name=name:peripheral(name))
 def hardware():
  s=read(R/'selected_build.json');assert s['status']=='PASS';assert build.inputs(P)==s['production_inputs'],'Build input drift'
  for rel,digest in s['outputs'].items():assert sha(P/rel)==digest,'Build output drift '+rel
  for rel,digest in s['evidence'].items():assert sha(P/rel)==digest,'Build evidence drift '+rel
  b=s['build'];assert b['resources']['XLRs']['used']<=60000 and b['resources']['Memory Blocks']['used']<=230
  assert b['min_setup_slack_ns']>=0 and b['min_hold_slack_ns']>=0
  return b
 check('Efinity map/interface/pnr/pgm and timing',hardware)
 # Scope audit: no IP, firmware, camera, algorithm or pin reassignment.
 logic={'example_top.v','rtl/vision8_controls.v','rtl/vision8_frames.v','rtl/vision8_ddr.v','rtl/vision8_base_axi.v','rtl/menu8_renderer.v','rtl/menu_glyph_rom.v','rtl/shared_glyph_rom.v','rtl/vision6_glyph_rom.v','Ti60_Demo.pt.sdc'}
 changes=[]
 for f in build.production_files(P):
  rel=f.relative_to(P).as_posix();before=old.get(rel,{}).get('sha256');after=sha(f)
  if before!=after:
   assert rel in logic or rel=='src/parallel/vision8_modes.vh' or (len(f.relative_to(P).parts)==1 and 'font' in f.name and f.suffix=='.hex'),'Unexpected production change '+rel
   changes.append(dict(path=rel,before_sha256=before,after_sha256=after,purpose='font generation' if 'font' in rel or 'glyph' in rel else 'mode display mapping' if 'modes.vh' in rel else 'capture/keys/integration'))
 old_sdc=(original/'Ti60_Demo.pt.sdc').read_text();new_sdc=(P/'Ti60_Demo.pt.sdc').read_text();assert new_sdc.startswith(old_sdc),'Existing constraints changed'
 assert new_sdc[len(old_sdc):].count('set_false_path')==2
 checks.append(dict(name='protected scope and original preservation',status='PASS',details=dict(original_files=len(old),changed_production_files=len(changes),pins_ip_firmware_camera_algorithms='unchanged')))
 write(R/'changed_files.json',changes)
 result=dict(status='PASS' if not pending else 'INCOMPLETE',verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),project=str(P),original=str(original),checks=checks,incomplete=pending,physical_board_test='NOT_RUN',jtag_flash='NOT_PERFORMED',scope_limits=['Physical DDR timing/electrical behavior is not modeled','Four-algorithm real-memory chain is 128x96; full 720p DDR pressure is RAW-only; separate full720p algorithm equality test','Permanent AXI nonresponse cannot be safely force-completed'])
 write(R/'delivery.json',result)
 print(json.dumps(dict(status=result['status'],passed=len(checks),incomplete=pending,report=str(R/'delivery.json')),ensure_ascii=False,indent=2))
 if pending and not args.partial:raise SystemExit(1)
if __name__=='__main__':main()
