from pathlib import Path
import re,json,hashlib
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
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
for stage in ['map','interface','pnr','pgm']:assert re.search(r'^\s*'+stage+r'\s*:\s*PASS',build,re.M),stage
setup=timing.split('Setup (Max) Clock Relationship')[1].split('Hold (Min) Clock Relationship')[0]
hold=timing.split('Hold (Min) Clock Relationship')[1].split('NOTE:')[0]
def slacks(s):return [float(m[0]) for m in re.findall(r'\s(-?\d+\.\d+)\s+\(([^)]+)\)\s*$',s,re.M)]
ss,hs=slacks(setup),slacks(hold);assert ss and hs and min(ss)>=0 and min(hs)>=0,'Timing failure'
bit=P/'outflow/Ti60_Demo.bit';assert bit.is_file()
sources=list((P/'rtl').glob('*.v'))+list((P/'src').rglob('*.v'))+list((P/'src').rglob('*.vh'))+list((P/'vendor').glob('*.v'))
sources+=[P/'example_top.v',P/'menu_font.hex',P/'vision6_font.hex']+list(P.glob('EfxSapphireSoc*.bin'))
assert all(p.stat().st_mtime<=bit.stat().st_mtime for p in sources),'Bitstream predates active source'
result={'resources':resources,'min_setup_slack_ns':min(ss),'min_hold_slack_ns':min(hs),
 'bit_sha256':sha(bit),'hex_sha256':sha(P/'outflow/Ti60_Demo.hex'),
 'physical_board_test':'not performed; user must confirm camera video and diagnostic lights'}
(P/'reports/build_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
