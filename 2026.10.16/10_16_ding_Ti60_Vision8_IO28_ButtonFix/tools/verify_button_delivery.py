"""Verify fresh IO28 tests, implementation, input pinout and original preservation.

This tool never programs hardware. The old-core counterexample is deliberately
failing and is recorded separately from all required passing testbenches.
"""
from pathlib import Path
from datetime import datetime, timezone
import csv, hashlib, json, re, shutil, sys, xml.etree.ElementTree as ET

P=Path(__file__).resolve().parents[1]
R=P/'reports/button_fix'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def inp(p):
    if p.name!='Ti60_Demo.xml': return sha(p)
    root=ET.fromstring(p.read_bytes())
    for k in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):
        root.attrib.pop(k,None)
    return hashlib.sha256(ET.tostring(root,encoding='utf-8')).hexdigest()

run=read(R/'run_started.json'); source=Path(run['source'])
started=datetime.fromisoformat(run['started_utc']).timestamp()
original=read(R/'original_files_sha256.json')
current={f.relative_to(source).as_posix():sha(f) for f in source.rglob('*') if f.is_file()}
assert current==original,'Original file set or contents changed'
copied=read(R/'copied_files_sha256.json')
baseline=read(R/'baseline_build_input_sha256.json')
# Efinity may update Dashboard bookkeeping even when it preserves every input.
changed=[rel for rel,digest in copied.items() if
         (inp(P/rel)!=baseline[rel] if rel=='Ti60_Demo.xml' else sha(P/rel)!=digest)]
allowed={'rtl/vision8_controls.v','sim/tb_vision8_controls.sv','sim/tb_vision8_ddr.sv',
         'sim/tb_vision8_frames.sv','README.md'}
assert set(changed)==allowed,changed

active_changes=[rel for rel,digest in baseline.items() if inp(P/rel)!=digest]
assert active_changes==['rtl/vision8_controls.v'],active_changes
for rel in ('src/cmos_i2c/I2C_OV5640_1280720_Config.v','src/parallel/rgb_balance_config.vh',
            'rtl/camera_rgb_balance.v','example_top.v','Ti60_Demo.peri.xml'):
    assert inp(P/rel)==baseline[rel],rel
control=(P/'rtl/vision8_controls.v').read_text()
assert 'a(clk,rst_n,io28,key_context,s[0],l[0])' in control
assert 'threshold_key(clk,rst_n,~io35,key_context,threshold_short,threshold_long)' in control

video='tb_h5_palm tb_h5_wave tb_h5_raster tb_h4_controls tb_h4_skin tb_h4_templates tb_h4_overlay tb_controls6 tb_matrix8 tb_vision6 tb_h5_ui tb_i2c6 tb_health6 tb_frame_path tb_menu_cdc6'.split()
vision='tb_vision8_controls tb_vision8_fifo tb_vision8_ddr tb_vision8_frames tb_vision8_faces tb_vision8_gesture tb_io29_freeze_ddr'.split()
logs=[(name,'reports/'+name+'.log') for name in video]
logs += [(name,'reports/vision8/'+name+'.log') for name in vision]
logs += [('tb_menu8_pixels','reports/vision8/tb_menu8_pixels.log'),
         ('tb_menu_cpu8','reports/tb_menu_cpu8.log'),('tb_epd_cpu','reports/tb_epd_cpu.log'),
         ('tb_ui_fonts','reports/ui_refresh/tb_ui_fonts.log'),
         ('tb_cache_stress','reports/cpu_font_ram/tb_cache_stress.log'),
         ('tb_gesture_roi_rgb','reports/roi_integration/tb_gesture_roi_rgb.log'),
         ('tb_roi_shared_overlay','reports/roi_integration/tb_roi_shared_overlay.log'),
         ('tb_vision8_key_boundary','reports/button_fix/tb_vision8_key_boundary.log'),
         ('tb_vision8_controls','reports/button_fix/tb_vision8_controls.log'),
         ('tb_vision8_frames','reports/button_fix/pip_pixels/tb_vision8_frames.log')]
tests=[]
for bench,rel in logs:
    f=P/rel;text=f.read_text(encoding='utf-8-sig',errors='replace')
    assert f.stat().st_mtime>=started,'Stale test: '+rel
    assert 'PASS:' in text and not re.search(r'Fatal:|Error:|^ERROR:',text,re.M),rel
    tests.append(dict(bench=bench,log=rel,status='PASS',sha256=sha(f)))
assert len({x['bench'] for x in tests})==30
boundary=(R/'tb_vision8_key_boundary.log').read_text(errors='replace')
assert 'exact release-long collision' in boundary and '500/1999/2000/5000ms' in boundary
controls=(R/'tb_vision8_controls.log').read_text(errors='replace')
assert 'IO28 active-low' in controls and '5s holds toggle once' in controls
context_check='IO35 settings close coincident with IO28 long generation masks pending PiP event'
assert context_check in controls and context_check in (P/'reports/vision8/tb_vision8_controls.log').read_text(errors='replace')
pixels=(P/'reports/vision8/tb_vision8_frames.log').read_text(errors='replace')
pixel_frames=re.findall(r'CHECK: PiP case=\d+ mode=\d+ enabled=[01] full raster pixels=(\d+) AUX words=(\d+)',pixels)
assert len(pixel_frames)==11 and sum(int(x[0]) for x in pixel_frames)==33792,'Missing full-regression PiP pixel scoreboard'

counterexamples=[]
for case in ('negative_original_core','negative_pending_context_core','negative_pending_context_controls'):
    negative=read(R/(case+'.json'))
    assert negative['result']=='EXPECTED_FAILURE_OBSERVED'
    ref='original_vision8_controls.v' if case=='negative_original_core' else 'first_fix_vision8_controls.v'
    assert sha(P/'reference/button_fix_counterexamples'/ref)==negative['original_source_sha256'].lower()
    assert sha(Path(negative['saved_source']))==negative['saved_source_sha256'].lower()==negative['original_source_sha256'].lower()
    bench=negative['testbench']
    assert sha(P/('sim/'+bench+'.sv'))==negative['testbench_sha256'].lower()
    assert negative['expected_failure'] in (R/(case+'.log')).read_text(errors='replace')
    counterexamples.append(negative)
assert sha(source/'rtl/vision8_controls.v')==counterexamples[0]['original_source_sha256'].lower()

source_only='--source-only' in sys.argv
if not source_only:
    info=read(P/'reports/build_verified.json')
    manifest=P/'reports/vision8/build_input_sha256.json';inputs=read(manifest)
    assert sha(manifest)==info['build_input_manifest_sha256']
    assert set(inputs)==set(baseline),'Unexpected active build input added or removed'
    for rel,digest in inputs.items(): assert inp(P/rel)==digest,'Build input changed: '+rel
    for ext in ('bit','hex'):
        f=P/('outflow/Ti60_Demo.'+ext)
        assert f.stat().st_mtime>=started and sha(f)==info[ext+'_sha256']
    assert info['min_setup_slack_ns']>=0 and info['min_hold_slack_ns']>=0
    assert info['resources']['XLRs']['used']<=60000 and info['resources']['Memory Blocks']['used']<=230
    assert all(v['used']<=v['available'] for v in info['resources'].values())
    rows=list(csv.reader((P/'outflow/Ti60_Demo.pinout.csv').read_text(encoding='utf-8-sig').splitlines()))
    pins={}
    for port,ball,gpio in [('io28_button_i','C1','GPIOL_N_16'),('io29_button_i','D1','GPIOL_P_16'),
                           ('io35_button_i','B9','GPIOT_P_11'),('key_mode_n','N2','GPIOL_P_02_CSI'),
                           ('key_freeze_n','M2','GPIOL_N_02_CSO')]:
        matches=[row for row in rows if len(row)>=7 and row[2].split('.')[0]==port]
        assert len(matches)==1,port
        row=matches[0]
        assert (row[0],row[1],row[3],row[6])==(ball,gpio,'Input','1.8 V LVCMOS'),row
        pins[port]=dict(ball=ball,gpio=gpio,direction=row[3],standard=row[6])
else:
    info=dict(status='not_completed_user_requested_stop',final_timing_verified=False,new_bit_or_hex_delivered=False)
    pins={}
peri=ET.fromstring((P/'Ti60_Demo.peri.xml').read_bytes())
gpio28=next(x for x in peri.iter() if x.attrib.get('name')=='io28_button_i' and x.tag.endswith('comp_gpio'))
assert gpio28.attrib['mode']=='input' and gpio28.attrib['io_standard']=='1.8 V LVCMOS'
assert next(iter(gpio28)).attrib['pull_option']=='none'
if source_only:
    assert gpio28.attrib['gpio_def']=='GPIOL_N_16'
    pins['io28_button_i']=dict(gpio=gpio28.attrib['gpio_def'],direction='Input',standard='1.8 V LVCMOS',
        pull_option='none',validation='source configuration; final PNR was cancelled by user')

downloads={}
if not source_only:
    downloads={};sum_lines=[]
    for ext in ('bit','hex'):
        target=P/('outflow/Ti60_Demo_IO28_ButtonFix.'+ext)
        shutil.copy2(P/('outflow/Ti60_Demo.'+ext),target)
        assert sha(target)==info[ext+'_sha256']
        downloads[ext]=target.relative_to(P).as_posix()
        sum_lines.append(sha(target)+'  '+target.name)
    (R/'SHA256SUMS.txt').write_text('\n'.join(sum_lines)+'\n',encoding='ascii')
result=dict(revision='io28_active_low_button_fix',date='2026-10-16',author='ding',
    completed_utc=datetime.now(timezone.utc).isoformat(),project=str(P),source=str(source),
    original_file_count=len(original),original_file_set_and_sha256='unchanged',
    copied_files=len(copied),changed_copied_files=changed,changed_build_inputs=active_changes,
    unchanged_build_inputs=len(baseline)-len(active_changes),
    unique_testbench_count=len({x['bench'] for x in tests}),passing_test_run_count=len(tests),tests=tests,
    expected_failure_counterexamples=counterexamples,build=info,pins=pins,download_files=downloads,
    source_camera_configuration='unchanged V3 B: LENC off, FPGA spatial RGB gains bypassed',
    button_configuration='IO28 active-low; IO35 active-high; IO29/K1/K2 active-low; 20ms debounce, 2s long',
    wiring='NO contact: P4.33 IO28 to P4.30 GND; remove and insulate third 3.3V lead',
    hardware_programming='not performed',physical_board_test='not performed; user compilation/SRAM/button acceptance pending',
    delivery_mode='source_and_simulation_only' if source_only else 'verified_bitstream',
    bitstream_compilation='stopped at user request' if source_only else 'PASS')
(R/'final_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in ('unique_testbench_count','passing_test_run_count','original_file_count',
    'changed_build_inputs','unchanged_build_inputs','build','download_files','physical_board_test')},ensure_ascii=False,indent=2))
