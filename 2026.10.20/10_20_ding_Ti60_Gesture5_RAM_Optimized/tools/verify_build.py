from pathlib import Path
import re,json,hashlib,sys
import xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def input_sha(p):
 if p.name!='Ti60_Demo.xml':return sha(p)
 root=ET.fromstring(p.read_bytes())
 for key in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):
  root.attrib.pop(key,None)
 return hashlib.sha256(ET.tostring(root,encoding='utf-8')).hexdigest()
def inputs():
 roots=['rtl','src','vendor','ip']
 paths=[p for root in roots for p in (P/root).rglob('*') if p.is_file() and p.suffix.lower() in ('.v','.sv','.vh','.hex','.bin','.mem','.xml','.sdc')]
 paths += [p for p in P.iterdir() if p.is_file() and p.suffix.lower() in ('.v','.sv','.vh','.hex','.bin','.xml','.sdc')]
 return {p.relative_to(P).as_posix():input_sha(p) for p in sorted(set(paths))}
snapshot=P/'reports/vision8/build_input_sha256.json'
if '--snapshot' in sys.argv:
 snapshot.parent.mkdir(parents=True,exist_ok=True)
 snapshot.write_text(json.dumps(inputs(),indent=2),encoding='utf-8')
 print('Captured build input SHA256 manifest')
 sys.exit(0)
assert snapshot.is_file(),'Missing build input manifest; run build_fpga.ps1'
assert json.loads(snapshot.read_text(encoding='utf-8'))==inputs(),'Build inputs changed during compilation; rebuild required'
route=(P/'outflow/Ti60_Demo.route.rpt').read_text(errors='replace')
timing=(P/'outflow/Ti60_Demo.timing.rpt').read_text(errors='replace')
build=(P/'reports/efinity_build.log').read_text(encoding='utf-8-sig',errors='replace')
if '\x00' in build:build=(P/'reports/efinity_build.log').read_text(encoding='utf-16')
resources={}
for label in ['XLRs','Memory Blocks','DSP Blocks','Global Clocks (GBUF)']:
 m=re.search(re.escape(label)+r':\s*(\d+)\s*/\s*(\d+)',route);assert m,label
 used,available=map(int,m.groups());assert used<=available,(label,used,available)
 resources[label]={'used':used,'available':available}
assert resources['XLRs']['used']<=60000,'User 60K limit exceeded'
assert resources['Memory Blocks']['used']<=230,'Planned RAM budget exceeded'
for stage in ['map','interface','pnr','pgm']:assert re.search(r'^\s*'+stage+r'\s*:\s*PASS',build,re.M),stage
setup=timing.split('Setup (Max) Clock Relationship')[1].split('Hold (Min) Clock Relationship')[0]
hold=timing.split('Hold (Min) Clock Relationship')[1].split('NOTE:')[0]
def slacks(s):return [float(m[0]) for m in re.findall(r'\s(-?\d+\.\d+)\s+\(([^)]+)\)\s*$',s,re.M)]
ss,hs=slacks(setup),slacks(hold);assert ss and hs and min(ss)>=0 and min(hs)>=0,'Timing failure'
bit=P/'outflow/Ti60_Demo.bit';assert bit.is_file()
sources=list((P/'rtl').glob('*.v'))+list((P/'src').rglob('*.v'))+list((P/'src').rglob('*.vh'))+list((P/'vendor').glob('*.v'))
sources+=[P/'example_top.v']+list(P.glob('*font*.hex'))+list(P.glob('EfxSapphireSoc*.bin'))
assert all(p.stat().st_mtime<=bit.stat().st_mtime for p in sources),'Bitstream predates active source'
result={'resources':resources,'min_setup_slack_ns':min(ss),'min_hold_slack_ns':min(hs),
 'bit_sha256':sha(bit),'hex_sha256':sha(P/'outflow/Ti60_Demo.hex'),
 'build_input_manifest_sha256':sha(snapshot),
 'physical_board_test':'not performed; simulation and compilation only'}
(P/'reports/build_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
