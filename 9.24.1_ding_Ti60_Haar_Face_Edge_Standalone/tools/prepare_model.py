from pathlib import Path
import re,json,hashlib
P=Path(__file__).resolve().parents[1]
S=P.parent/'facedetect-fpga/Baseline'
a={}
for f in ['haar_dataRcc_with_partitioning.h','haar_dataEWC_with_partitioning.h']:
 t=(S/f).read_text()
 for name,n,body in re.findall(r'(\w+)\[(\d+)\]\s*=\s*\{([^}]+)\}',t):
  v=[int(x) for x in re.findall(r'-?\d+',body)]
  assert len(v)==int(n),(name,len(v),n)
  a[name]=v
print({k:(len(v),min(v),max(v)) for k,v in a.items()})
(P/'model/cascade.json').write_text(json.dumps(a))
# Packed 120-bit records: 3x20 geometry, 3x4 weight units (4096), threshold16, leaves16 each.
lines=[]
for i in range(2913):
 z=0
 for r in range(3):
  for j in range(4):z|=a[f'rectangles_array{r*4+j}'][i]<<(r*20+j*5)
  w=a[f'weights_array{r}'][i];assert w%4096==0 and -8<=w//4096<8
  z|=((w//4096)&15)<<(60+4*r)
 for k,off in [('tree_thresh_array',72),('alpha1_array',88),('alpha2_array',104)]:
  v=a[k][i];assert -32768<=v<32768
  z|=(v&65535)<<off
 lines.append(f'{z:030x}')
(P/'model/features.mem').write_text('\n'.join(lines)+'\n')
end=0;lines=[]
for n,t in zip(a['stages_array'],a['stages_thresh_array']):
 end+=n
 # ceil(2*t/5): equivalent to integer sum < 0.4*t; avoid float hardware.
 thresh=-((-2*t)//5)
 assert -(1<<19)<=thresh<(1<<19)
 lines.append(f'{((thresh&((1<<20)-1))<<12)|(end-1):08x}')
assert end==2913
(P/'model/stages.mem').write_text('\n'.join(lines)+'\n')
(P/'model/model_arrays.h').write_text('\n'.join('static const int '+k+'[] = {'+','.join(map(str,v))+'};' for k,v in a.items()))

