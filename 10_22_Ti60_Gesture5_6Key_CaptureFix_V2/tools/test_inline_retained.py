"""Retained final-source inline-threshold regressions; historical RAMOPT reports untouched."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,time,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
R=P/'reports/inline_threshold/retained';R.mkdir(parents=True,exist_ok=True)
RUN=P/'sim_inline_retained';RUN.mkdir(exist_ok=True)
V=Path(os.environ.get('RAMOPT_VIVADO',r'D:/Xilinx/Vivado/2018.3/bin'))
BENCHES=['tb_vision8_key_boundary','tb_vision8_fifo','tb_vision8_ddr','tb_vision8_frames','tb_vision8_faces','tb_io29_freeze_ddr','tb_vision8_gesture','tb_h5_palm','tb_h5_wave','tb_gesture5_controls_new','tb_gesture5_templates_ramopt','tb_gesture5_rgb_ramopt','tb_gesture5_shared_overlay_ramopt','tb_h4_skin','tb_h4_overlay','tb_controls6','tb_matrix5_ramopt','tb_h5_ui','tb_i2c6','tb_health6','tb_frame_path','tb_menu_cdc6','tb_camera_rgb_fifo']
if len(sys.argv)>1:
 BENCHES=[b for b in BENCHES if b in sys.argv[1:]]
 assert BENCHES,'No selected benches'
import shutil
for f in P.glob('*font*.hex'):shutil.copy2(f,RUN/f.name)
for f in (P/'tb').glob('*.hex'):shutil.copy2(f,RUN/f.name)
(RUN/'reports').mkdir(exist_ok=True)
sources=[e.attrib['name'] for e in ET.parse(P/'Ti60_Demo.xml').iter() if e.tag.endswith('design_file') and e.attrib['name'].startswith(('rtl/','src/vision/','src/face/','src/parallel/','src/gesture/','src/cmos_i2c/'))]
sources+=['ip/W0_FIFO_8/W0_FIFO_8.sv','ip/R0_FIFO_16/R0_FIFO_16.sv','src/axi/axi4_ctrl.v','src/axi/frame_buffer_select.v']
sources=list(dict.fromkeys(sources))+['sim/'+b+'.sv' for b in BENCHES]
tracked=[P/s for s in sources]+list((P/'src/parallel').glob('*.vh'))+list(P.glob('*font*.hex'))
manifest={x.relative_to(P).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in tracked}
(R/'input_sha256.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
def run(exe,args,log):
 cmd=[str(V/exe)]+args
 with (R/log).open('w',encoding='utf-8') as f:r=subprocess.run(subprocess.list2cmdline(cmd),shell=True,cwd=RUN,stdout=f,stderr=subprocess.STDOUT)
 txt=(R/log).read_text(errors='replace')
 if r.returncode or any(s in txt for s in ('ERROR:','Fatal:','FATAL')):raise RuntimeError(log+'\n'+txt[-4000:])
 return txt
run('xvlog.bat',['--sv','-d','CAMERA_FIFO_VENDOR_IP','-i','../src/parallel']+['../'+s for s in sources],'compile.log')
results=[]
for b in BENCHES:
 start=time.monotonic()
 try:
  run('xelab.bat',[b,'-s',b,'--relax','-mt','off'],b+'_elab.log')
  text=run('xsim.bat',[b,'-runall','-log',str(R/(b+'.log'))],b+'_console.log')
  assert 'PASS:' in text and '$finish called' in text,text[-3000:]
  results.append(dict(bench=b,status='PASS',seconds=round(time.monotonic()-start,2),log=b+'.log',log_sha256=hashlib.sha256((R/(b+'.log')).read_bytes()).hexdigest(),completion_markers=[line for line in text.splitlines() if 'PASS:' in line]+['$finish called']))
  print(b,'PASS',flush=True)
 except Exception as e:
  results.append(dict(bench=b,status='FAIL',seconds=round(time.monotonic()-start,2),error=str(e)))
  print(b,'FAIL',str(e)[-1000:],flush=True)
 (R/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
for rel,digest in manifest.items():
 assert hashlib.sha256((P/rel).read_bytes()).hexdigest()==digest,'Source changed during test: '+rel
(R/'summary.json').write_text(json.dumps(dict(status='PASS' if all(x['status']=='PASS' for x in results) else 'FAIL',results=results,excluded=['tb_vision8_controls: superseded by tb_inline_controls','tb_vision6: root stronger seven-scene golden regression']),indent=2),encoding='utf-8')
print('RESULTS',json.dumps(results),flush=True)
if any(t['status']!='PASS' for t in results):raise SystemExit(1)
