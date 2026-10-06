from PIL import Image
from pathlib import Path
import subprocess,json
P=Path(__file__).resolve().parents[1]
STRIDES=(8,9,10,11,12,14,16,18,20,22,24,26,28)
SCALES=[(s,(1280+s-1)//s,(720+s-1)//s) for s in STRIDES]
def detect(im,phase,name):
 v=list(im.getdata());golden=[]
 for stride,w,h in SCALES:
  fn=P/f'sim/{name}_scale{stride}.raw'
  fn.write_bytes(bytes(v[(y*stride//8)*160+x*stride//8] for y in range(h) for x in range(w)))
  r=subprocess.run([str(P/'tools/haar_reference.exe'),str(fn),str(w),str(h),'2',str(phase&1),str(phase>>1)],capture_output=True,text=True,check=True)
  for row in r.stdout.splitlines():
   x,y,_,_=map(int,row.split(','));golden.append([x*stride+4,y*stride+4,24*stride])
 return golden
im=Image.open(P.parent/'facedetect-fpga/gen_dataset/image0_320_240.pgm').convert('L').resize((160,120),Image.Resampling.NEAREST).crop((0,15,160,105))
im.save(P/'reports/test_input.png')
# A large face from the existing licensed regression image exercises the new scales.
near=Image.new('L',(160,90),128)
near.paste(im.crop((20,26,46,52)).resize((80,80),Image.Resampling.BILINEAR),(40,5))
near.save(P/'reports/test_near_input.png')
counts=[];report={}
for name,picture in [('positive',im),('near',near),('blank',Image.new('L',(160,90),128))]:
 (P/f'sim/{name}.mem').write_text('\n'.join(f'{x:02x}' for x in picture.getdata())+'\n')
 for phase in range(4):
  boxes=detect(picture,phase,name);counts.append(len(boxes));report[f'{name}_{phase}']=boxes
  (P/f'sim/expected_{name}_{phase}.mem').write_text('\n'.join(f'{x|(y<<11)|(s<<21):08x}' for x,y,s in boxes)+'\n' if boxes else '00000000\n')
  print(name,'phase',phase,'count',len(boxes),'large',sum(s>384 for x,y,s in boxes))
  if name=='positive' and phase==0:
   (P/'sim/expected.mem').write_text('\n'.join(f'{x|(y<<11)|(s<<21):08x}' for x,y,s in boxes)+'\n')
   (P/'sim/expected_count.vh').write_text(f'`define EXPECTED_COUNT {len(boxes)}\n')
assert any(s>384 for k,b in report.items() if k.startswith('near') for x,y,s in b), 'Large-face fixture must exercise new large scales'
assert all(n==0 for n in counts[8:]), 'Uniform image must not create detections'
(P/'sim/expected_counts.mem').write_text('\n'.join(f'{n:04x}' for n in counts)+'\n')
(P/'reports/golden_detections.json').write_text(json.dumps(report,indent=2))
self_im=Image.new('L',(160,90));self_im.putdata([int(a,16)*17 for a in (P/'model/selftest.mem').read_text().split()])
self_count=len(detect(self_im,0,'self'))
(P/'sim/self_expected_count.vh').write_text(f'`define SELF_EXPECTED_COUNT {self_count}\n')
print('Self-test expected',self_count)
