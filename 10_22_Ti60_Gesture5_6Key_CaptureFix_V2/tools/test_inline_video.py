"""Source-bound real XSim original/default equality and runtime threshold checks."""
from pathlib import Path
import datetime as dt,hashlib,json,subprocess,sys,time,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1];R=P/'reports/inline_threshold/video'
R.mkdir(parents=True,exist_ok=True)
V=Path(r'D:/Xilinx/Vivado/2018.3/bin');RUN=P/'sim_inline_video';RUN.mkdir(exist_ok=True);(RUN/'reports').mkdir(exist_ok=True)
import shutil
for f in P.glob('*font*.hex'):shutil.copy2(f,RUN/f.name)
src=[e.attrib['name'] for e in ET.parse(P/'Ti60_Demo.xml').iter() if e.tag.endswith('design_file') and e.attrib['name'].startswith(('rtl/','src/vision/','src/face/','src/parallel/','src/gesture/','src/cmos_i2c/'))]
src+=['sim/inline_reference/parallel_video_original.v','sim/inline_reference/vision6_overlay_original.v','sim/tb_inline_video_defaults.sv','sim/tb_inline_video_dynamic.sv']
tracked=[P/x for x in src]+list((P/'src/parallel').glob('*.vh'))+list(P.glob('*font*.hex'))
inputs={x.relative_to(P).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in tracked}
started=dt.datetime.now(dt.timezone.utc).isoformat()
(R/'inputs.json').write_text(json.dumps({'started_utc':started,'sources':inputs},indent=2),encoding='utf-8')
def run(exe,args,log):
 with (R/log).open('w',encoding='utf-8') as f:
  result=subprocess.run(subprocess.list2cmdline([str(V/exe)]+args),shell=True,cwd=RUN,stdout=f,stderr=subprocess.STDOUT)
 text=(R/log).read_text(encoding='utf-8',errors='replace')
 if result.returncode or any(x in text for x in ('ERROR:','Fatal:','FATAL')):raise RuntimeError(log+'\n'+text[-5000:])
 return text
run('xvlog.bat',['--sv','-i',str(P/'src/parallel')]+[str(P/x) for x in src],'compile.log')
results=[]
benches=[('tb_inline_video_dynamic','PASS: inline dynamic 12 frames 147456 pixels'),('tb_inline_video_defaults','PASS: inline default original equality 6451200 pixels')]
for bench,marker in benches:
 t=time.monotonic();run('xelab.bat',[bench,'-s',bench,'--relax','-mt','off'],bench+'_elab.log')
 run('xsim.bat',[bench,'-runall','-log',str(R/(bench+'.log'))],bench+'_console.log')
 log=R/(bench+'.log');text=log.read_text(errors='replace');assert marker in text and '$finish called at time' in text
 results.append(dict(bench=bench,status='PASS',log=log.relative_to(P).as_posix(),sha256=hashlib.sha256(log.read_bytes()).hexdigest(),completion_markers=[marker,'$finish called at time'],seconds=round(time.monotonic()-t,2)))
 (R/'results.json').write_text(json.dumps({'status':'RUNNING' if len(results)<2 else 'PASS','started_utc':started,'results':results,'sources':inputs},indent=2),encoding='utf-8')
 print(bench,'PASS',flush=True)
for rel,sha in inputs.items():assert hashlib.sha256((P/rel).read_bytes()).hexdigest()==sha,'Test source changed: '+rel
print('PASS: inline video original/default and dynamic suites completed',flush=True)
