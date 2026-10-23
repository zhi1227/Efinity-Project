"""Audit the four-key delivery. Never runs programming or alters old verifiers.

--source-only records source protection while final simulations/builds are
pending. Full mode requires current-source tests and a fresh selected build.
Only the selected audit JSON is written by this program.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, sys
import xml.etree.ElementTree as ET
from inline_threshold_build import inputs, input_sha, production_files, sha

P = Path(__file__).resolve().parents[1]
R = P/'reports/inline_threshold'
ALLOWED_RTL = {
    'example_top.v', 'rtl/vision8_controls.v', 'rtl/vision8_frames.v',
    'rtl/menu8_renderer.v', 'rtl/vision6_overlay.v',
    'rtl/menu_glyph_rom.v', 'rtl/vision6_glyph_rom.v', 'rtl/shared_glyph_rom.v',
    'src/parallel/parallel_video.v', 'src/parallel/parallel_overlay.v',
}
ALLOWED_CONFIG = {'Ti60_Demo.xml','Ti60_Demo.peri.xml','Ti60_Demo.pt.sdc'}
FONT_NAME = re.compile(r'^(?:(?:shared|menu|vision6)_font(?:_bank\d+)?|shared_font_index_bank\d+)\.hex$')
PROTECTED_RAM = {
    'rtl/gesture_branch.v',
    'src/gesture/ep1_components.v', 'src/gesture/ep1_skin.v',
    'src/parallel/face_grid_regions.v', 'src/parallel/video_delay.v',
    'src/vision/line_buffer_3x3.v',
}
REQUIRED_CHECKS = {
    'controls_95','io28_boundaries','video_dynamic','video_defaults','ui_pixels',
    'font_dualclock','capture_binding','cpu8_real','epaper_real',
} | {'retained_'+name for name in (
    'tb_vision8_key_boundary','tb_vision8_fifo','tb_vision8_ddr','tb_vision8_frames',
    'tb_vision8_faces','tb_io29_freeze_ddr','tb_vision8_gesture','tb_h5_palm',
    'tb_h5_wave','tb_gesture5_controls_new','tb_gesture5_templates_ramopt',
    'tb_gesture5_rgb_ramopt','tb_gesture5_shared_overlay_ramopt','tb_h4_skin',
    'tb_h4_overlay','tb_controls6','tb_matrix5_ramopt','tb_h5_ui','tb_i2c6',
    'tb_health6','tb_frame_path','tb_menu_cdc6','tb_camera_rgb_fifo')}
def require(ok,message):
    if not ok: raise AssertionError(message)
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def inside(path):
    result=(P/path).resolve()
    require(result.is_relative_to(P), 'Audit path escapes project: '+str(path))
    return result
def text(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
def signature(root):
    return (root.tag,tuple(sorted(root.attrib.items())),(root.text or '').strip(),tuple(signature(c) for c in root))

def check_original(protection):
    original=Path(protection['source']).resolve()
    expected={entry['path']:entry['sha256'] for entry in protection['files']}
    actual={p.relative_to(original).as_posix():sha(p) for p in original.rglob('*') if p.is_file()}
    require(actual==expected,'Original project files or bytes changed since independent copy')
    return original, expected

def check_sources(original, before):
    historical_roots=('reports/ram_optimization_20261020/','reports/ramopt_regression/',
                      'reports/ramopt_buffers/','reports/ramopt_coordinates/','reports/ramopt_wide_lines/')
    historical={n:h for n,h in before.items() if n.startswith(historical_roots)}
    actual_historical={p.relative_to(P).as_posix():sha(p) for root in historical_roots
                       for p in (P/root).rglob('*') if p.is_file()}
    require(historical==actual_historical,'Inherited historical RAM optimization evidence was changed or mixed with new results')
    # Protect all IP collateral and CPU firmware, including simulation models
    # and JSON/scripts that are not consumed by the selected synthesis source
    # list. The compile-input manifest deliberately has a narrower HDL scope.
    protected_collateral={n:h for n,h in before.items() if n.split('/')[0] in {'ip','vendor','firmware','image'}}
    actual_collateral={p.relative_to(P).as_posix():sha(p) for root in ('ip','vendor','firmware','image')
                       for p in (P/root).rglob('*') if p.is_file()}
    require(actual_collateral==protected_collateral,'An IP/vendor/firmware/image collateral file was changed, added or removed')
    current={p.relative_to(P).as_posix():sha(p) for p in production_files(P)}
    originals={p.relative_to(original).as_posix():before[p.relative_to(original).as_posix()]
               for p in production_files(original)}
    require(not set(originals)-set(current),'An original production input was removed')
    added=sorted(set(current)-set(originals))
    require(not added, 'Unapproved new production inputs: '+repr(added))
    changed=sorted(n for n,h in current.items() if originals.get(n)!=h)
    allowed=ALLOWED_RTL|ALLOWED_CONFIG
    require(all(n in allowed or FONT_NAME.fullmatch(n) for n in changed),
            'Unexpected production edits: '+repr([n for n in changed if n not in allowed and not FONT_NAME.fullmatch(n)]))
    require(all(current[n]==originals[n] for n in PROTECTED_RAM),'Protected RAM layout RTL changed')
    # Updated text legitimately changes the row dictionary and sparse high
    # decode. Strip only those combinational function bodies; the physical
    # banks, widths, clocks, read addresses, mux and latency must stay identical.
    def font_layout(base):
        value=(base/'rtl/shared_glyph_rom.v').read_text(encoding='utf-8-sig')
        value=re.sub(r'function\b.*?endfunction','FUNCTION_DATA',value,flags=re.S)
        value=re.sub(r'//[^\n]*','',value)
        return re.sub(r'\s+','',value)
    require(font_layout(P)==font_layout(original),'Shared font RAM banks/read timing layout changed')
    # Keep IO28's synchronized debounce/long/short core verbatim.
    def key_module(base):
        value=(base/'rtl/vision8_controls.v').read_text(encoding='utf-8-sig')
        return re.search(r'\bmodule\s+vision8_key\b.*?\bendmodule\b',value,re.S).group()
    require(key_module(P)==key_module(original),'Original vision8_key module changed')
    old_top=(original/'example_top.v').read_text(encoding='utf-8-sig')
    new_top=(P/'example_top.v').read_text(encoding='utf-8-sig')
    def protected_prefix(value):
        value=value.split(' wire settings_open;',1)[0]
        return re.sub(r'^\s*input io34_button_i,[^\n]*\n','',value,flags=re.M)
    require(protected_prefix(old_top)==protected_prefix(new_top),
            'Top-level camera/DDR/reset/clock prefix changed beyond the new IO34 port')
    protected_instances={}
    for module in ('camera_rgb_balance','vision8_ddr','rgb2dvi'):
        def instance(value):
            matches=re.findall(r'^\s*'+module+r'\b.*?\);',value,re.M|re.S)
            require(len(matches)==1,'Expected one protected top instance: '+module)
            return re.sub(r'\s+','',matches[0])
        require(instance(old_top)==instance(new_top),'Protected top instance changed: '+module)
        protected_instances[module]='identical ports and parameters'
    # Existing project settings and source list remain byte-independent equal.
    require(input_sha(P/'Ti60_Demo.xml')==input_sha(original/'Ti60_Demo.xml'),
            'Project settings/source list changed beyond volatile flow metadata')
    old=ET.parse(original/'Ti60_Demo.peri.xml').getroot()
    new=ET.parse(P/'Ti60_Demo.peri.xml').getroot()
    matches=[(parent,node) for parent in new.iter() for node in parent
             if node.attrib.get('name')=='io34_button_i' and node.tag.endswith('comp_gpio')]
    require(len(matches)==1,'Expected exactly one new IO34 GPIO')
    parent,node=matches[0]
    require(node.attrib.get('gpio_def')=='GPIOT_N_11' and node.attrib.get('mode')=='input'
            and node.attrib.get('io_standard')=='1.8 V LVCMOS','IO34 mapping/standard changed')
    configs=[c for c in node if c.tag.endswith('input_config')]
    require(len(configs)==1 and configs[0].attrib.get('pull_option')=='none','IO34 input configuration changed')
    parent.remove(node)
    require(signature(old)==signature(new),'An existing pin, PLL, LVDS or interface configuration changed')
    def constraints(base):
        return [line.strip() for line in (base/'Ti60_Demo.pt.sdc').read_text(encoding='utf-8-sig').splitlines()
                if line.strip() and not line.lstrip().startswith('#')]
    old_sdc,new_sdc=constraints(original),constraints(P)
    require(new_sdc[:len(old_sdc)]==old_sdc,'Original timing constraints were removed or changed')
    extra=new_sdc[len(old_sdc):]
    require(extra==['set_false_path -from [get_ports {io34_button_i}] -to [get_pins {controls/c/meta~FF|D}]'],
            'Only IO34 asynchronous input to its first post-map meta~FF|D synchronizer may be exempted: '+repr(extra))
    return {'status':'PASS','modified_production_inputs':changed,'new_production_inputs':added,
            'protected_ip_cpu_runtime_collateral_files':len(protected_collateral),
            'preserved_historical_ram_evidence_files':len(historical),
            'protected_camera_ddr_clock_reset_prefix':'identical except IO34 port',
            'protected_top_instances':protected_instances,
            'protected_ram_modules':sorted(PROTECTED_RAM),'shared_font_ram_layout':'identical outside combinational dictionary functions','original_key_core':'identical',
            'pin_changes':'IO34 GPIOT_N_11 input, 1.8 V LVCMOS only','new_sdc':extra}

def check_tests(data, current, protection):
    require(data.get('production_inputs')==current,'Tests production manifest differs from current final build inputs')
    require(data.get('started_utc'),'Tests have no start time')
    start=datetime.fromisoformat(data['started_utc'].replace('Z','+00:00'))
    protected_time=datetime.fromisoformat(protection['created_utc'].replace('Z','+00:00'))
    require(start>=protected_time,'Tests began before the independent copy was verified')
    checks=data.get('checks',[]);require(bool(checks),'Test list is empty')
    names=[c['name'] for c in checks];require(len(set(names))==len(names),'Duplicate test names')
    require(REQUIRED_CHECKS<=set(names),'Missing mandatory checks: '+repr(sorted(REQUIRED_CHECKS-set(names))))
    summaries=[]
    for check in checks:
        name=check['name']; require(check.get('status')=='PASS','Test not PASS: '+name)
        logs=check.get('logs',[]);require(bool(logs) and len(set(logs))==len(logs),'Empty/duplicate test logs: '+name)
        hashes=check.get('expected_log_sha256',{});markers=check.get('completion_markers',{})
        require(set(logs)==set(hashes)==set(markers),'Log hash/marker key sets differ: '+name)
        for rel in logs:
            path=inside(rel);require(path.is_file(),'Missing log: '+rel)
            require(sha(path)==hashes[rel],'Test log changed: '+rel)
            require(datetime.fromtimestamp(path.stat().st_mtime,timezone.utc)>=start,'Stale test log: '+rel)
            value=text(path)
            require(not re.search(r'Fatal:|Error:|FATAL|ERROR:',value),'Failure in test log: '+rel)
            final=markers[rel]
            require(isinstance(final,list) and bool(final) and all(isinstance(m,str) and len(m.strip())>=8 for m in final),
                    'Missing explicit completion markers: '+rel)
            require(any('PASS' in m for m in final),'Completion marker lacks final PASS: '+rel)
            require(all(m in value for m in final),'Final test completion not reached: '+rel)
        sources=check.get('sources',[]);require(bool(sources),'Test lacks source/bench provenance: '+name)
        require(len({s['path'] for s in sources})==len(sources),'Duplicate test source paths: '+name)
        for source in sources:
            require(sha(inside(source['path']))==source['sha256'],'Test source changed: '+source['path'])
        summaries.append({'name':name,'status':'PASS','logs':logs,'sources':len(sources)})
    return {'status':'PASS','check_count':len(checks),'checks':summaries}

def check_build(current,protection):
    selected=read(R/'selected_build.json')
    require(selected.get('status')=='PASS' and selected.get('production_inputs')==current,
            'Selected build is not current-source PASS')
    require(selected.get('hardware_programming')=='not performed','Unexpected hardware-programming record')
    for group in ('outputs','evidence'):
        require(bool(selected.get(group)), 'Selected build has no '+group)
        for rel,expected in selected[group].items():
            require(sha(inside(rel))==expected,'Selected build artifact changed: '+rel)
    build=selected['build']
    require(read(R/'build/build_verified.json')==build,'Selected resource/timing results differ from the immutable completed build report')
    for extension in ('bit','hex'):
        require(sha(P/f'outflow/Ti60_Demo.{extension}')==build[extension+'_sha256'],'Stale '+extension)
    require(build['min_setup_slack_ns']>=0 and build['min_hold_slack_ns']>=0,'Timing failed')
    for resource,limit in [('XLRs',60000),('Memory Blocks',230)]:
        require(build['resources'][resource]['used']<=limit,'Resource budget exceeded: '+resource)
    stage=read(R/'build/inline_build_stage.json')
    require(datetime.fromisoformat(stage['build_started_utc'])>=datetime.fromisoformat(protection['created_utc']),
            'Build predates current independent copy')
    require(stage['production_inputs']==current and stage.get('build_exit_code')==0,'Build-stage inputs or exit status changed')
    existing=read(R/'build/build_input_sha256.json')
    require(all(current.get(n)==h for n,h in existing.items()),'Existing verify_build source snapshot differs')
    require(sha(R/'build/build_input_sha256.json')==build['build_input_manifest_sha256'],'Build manifest hash changed')
    log=text(R/'build/efinity_build.log')
    for name in ('map','interface','pnr','pgm'):
        require(re.search(r'^\s*'+name+r'\s*:\s*PASS',log,re.M),'Efinity stage not PASS: '+name)
    mapped=text(P/'outflow/Ti60_Demo.map.v')
    ff_parts=re.split(r'\bEFX_FF\s+\\',mapped)[1:]
    sink=[]
    for part in ff_parts:
        cell=part.split(None,1)[0]
        # Everything preceding this cell's closing attributes is its instance.
        body=part.split('defparam',1)[0]
        if re.search(r'\.D\(\s*io34_button_i\s*\)',body):
            sink.append(cell)
            require('.CLK(clk_pixel)' in body,'New asynchronous button is not synchronized in clk_pixel')
    require(sink==['controls/c/meta~FF'],'IO34 async input does not target its sole expected first synchronizer: '+repr(sink))
    references=[line.strip() for line in mapped.splitlines() if re.search(r'\bio34_button_i\b',line)]
    require(len(references)==3,'Unexpected IO34 port fanout/references: '+repr(references))
    pinout=text(P/'outflow/Ti60_Demo.pinout.csv')
    require('A9,GPIOT_N_11,io34_button_i.N,Input,2B,1.8 V,1.8 V LVCMOS' in pinout,'IO34 package pin is not A9/GPIOT_N_11/1.8V input')
    old_pinout=text(Path(protection['source'])/'outflow/Ti60_Demo.pinout.csv')
    preserved_buttons={}
    for signal in ('io28_button_i','io29_button_i','io35_button_i'):
        old_rows=[line for line in old_pinout.splitlines() if signal+'.' in line]
        new_rows=[line for line in pinout.splitlines() if signal+'.' in line]
        require(len(old_rows)==1 and old_rows==new_rows,'Original button pin row changed: '+signal)
        preserved_buttons[signal]=new_rows[0]
    warning=text(P/'outflow/Ti60_Demo.warn.log')
    new_constraint_failures=[line for line in warning.splitlines()
        if re.search(r'io34_button_i|controls/c/meta',line)
        and re.search(r'not found|does not exist|ignored|unsupported|invalid',line,re.I)]
    require(not new_constraint_failures,'IO34 exception target failed: '+repr(new_constraint_failures))
    cdc=text(P/'outflow/Ti60_Demo.cdc.rpt')
    require('No Synchronizer warnings to report.' in cdc,'New synchronizer warning requires review')
    return {'status':'PASS',**build,'selected_build_sha256':sha(R/'selected_build.json'),
            'io34_map_sink':sink[0],'io34_pin':'A9/GPIOT_N_11, input, 1.8 V LVCMOS',
            'original_button_pin_rows_unchanged':preserved_buttons,
            'io34_map_references':references,'synchronizer_report':'No Synchronizer warnings to report.',
            'cdc_scope':'Efinity synchronizer report only; not a formal CDC or MTBF certification'}

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source-only',action='store_true')
    args=ap.parse_args()
    report={'project':str(P),'started_utc':datetime.now(timezone.utc).isoformat(),
            'hardware_programming':'not performed','mode':'source-only' if args.source_only else 'full',
            'audit_tool_sha256':sha(Path(__file__))}
    try:
        protection=read(R/'protection.json')
        original,before=check_original(protection)
        report['original_protection']={'status':'PASS','files':len(before),'source':str(original),
                                       'manifest_sha256':sha(R/'protection.json')}
        report['sources']=check_sources(original,before)
        current=inputs(P)
        if args.source_only:
            report['status']='SOURCE_PASS';report['build']='not audited';report['tests']='not audited'
        else:
            report['build']=check_build(current,protection)
            report['tests']=check_tests(read(R/'tests.json'),current,protection)
            report['tests_manifest_sha256']=sha(R/'tests.json')
            report['status']='PASS'
        require({p.relative_to(original).as_posix():sha(p) for p in original.rglob('*') if p.is_file()}==before,
                'Original changed during audit')
        require(inputs(P)==current,'Current production sources changed during final audit')
    except Exception as error:
        report['status']='FAIL';report['error']=f'{type(error).__name__}: {error}'
    report['ended_utc']=datetime.now(timezone.utc).isoformat()
    output=R/('source_audit.json' if args.source_only else 'delivery_audit.json')
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'status':report['status'],'audit':str(output),'error':report.get('error')},ensure_ascii=True))
    return 0 if report['status'] in {'PASS','SOURCE_PASS'} else 1

if __name__=='__main__':sys.exit(main())
