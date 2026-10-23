"""Archive final 25+UI regressions, retain the already-completed unchanged CPU/EPD v1 chain."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import ast,hashlib,json,os,re,shutil,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1];R=P/'reports/ramopt_regression';A=R/'final_evidence';A.mkdir(exist_ok=True)
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def stamp(txt,pattern):
 m=re.search(pattern,txt)
 if not m:return None
 try:return datetime.strptime(m[1].strip(),'%a %b %d %H:%M:%S %Y').replace(tzinfo=timezone(timedelta(hours=8))).isoformat()
 except ValueError:return m[1].strip()
old=json.loads((R/'v1_tests.json').read_text())
v1=json.loads((R/'v1_production_sha256.json').read_text())
final=json.loads((R/'final_production_sha256.json').read_text())
assert final==json.loads((P/'reports/vision8/build_input_sha256.json').read_text()),'Final manifest differs from collected FPGA build'
for rel,expected in final.items():
 f=P/rel
 if f.name=='Ti60_Demo.xml':
  tree=ET.fromstring(f.read_bytes())
  for key in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):tree.attrib.pop(key,None)
  actual=hashlib.sha256(ET.tostring(tree,encoding='utf-8')).hexdigest()
 else:actual=sha(f)
 assert actual==expected,'Final production input changed: '+rel
critical=[k for k in v1 if k.startswith('vendor/') or k.startswith('EfxSapphireSoc') and k.endswith('.bin') or k in ['rtl/riscv_menu_top.v','rtl/menu_lcd_apb.v','rtl/epd_apb.v','rtl/spi_write_byte.v','rtl/menu_status_cdc.v','rtl/menu8_renderer.v','rtl/menu_renderer.v','rtl/menu_glyph_rom.v']]
font_inputs=['rtl/shared_glyph_rom.v']+[f'shared_font_index_bank{i}.hex' for i in range(5)]
critical+=font_inputs
for rel in critical:assert v1[rel]==final[rel],'CPU/firmware/service input changed: '+rel
cpu=[t for t in old['tests'] if t['name'] in ('tb_cache_stress','tb_menu_cpu8','tb_epd_cpu')]
assert len(cpu)==3
for t in cpu:assert sha(P/t['log'])==t['sha256']
root=ast.parse((P/'tools/test_ramopt_regression.py').read_text())
benches=next(ast.literal_eval(n.value) for n in root.body if isinstance(n,ast.Assign) and any(isinstance(v,ast.Name) and v.id=='BENCHES' for v in n.targets))
group=R/os.environ.get('RAMOPT_FINAL_GROUP','frequency_suite')
logs={b:(group/(b+'.log') if (group/(b+'.log')).exists() else group/('video' if b=='tb_vision6' else 'main')/(b+'.log')) for b in benches};logs['tb_menu8_pixels']=P/'reports/vision8/tb_menu8_pixels.log'
items=[]
for name,log in logs.items():
 text=log.read_text(encoding='utf-8-sig',errors='replace')
 assert 'PASS:' in text and not re.search(r'Fatal:|Error:|FATAL|ERROR:',text),name
 assert 'Exiting xsim' in text,name
 markers={'tb_vision6':'PASS: six modes','tb_menu8_pixels':'PASS: all eight UI','tb_gesture5_rgb_ramopt':'PASS: five-class RGB-to-template'}
 if name in markers:assert markers[name] in text,name
 dest=A/(name+'.log');shutil.copy2(log,dest);bench=P/'sim'/(name+'.sv')
 elapsed=re.findall(r'run: Time .*?elapsed = ([0-9:]+)',text)
 items.append(dict(name=name,log=dest.relative_to(P).as_posix(),status='PASS',sha256=sha(dest),source_phase='final',started_at=stamp(text,r'# Start of session at: (.+)'),ended_at=stamp(text,r'Exiting xsim at (.+?)\.\.\.'),xsim_elapsed=elapsed[-1] if elapsed else None,bench=bench.relative_to(P).as_posix(),bench_sha256=sha(bench)))
for item in items+cpu:
 manifest=R/(item['source_phase']+'_production_sha256.json')
 item['source_manifest']=manifest.relative_to(P).as_posix();item['source_manifest_sha256']=sha(manifest)
summary=dict(tests=items+cpu,test_count=len(items)+len(cpu),tool=old['tool'],source_manifest='reports/ramopt_regression/final_production_sha256.json',source_manifest_sha256=sha(R/'final_production_sha256.json'),source_manifests={phase:dict(path='reports/ramopt_regression/'+phase+'_production_sha256.json',sha256=sha(R/(phase+'_production_sha256.json'))) for phase in ('v1','final')},unchanged_cpu_epd_inputs=critical,composition_evidence='CPU core, production firmware images, menu/EPD interfaces, font RTL and all five font-index assets are byte-identical between v1 and final. The completed v1 real-CPU/cache/EPD regressions are retained explicitly; final font all-address/dual-clock equivalence and final 17-scene pixel/retained-function regressions validate the storage-only substitution. RAM/font/coordinate unit evidence is appended separately.',physical_board_test='not performed',provenance='reports/ramopt_regression/bench_provenance.json')
(R/'final_tests.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('Final current-function suite verified:',len(items),'final-phase +',len(cpu),'unchanged CPU/EPD v1')
