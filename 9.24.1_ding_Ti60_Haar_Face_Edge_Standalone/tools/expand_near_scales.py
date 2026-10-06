from pathlib import Path
import re
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
strides=[8,9,10,11,12,14,16,18,20,22,24,26,28]
f=P/'src/haar/haar_engine.v';s=f.read_text();s=s.replace('SCALE_COUNT=7','SCALE_COUNT=13').replace('reg [2:0] scale_id','reg [3:0] scale_id')
a=s.index('       case(scale_id)');b=s.index('       endcase',a)
lines=['       case(scale_id)']
for i,k in enumerate(strides[1:]):
 label=str(i) if i<len(strides)-2 else 'default'
 lines.append(f'        {label}:begin stride<={k};sw<={(1280+k-1)//k};sh<={(720+k-1)//k};end')
s=s[:a]+'\n'.join(lines)+'\n'+s[b:];f.write_text(s)
print('Expanded scales:',[(k,24*k,(1280+k-1)//k,(720+k-1)//k) for k in strides])
