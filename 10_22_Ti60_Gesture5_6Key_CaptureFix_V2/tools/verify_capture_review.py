"""Read-only acceptance by default. Explicit evidence selection, no newest-run fallback.

--publish --output NEW_FILE creates one new delivery file, refusing overwrite.
All counters are parsed from the selected simulator logs; no claimed pixel counts
are synthesized by the verifier. Physical validation remains NOT_RUN.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,re,sys
sys.dont_write_bytecode=True
import capture_review_build as build
P=Path(__file__).resolve().parents[1]
OLD={'example_top.v','rtl/vision8_controls.v','rtl/vision8_frames.v','rtl/vision8_ddr.v','rtl/vision8_base_axi.v','rtl/menu8_renderer.v','rtl/menu_glyph_rom.v','rtl/shared_glyph_rom.v','rtl/vision6_glyph_rom.v','Ti60_Demo.pt.sdc','src/parallel/vision8_modes.vh'}
REQUIRED=set('''tb_vision8_key_boundary tb_vision8_fifo tb_vision8_ddr tb_vision8_faces tb_io29_freeze_ddr tb_h5_palm tb_h5_wave tb_gesture5_controls_new tb_gesture5_templates_ramopt tb_gesture5_rgb_ramopt tb_gesture5_shared_overlay_ramopt tb_h4_skin tb_h4_overlay tb_controls6 tb_matrix5_ramopt tb_h5_ui tb_i2c6 tb_health6 tb_frame_path tb_menu_cdc6 tb_camera_rgb_fifo tb_capture_exit_regression tb_capturefix_controls tb_capturefix_chain tb_capturefix_abort tb_capturefix_faults tb_capturefix_pip tb_capturefix_ui_select tb_vision8_gesture tb_capturefix_rawphase tb_review_controls tb_review_hdmi_text tb_review_done_cdc tb_review_top tb_capturefix_cancel_boundary tb_capturefix_binding tb_capturefix_720p_pressure tb_capturefix_full_load tb_review_video_defaults tb_inline_video_dynamic tb_fourkey_font tb_capturefix_menu tb_inline_cpu8 tb_inline_epd_cpu'''.split())
COVERAGE={
 'rtl/vision8_frames.v':['tb_review_hdmi_text','tb_review_done_cdc','tb_capturefix_chain','tb_capturefix_cancel_boundary','tb_capturefix_faults','tb_review_top'],
 'example_top.v':['tb_review_top'],
 'Ti60_Demo.pt.sdc':['Efinity PNR and byte-prefix check (not RTL simulation)'],
 'rtl/vision8_controls.v':['tb_review_controls','tb_capturefix_controls'],
 'rtl/vision8_ddr.v':['tb_capturefix_abort','tb_capturefix_chain','tb_capturefix_720p_pressure','tb_capturefix_full_load','tb_review_top'],
 'rtl/vision8_base_axi.v':['tb_capturefix_faults','tb_capturefix_full_load','tb_review_top'],
 'rtl/menu8_renderer.v':['tb_capturefix_menu','tb_capturefix_ui_select','tb_inline_cpu8'],
 'src/parallel/vision8_modes.vh':['tb_review_controls','tb_capturefix_menu','tb_review_top'],
 'generated_fonts':['tb_fourkey_font','tb_capturefix_menu','tb_inline_cpu8','tb_inline_epd_cpu'],
 'Canny LOW/HIGH frame atomicity':['tb_inline_video_dynamic','tb_review_controls','tb_capturefix_binding','tb_review_top']}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def path(s):
 p=Path(s);return p if p.is_absolute() else P/p
def sdc_prefix(original,current):
 assert current.startswith(original),'Existing SDC byte prefix changed'
 suffix=current[len(original):]
 assert suffix.count(b'set_false_path')==2 and b'key_mode_n' in suffix and b'key_freeze_n' in suffix
 assert b'\r' not in current,'CRLF regression Ti60_Demo.pt.sdc'
def verify(evidence):
 spec=read(evidence);seen={};details=[];batches=[]
 assert isinstance(spec['runs'],list) and spec['runs'],'Explicit runs required'
 for selection in spec['runs']:
  assert isinstance(selection,dict) and selection.get('benches'),'Name every selected bench explicitly'
  rp=path(selection['path']);r=read(rp)
  selected=set(selection['benches']);assert len(selected)==len(selection['benches'])
  # A batch compiles several independent roots. Only the elaborated root's
  # testbench is an input to that simulation. All production/configuration,
  # reference-module and runner hashes remain mandatory. Other bench fixtures
  # may be corrected/rerun independently, without invalidating unrelated RTL.
  assert r['status'] in ('PASS','FAIL','ERROR'),f'Batch not terminal: {rp}'
  if r['status']=='ERROR':assert r.get('error')=='Source drift during run','Unknown batch error'
  for f,h in r['inputs'].items():
   fp=path(f)
   if fp.parent==P/'sim' and fp.suffix=='.sv' and fp.stem not in selected:continue
   assert fp.is_file() and sha(fp)==h,'Changed selected test input: '+f
  entries=[t for t in r['results'] if t['bench'] in selected];assert {t['bench'] for t in entries}==selected,'Selected bench absent'
  batches.append(dict(report=selection['path'],raw_batch_status=r['status'],raw_batch_error=r.get('error'),selected_benches=sorted(selected),excluded_roots=[dict(bench=t['bench'],status=t['status']) for t in r['results'] if t['bench'] not in selected]))
  for t in entries:
   assert t['status']=='PASS','Test not PASS '+t['bench'];assert t['bench'] not in seen,'Duplicate selected bench '+t['bench']
   log=path(t['log']);assert sha(log)==t['sha256'],'Changed log '+str(log)
   text=log.read_text(encoding='utf-8',errors='replace')
   assert 'PASS:' in text and '$finish called' in text and not re.search(r'Fatal:|FATAL|ERROR:|Error:',text),'Incomplete/error log '+str(log)
   markers=[s for s in text.splitlines() if 'PASS:' in s];assert markers==t['markers'],'Markers drift'
   metrics=[]
   for s in markers:
    metrics.append({'text':s,'numeric_fields':re.findall(r'\b(?:[A-Za-z_]+\s*=\s*)?\d+(?:\.\d+)?\b',s)})
   seen[t['bench']]=dict(result=str(rp.relative_to(P)),log=t['log'],sha256=t['sha256'],observed_metrics=metrics)
 assert REQUIRED.issubset(seen),'Missing required benches: '+','.join(sorted(REQUIRED-set(seen)))
 assert len(seen)==len(REQUIRED),'Unexpected bench selection; review scope explicitly'
 # Original untouched proof uses its independent pre-copy manifest, not a label.
 prot=read(P/'reports/capture_fix/protection.json');original=Path(prot['source']);old={x['path']:x['sha256'] for x in prot['files']}
 actual={f.relative_to(original).as_posix() for f in original.rglob('*') if f.is_file()}
 assert actual==set(old),'Original file set changed'
 for rel,h in old.items():assert sha(original/rel)==h,'Original changed '+rel
 backup=read(P/'reports/capture_review/backup.json');before={x['path']:x['sha256'] for x in backup['files']}
 # Current-vs-before-audit production scope: only the three reviewed files.
 review_changes=[];all_changes=[];protected=[]
 for f in build.production_files(P):
  rel=f.relative_to(P).as_posix();h=sha(f)
  if before.get(rel)!=h:
   assert rel in {'example_top.v','rtl/vision8_frames.v','Ti60_Demo.pt.sdc'},'Unexpected audit production change '+rel
   review_changes.append(dict(path=rel,before_sha256=before.get(rel),after_sha256=h,tests=COVERAGE[rel]))
  if old.get(rel)!=h:
   assert rel in OLD or (len(f.relative_to(P).parts)==1 and 'font' in f.name and f.suffix=='.hex'),'Unexpected original production change '+rel
   all_changes.append(dict(path=rel,before_sha256=old.get(rel),after_sha256=h))
  else:protected.append(dict(path=rel,sha256=h))
 # IP configuration/blueprint JSON is not elaborated HDL, but it is protected
 # project state too. Compare the full IP/vendor/image file sets, rather than
 # merely asserting that the compiled HDL was unchanged.
 supplemental=[]
 for root in ('ip','vendor','image'):
  expected={rel:h for rel,h in before.items() if rel.startswith(root+'/')}
  actual={f.relative_to(P).as_posix() for f in (P/root).rglob('*') if f.is_file()}
  assert actual==set(expected),'Protected directory file set changed: '+root
  for rel,h in expected.items():
   assert sha(P/rel)==h,'Protected settings/dependency changed: '+rel
   supplemental.append(dict(path=rel,sha256=h))
 # Exact bytes, including LF. Existing constraints cannot be silently normalized.
 old_sdc=(original/'Ti60_Demo.pt.sdc').read_bytes();new_sdc=(P/'Ti60_Demo.pt.sdc').read_bytes()
 sdc_prefix(old_sdc,new_sdc)
 for f in ('example_top.v','rtl/vision8_frames.v','Ti60_Demo.pt.sdc'):assert b'\r' not in (P/f).read_bytes(),'CRLF regression '+f
 # Header is actually referenced by two consuming modules, not three.
 header_users=[f.relative_to(P).as_posix() for root in ('rtl','src') for f in (P/root).rglob('*.v') if '"vision8_modes.vh"' in f.read_text(encoding='utf-8',errors='replace')]
 assert set(header_users)=={'rtl/menu8_renderer.v','rtl/vision8_controls.v'}
 bpath=path(spec['build']);s=read(bpath);assert s['status']=='PASS';assert build.inputs(P)==s['production_inputs'],'Build production drift'
 for group in ('outputs','evidence'):
  for rel,h in s[group].items():assert sha(P/rel)==h,'Build artifact drift '+rel
 assert {'outflow/Ti60_Demo.bit','outflow/Ti60_Demo.hex','outflow/Ti60_Demo.route.rpt','outflow/Ti60_Demo.timing.rpt'}.issubset(s['outputs']),'Build output manifest incomplete'
 eroot=P/'reports/capture_review/build'
 assert read(eroot/'build_verified.json')==s['build'],'Selected build metrics differ from verified build record'
 raw=(eroot/'efinity_build.log').read_bytes();text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
 for stage in ('map','interface','pnr','pgm'):assert re.search(r'^\s*'+stage+r'\s*:\s*PASS',text,re.M),'Build stage not PASS: '+stage
 b=s['build'];assert b['resources']['XLRs']['used']<=60000 and b['resources']['Memory Blocks']['used']<=230
 assert b['min_setup_slack_ns']>=0 and b['min_hold_slack_ns']>=0
 route=(P/'outflow/Ti60_Demo.route.rpt').read_text(errors='replace')
 for name,values in b['resources'].items():
  m=re.search(re.escape(name)+r':\s*(\d+)\s*/\s*(\d+)',route);assert m,'Resource missing from route report '+name
  assert tuple(map(int,m.groups()))==(values['used'],values['available']),'Resource metric mismatch '+name
 timing=(P/'outflow/Ti60_Demo.timing.rpt').read_text(errors='replace')
 for start,end,key in [('Setup (Max) Clock Relationship','Hold (Min) Clock Relationship','min_setup_slack_ns'),('Hold (Min) Clock Relationship','NOTE:','min_hold_slack_ns')]:
  block=timing.split(start,1)[1].split(end,1)[0];slacks=[float(x) for x in re.findall(r'\s(-?\d+\.\d+)\s+\([^)]+\)\s*$',block,re.M)]
  assert slacks and min(slacks)==b[key],'Timing metric mismatch '+key
 assert b['bit_sha256']==sha(P/'outflow/Ti60_Demo.bit') and b['hex_sha256']==sha(P/'outflow/Ti60_Demo.hex'),'Bitstream metric mismatch'
 return dict(status='PASS',verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),project=str(P),selected_evidence=str(evidence),selected_evidence_sha256=sha(evidence),tests=seen,test_count=len(seen),batch_selection=batches,build=b,review_production_changes=review_changes,all_production_changes=all_changes,protected_files_compared=protected,protected_dependencies_and_settings=supplemental,original_files_hashed=len(old),header_consumers=header_users,coverage_map=COVERAGE,excluded_historical_groups=['tb_vision8_controls/tb_inline_controls: replaced by capturefix and review six-key controls','tb_vision8_frames: replaced by real chain, PiP and error/cancel tests','tb_vision6: replaced by actual 4Key seven-scene default equality'],physical_board_test='NOT_RUN',jtag_flash='NOT_PERFORMED',limitations=['Physical DDR/MIPI/PLL electrical behavior not modeled','Real top smoke reduced to 128x96; physical boundary models explicitly identified','Four-algorithm capture chain 128x96, full720p DDR pressure RAW only','Full-load test preloads memory and forces valid directory; separate empty-to-four-save test retained','CPU8 pixel checking validates LVDS packing, not an independent image golden','DDR watchdog tests shorten SNAP_TIMEOUT; full production timeout elapsed duration not simulated','Permanent AXI nonresponse cannot be safely force-completed'])
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--evidence',type=Path,required=True);ap.add_argument('--publish',action='store_true');ap.add_argument('--output',type=Path);args=ap.parse_args()
 assert args.publish==bool(args.output),'--output requires explicit --publish'
 result=verify(args.evidence.resolve())
 if args.publish:
  assert not args.output.exists(),'Refusing to overwrite delivery evidence'
  with args.output.open('x',encoding='utf-8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
 print(json.dumps(dict(status=result['status'],tests=result['test_count'],protected_files=len(result['protected_files_compared']),published=str(args.output) if args.publish else False),ensure_ascii=False))
if __name__=='__main__':
 try:main()
 except Exception as e:print('FAIL:',str(e),file=sys.stderr);raise SystemExit(1)
