"""Archive and verify the completed v1 functional regressions. Does not edit production."""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import ast,hashlib,json,re,shutil
P=Path(__file__).resolve().parents[1]
R=P/'reports/ramopt_regression';A=R/'v1_evidence';A.mkdir(exist_ok=True)
root=ast.parse((P/'tools/test_ramopt_regression.py').read_text())
benches=next(ast.literal_eval(n.value) for n in root.body if isinstance(n,ast.Assign) and any(isinstance(v,ast.Name) and v.id=='BENCHES' for v in n.targets))
logs={b:R/(b+'.log') for b in benches}
logs['tb_gesture5_rgb_ramopt']=R/'five_rgb/tb_gesture5_rgb_ramopt.log'
for b in ('tb_gesture5_shared_overlay_ramopt','tb_matrix5_ramopt'):logs[b]=R/'five_ui'/(b+'.log')
logs.update(tb_menu8_pixels=P/'reports/vision8/tb_menu8_pixels.log',tb_cache_stress=P/'reports/cpu_font_ram/tb_cache_stress.log',tb_menu_cpu8=P/'reports/tb_menu_cpu8.log',tb_epd_cpu=P/'reports/tb_epd_cpu.log')
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def stamp(txt,pattern):
 m=re.search(pattern,txt)
 if not m:return None
 try:return datetime.strptime(m[1].strip(),'%a %b %d %H:%M:%S %Y').replace(tzinfo=timezone(timedelta(hours=8))).isoformat()
 except ValueError:return m[1].strip()
sealed=json.loads((R/'v1_completed_log_sha256.json').read_text())
items=[]
for name,log in logs.items():
 if name in sealed:
  log=P/sealed[name]['log'];assert sha(log)==sealed[name]['sha256']
 assert log.is_file(),'Missing final log: '+str(log)
 text=log.read_text(encoding='utf-8-sig',errors='replace')
 assert 'PASS:' in text and not re.search(r'Fatal:|Error:|FATAL|ERROR:',text),'Log not passed: '+str(log)
 # Require the final marker, avoiding an in-progress log that has per-frame PASS.
 markers={'tb_vision6':'PASS: six modes','tb_menu_cpu8':'PASS: CPU8 all eight','tb_epd_cpu':'PASS: real RISC-V','tb_menu8_pixels':'PASS: all eight UI','tb_gesture5_rgb_ramopt':'PASS: five-class RGB-to-template'}
 if name in markers:assert markers[name] in text,'Incomplete bench: '+name
 assert 'Exiting xsim' in text,'XSim has not exited: '+name
 dest=A/(name+'.log')
 if dest.resolve()!=log.resolve():shutil.copy2(log,dest)
 bench=P/'sim'/(name+'.sv')
 if name=='tb_cache_stress':bench=P/'sim/cache_stress/tb_cache_stress.sv'
 elapsed=re.findall(r'run: Time .*?elapsed = ([0-9:]+)',text)
 items.append(dict(name=name,log=dest.relative_to(P).as_posix(),status='PASS',sha256=sha(dest),source_phase='v1',started_at=stamp(text,r'# Start of session at: (.+)'),ended_at=stamp(text,r'Exiting xsim at (.+?)\.\.\.'),xsim_elapsed=elapsed[-1] if elapsed else None,bench=bench.relative_to(P).as_posix(),bench_sha256=sha(bench)))
manifest=R/'v1_production_sha256.json'
for item in items:
 item['source_manifest']=manifest.relative_to(P).as_posix();item['source_manifest_sha256']=sha(manifest)
summary=dict(tests=items,test_count=len(items),tool=r'D:\Xilinx\Vivado\2018.3\bin',source_manifest=manifest.relative_to(P).as_posix(),source_manifest_sha256=sha(manifest),physical_board_test='not performed',provenance='reports/ramopt_regression/bench_provenance.json',note='All v1 tests refer to locked production sources; three-class historical expectations replaced by the current five-class tests. Later lossless storage substitutions require their own final-phase equivalence evidence.')
(R/'final_tests.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
(R/'v1_tests.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('Archived and verified',len(items),'passed current-function benches')
