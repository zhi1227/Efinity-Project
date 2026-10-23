"""Fresh, SHA-bound XSim runs. No programming or global tool changes."""
from pathlib import Path
import argparse, datetime, hashlib, json, shutil, subprocess, re, xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('bench');a.add_argument('--original',action='store_true');a.add_argument('--expect-fail',action='store_true');a.add_argument('--define',action='append',default=[]);args=a.parse_args()
 base=P.parent/'10_20_ding_Ti60_Gesture5_4Key_InlineThreshold' if args.original else P
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
 run=Path('D:/Github_Project/fpga_build')/('capturefix_'+args.bench+'_'+stamp);run.mkdir(parents=True);(run/'reports').mkdir()
 report=P/'reports/capture_fix'/((args.bench+'_original') if args.original else args.bench)/stamp;report.mkdir(parents=True)
 sources=[e.attrib['name'] for e in ET.parse(base/'Ti60_Demo.xml').iter() if e.tag.endswith('design_file') and e.attrib['name'].startswith(('rtl/','src/vision/','src/face/','src/parallel/','src/gesture/','src/cmos_i2c/'))]
 sources+=['ip/W0_FIFO_8/W0_FIFO_8.sv','ip/R0_FIFO_16/R0_FIFO_16.sv','src/axi/axi4_ctrl.v','src/axi/frame_buffer_select.v']
 sources=list(dict.fromkeys(sources))
 tracked={}
 for rel in sources:
  dest=run/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(base/rel,dest);tracked[str(base/rel)]=sha(base/rel)
 bench=P/'sim'/f'{args.bench}.sv';dest=run/'sim'/bench.name;dest.parent.mkdir(exist_ok=True);shutil.copy2(bench,dest);sources.append('sim/'+bench.name);tracked[str(bench)]=sha(bench)
 for f in list(base.glob('*font*.hex'))+list(base.glob('*.bin'))+list((base/'src/parallel').glob('*.vh'))+list((base/'rtl').glob('*.vh')):
  dest=run/f.relative_to(base);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dest);tracked[str(f)]=sha(f)
 record=dict(status='RUNNING',stage=str(run),base=str(base),started_utc=stamp,inputs=tracked,expected_failure=args.expect_fail)
 (report/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
 def tool(name,extra,log):
  with (report/log).open('w',encoding='utf-8') as o:
   r=subprocess.run([f'D:/Xilinx/Vivado/2018.3/bin/{name}.bat',*extra],cwd=run,stdout=o,stderr=subprocess.STDOUT)
  if r.returncode:raise RuntimeError(str(report/log))
 tool('xvlog',['--sv','-d','CAMERA_FIFO_VENDOR_IP',*[x for d in args.define for x in ('-d',d)],'-i',str(run/'src/parallel'),'-i',str(run/'rtl'),*sources],'compile.log')
 tool('xelab',[args.bench,'-s',args.bench,'--relax','-mt','off'],'elab.log')
 tool('xsim',[args.bench,'-runall','-log',str(report/'simulation.log')],'console.log')
 text=(report/'simulation.log').read_text(errors='replace')
 failure=bool(re.search(r'Fatal:|FATAL|Error:|ERROR:',text))
 ok=('EXPECTED_BASELINE_DEFECT' in text and failure) if args.expect_fail else ('PASS:' in text and '$finish called' in text and not failure)
 assert all(sha(Path(f))==h for f,h in tracked.items()),'source drift during run'
 record.update(status='PASS' if ok else 'FAIL',completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),log_sha256=sha(report/'simulation.log'),markers=[l for l in text.splitlines() if 'PASS:' in l or 'EXPECTED_BASELINE_DEFECT' in l])
 (report/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
 print(json.dumps(dict(status=record['status'],report=str(report),markers=record['markers'])),flush=True)
 if not ok:raise SystemExit(1)
if __name__=='__main__':main()
