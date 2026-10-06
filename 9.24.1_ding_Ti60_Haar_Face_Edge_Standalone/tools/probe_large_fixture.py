from pathlib import Path
import subprocess
from PIL import Image
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
im=Image.open(P/'reports/test_input.png').convert('L')
for side in [72,80,84]:
 pic=Image.new('L',(160,90),128);pic.paste(im.crop((20,26,46,52)).resize((side,side),Image.Resampling.BILINEAR),((160-side)//2,(90-side)//2))
 v=pic.tobytes();boxes=[]
 for stride in [8,9,10,11,12,14,16,18,20,22,24,26,28]:
  w,h=(1280+stride-1)//stride,(720+stride-1)//stride
  f=P/'sim/near_probe.raw';f.write_bytes(bytes(v[(y*stride//8)*160+x*stride//8] for y in range(h) for x in range(w)))
  r=subprocess.run([str(P/'tools/haar_reference.exe'),str(f),str(w),str(h),'2','0','0'],capture_output=True,text=True,check=True)
  boxes.extend([stride*24 for _ in r.stdout.splitlines()])
 print(side,boxes)
