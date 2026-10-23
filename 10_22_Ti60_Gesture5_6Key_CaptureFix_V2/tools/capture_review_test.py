"""Append-only XSim evidence. Explicit bench names; terminal errors and input hashes.

Physical DDR PHY is header-only for the actual-top smoke; its boundary is driven
by that bench, not presented as a physical DDR/MIPI/PLL simulation.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, re, shutil, subprocess, sys
import xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('benches',nargs='+');ap.add_argument('--original',action='store_true');args=ap.parse_args()
 base=P.parent/'10_20_ding_Ti60_Gesture5_4Key_InlineThreshold' if args.original else P
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
 stage=Path('D:/Github_Project/fpga_build')/('review_'+stamp);stage.mkdir(parents=True,exist_ok=False);(stage/'reports').mkdir()
 report=P/'reports/capture_review/runs'/stamp;report.mkdir(parents=True,exist_ok=False)
 record=dict(status='RUNNING',stage=str(stage),base=str(base),started_utc=now(),results=[],inputs={})
 def save(): (report/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
 save()
 try:
  sources=[e.attrib['name'] for e in ET.parse(base/'Ti60_Demo.xml').iter() if e.tag.endswith('design_file')]
  sources+=['ip/W0_FIFO_8/W0_FIFO_8.sv','ip/R0_FIFO_16/R0_FIFO_16.sv']
  extra=[]
  if 'tb_review_top' in args.benches:
   phy=base/'ip/DdrCtrl/DdrCtrl.sv';txt=phy.read_text();m=re.search(r'\bmodule\s+DdrCtrl\b.*?\);',txt,re.S);assert m,'PHY header not found'
   (stage/'physical_ddr_boundary.sv').write_text(m.group(0)+'\nendmodule\n',encoding='utf-8');extra+=['physical_ddr_boundary.sv'];record['inputs'][str(phy)]=sha(phy)
   record['physical_boundary']='DDR PHY header stub; clocks/resets/camera/health and AXI boundary driven by tb_review_top. Actual user top and logical instances unchanged. SDC checked by PNR, not interpreted by XSim.'
  if 'tb_review_video_defaults' in args.benches:
   original=P.parent/'10_20_ding_Ti60_Gesture5_4Key_InlineThreshold'
   for rel,module in [('src/parallel/parallel_video.v','parallel_video'),('rtl/vision6_overlay.v','vision6_overlay')]:
    f=original/rel;record['inputs'][str(f)]=sha(f);txt=f.read_text(encoding='utf-8')
    txt=re.sub(r'\bparallel_video\b','parallel_video_original',txt);txt=re.sub(r'\bvision6_overlay\b','vision6_overlay_original',txt)
    dest='reference_'+module+'.v';(stage/dest).write_text(txt,encoding='utf-8');extra.append(dest)
   record['golden']='Actual named 4Key predecessor parallel_video and overlay; module identifiers renamed only. Unchanged leaf RTL current-vs-predecessor hashes checked by acceptance.'
  sources+=['sim/'+b+'.sv' for b in args.benches]
  if any(b.startswith('tb_inline_video') for b in args.benches):sources+=['sim/inline_reference/parallel_video_original.v','sim/inline_reference/vision6_overlay_original.v']
  sources=list(dict.fromkeys(sources))
  files=[(base/s if not s.startswith('sim/') else P/s) for s in sources]
  files+=list(base.glob('*font*.hex'))+list(base.glob('*.bin'))+list((base/'tb').glob('*.hex'))
  files+=list((base/'rtl').glob('*.vh'))+list((base/'src/parallel').glob('*.vh'))+[base/'src/lcd_para.v',base/'Ti60_Demo.xml',base/'Ti60_Demo.pt.sdc',base/'Ti60_Demo.peri.xml',P/'tools/capture_review_test.py',base/'image/epaper.hex']
  for f in dict.fromkeys(files):
   rel=f.relative_to(P) if f.is_relative_to(P) else f.relative_to(base)
   dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dest);record['inputs'][str(f)]=sha(f)
  for f in (stage/'tb').glob('*.hex'):shutil.copy2(f,stage/f.name)
  shutil.copy2(stage/'image/epaper.hex',stage/'epaper.hex')
  if 'tb_fourkey_font' in args.benches:
   words=(stage/'shared_font.hex').read_text().split();assert len(words)<=8192
   (stage/'shared_font_expected_8192.hex').write_text('\n'.join(words+['0000']*(8192-len(words)))+'\n',encoding='ascii')
  def tool(name,cmd,log):
   with (report/log).open('w',encoding='utf-8') as out:r=subprocess.run([f'D:/Xilinx/Vivado/2018.3/bin/{name}.bat',*cmd],cwd=stage,stdout=out,stderr=subprocess.STDOUT)
   t=(report/log).read_text(errors='replace')
   if r.returncode or re.search(r'ERROR:|Fatal:|FATAL',t):raise RuntimeError(f'{name} exit={r.returncode}: {log}\n'+t[-3500:])
   return t
  save();tool('xvlog',['--sv','-d','CAMERA_FIFO_VENDOR_IP','-i','src','-i','src/parallel','-i','rtl',*sources,*extra],'compile.log')
  for b in args.benches:
   entry=dict(bench=b,status='RUNNING');record['results'].append(entry);save()
   try:
    tool('xelab',[b,'-s',b,'--relax','-mt','off'],b+'_elab.log')
    tool('xsim',[b,'-runall','-log',str(report/(b+'.log'))],b+'_console.log')
    log=report/(b+'.log');t=log.read_text(errors='replace');assert 'PASS:' in t and '$finish called' in t,'Missing terminal PASS/finish'
    assert not re.search(r'ERROR:|Error:|Fatal:|FATAL',t),'Simulation errors'
    entry.update(status='PASS',log=log.relative_to(P).as_posix(),sha256=sha(log),markers=[l for l in t.splitlines() if 'PASS:' in l])
   except Exception as e:entry.update(status='FAIL',error=str(e))
   save();print(b,entry['status'],entry.get('error',''),flush=True)
  assert all(sha(Path(f))==h for f,h in record['inputs'].items()),'Source drift during run'
  record['status']='PASS' if all(x['status']=='PASS' for x in record['results']) else 'FAIL'
 except Exception as e:record.update(status='ERROR',error=str(e));print(str(e),flush=True)
 finally:record['completed_utc']=now();save();print('EVIDENCE',report/'result.json',flush=True)
 if record['status']!='PASS':raise SystemExit(1)
if __name__=='__main__':main()
