from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
tests=['tb_haar','tb_haar_video','tb_haar_integration','tb_haar_selftest','tb_haar_tracker','tb_gray_thumbnail','tb_haar_near']
for name in tests:
 t=(P/f'sim/{name}.log').read_text(errors='replace')
 assert 'PASS' in t and '$finish called' in t and not re.search(r'Fatal:|FAIL|ERROR:',t),name
log=(P/'reports/build.log').read_text(errors='replace')
assert all(re.search(stage+r'\s*:\s*PASS',log) for stage in ['map','interface','pnr','pgm'])
assert not re.search(r'FAIL|ERROR',log)
timing=(P/'outflow/Ti60_Demo.timing.rpt').read_text()
setup=timing.split('Setup (Max) Clock Relationship')[1].split('Hold (Min) Clock Relationship')[0]
hold=timing.split('Hold (Min) Clock Relationship')[1].split('NOTE:')[0]
def slacks(t):return [float(v) for v in re.findall(r'^\s+\w+\s+\w+\s+-?\d+\.\d+\s+(-?\d+\.\d+)\s+\(',t,re.M)]
ss,hs=slacks(setup),slacks(hold);assert len(ss)>=10 and len(hs)>=10
assert min(ss)>=0 and min(hs)>=0
place=(P/'outflow/Ti60_Demo.place.rpt').read_text()
resources={name:int(re.search(tag+r':\s+(\d+)\s*/',place)[1]) for name,tag in [('xlr','XLRs'),('ram','Memory Blocks'),('dsp','DSP Blocks')]}
paths=set();ns={'e':'http://www.efinixinc.com/enf_proj'};r=ET.parse(P/'Ti60_Demo.xml')
for f in r.findall('.//e:design_file',ns):paths.add(P/f.attrib['name'])
for d in ['ip','model','tb']:
 paths.update(f for f in (P/d).rglob('*') if f.is_file())
for f in ['Ti60_Demo.xml','Ti60_Demo.peri.xml','Ti60_Demo.pt.sdc','outflow/Ti60_Demo.bit','outflow/Ti60_Demo.hex','sim/positive.mem','sim/expected.mem','sim/expected_count.vh']:paths.add(P/f)
paths.update(f for f in (P/'sim').glob('*') if f.suffix in ('.mem','.vh'))
bit=(P/'outflow/Ti60_Demo.bit').stat().st_mtime
implementation_paths=[f for f in paths if f.relative_to(P).parts[0] not in ('tb','sim')]
assert all(f.stat().st_mtime<=bit for f in implementation_paths if f.suffix in ['.v','.sv','.vh','.mem','.sdc']), 'implementation sources newer than bit'
result={'date':'2026-09-24','board':'Ti60F225 C4','jtag_id':'0x10660A79','resources':resources,'setup_ns':min(ss),'hold_ns':min(hs),'setup_relationships':len(ss),'hold_relationships':len(hs),'tests':tests,'visual_acceptance':'Latency and near-face revision: awaiting on-board confirmation; prior image had stable boxes but slow acquisition.','files':[{'path':f.relative_to(P).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(paths)]}
(P/'reports/build_manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))
