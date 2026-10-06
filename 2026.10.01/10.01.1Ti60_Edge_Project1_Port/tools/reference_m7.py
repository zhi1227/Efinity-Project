"""Independent binary-image/flood-fill reference. Python runs only offline."""
from pathlib import Path
from collections import deque
import random,json
ROOT=Path(__file__).resolve().parents[1]
DISK=[(dx,dy) for dy in range(-3,4) for dx in range(-3,4) if dx*dx+dy*dy<=9]
assert len(DISK)==29
def skin(rgb,lower=10):
 r,g,b=rgb>>16,(rgb>>8)&255,rgb&255
 y=(77*r+150*g+29*b)>>8
 return int(lower<max(r-g,0)<90 and r>b and 32<=y<=240)
def process(image,lower=10):
 h,w=len(image),len(image[0]);a=[bytearray(skin(p,lower) for p in row) for row in image]
 b=[bytearray(w) for _ in range(h)]
 for y in range(3,h-3):
  for x in range(3,w-3):b[y][x]=sum(a[y+dy][x+dx] for dx,dy in DISK)>=15
 for border,dilate in [(4,False),(5,True)]:
  a=b;b=[bytearray(w) for _ in range(h)]
  for y in range(border,h-border):
   for x in range(border,w-border):
    values=(a[yy][xx] for yy in range(y-1,y+2) for xx in range(x-1,x+2))
    b[y][x]=any(values) if dilate else all(values)
 return b
def components(mask,border=5,minw=40,minh=40,mina=2500,maxa=460800,cap=64):
 h,w=len(mask),len(mask[0]);seen=set();blobs=[]
 for y in range(h):
  for x in range(w):
   if not mask[y][x] or (x,y) in seen:continue
   q=deque([(x,y)]);seen.add((x,y));pts=[]
   while q:
    xx,yy=q.popleft();pts.append((xx,yy))
    for dy in (-1,0,1):
     for dx in (-1,0,1):
      p=(xx+dx,yy+dy)
      if 0<=p[0]<w and 0<=p[1]<h and mask[p[1]][p[0]] and p not in seen:seen.add(p);q.append(p)
   xs,ys=zip(*pts);x0,x1,y0,y1=min(xs),max(xs),min(ys),max(ys)
   area=len(pts);bw=x1-x0+1;bh=y1-y0+1;fill=area*1000//(bw*bh);ratio=bh*1000//bw
   blobs.append((area,fill,ratio,x0,x1,y0,y1))
 if len(blobs)>cap:return (1,0,0,0,0,0,0,0,0)
 valid=[b for b in blobs if b[4]-b[3]+1>=minw and b[6]-b[5]+1>=minh and mina<=b[0]<=maxa and b[1]>=150
        and b[3]>border and b[4]<w-1-border and b[5]>border and b[6]<h-1-border]
 return (0,1,*sorted(valid,key=lambda b:(-b[0],b[5],b[3]))[0]) if valid else (0,0,0,0,0,0,0,0,0)
def generate():
 w,h=128,96;rng=random.Random(73641);cases=[];names=[]
 def new(name):
  a=[bytearray(w) for _ in range(h)];cases.append(a);names.append(name);return a
 def rect(a,x0,y0,x1,y1):
  for y in range(y0,y1+1):a[y][x0:x1+1]=bytes([1])*(x1-x0+1)
 new('empty');a=new('two remote specks');a[5][5]=a[90][120]=1
 for n in range(3):rect(new('rectangle stable '+str(n)),20,20,49,49)
 new('removed')
 a=new('largest not global bbox');rect(a,8,8,17,17);rect(a,70,45,109,74)
 a=new('equal area earliest y then x');rect(a,65,10,84,29);rect(a,10,10,29,29)
 a=new('late bridge joins roots');rect(a,15,12,22,65);rect(a,60,12,67,65);rect(a,15,60,67,65)
 a=new('one root splits then joins');rect(a,15,12,67,17);rect(a,15,12,22,65);rect(a,60,12,67,65);rect(a,15,60,67,65)
 a=new('diagonal connection');rect(a,20,20,29,29);rect(a,30,30,39,39)
 a=new('blank row separates');rect(a,20,20,40,29);rect(a,20,31,40,39)
 rect(new('truncated boundary'),0,15,40,70)
 a=new('candidate overflow 65');
 for i in range(65):rect(a,3+(i%13)*9,3+(i//13)*9,6+(i%13)*9,6+(i//13)*9)
 a=new('full white');rect(a,0,0,w-1,h-1)
 for i in range(15):
  a=new('random overlapping rectangles '+str(i))
  for j in range(12):
   x=rng.randrange(3,100);y=rng.randrange(3,70);rect(a,x,y,x+rng.randrange(2,24),y+rng.randrange(2,24))
 a=new('exact capacity 64');
 for i in range(64):rect(a,3+(i%13)*9,3+(i//13)*9,6+(i%13)*9,6+(i//13)*9)
 (ROOT/'tb/ccl_pixels.hex').write_text(''.join(str(p)+'\n' for a in cases for row in a for p in row))
 expected=[]
 for a in cases:
  v=components(a,1,4,4,20,w*h)
  word=0
  for n,bits in zip(v,[1,1,20,10,20,11,11,10,10]):word=(word<<bits)|n
  expected.append(f'{word:024x}\n')
 (ROOT/'tb/ccl_expected.hex').write_text(''.join(expected))
 vectors=[]
 for _ in range(2000):
  rgb=rng.randrange(1<<24);lo=rng.randrange(86);vectors.append((rgb<<9)|(lo<<1)|skin(rgb,lo))
 for d in (0,9,10,11,89,90,91):
  for b in (40,100,220):
   rgb=((100+d)<<16)|(100<<8)|b;vectors.append((rgb<<9)|(10<<1)|skin(rgb))
 (ROOT/'tb/skin_vectors.hex').write_text(''.join(f'{v:09x}\n' for v in vectors))
 image=[[(0xa0785f if 256<=x<512 and 200<=y<456 else 0x202020) for x in range(1280)] for y in range(720)]
 mask=process(image)
 (ROOT/'tb/full_m7.hex').write_text(''.join('ffffff\n' if p else '000000\n' for row in mask for p in row))
 info={'ccl_cases':names,'skin_cases':len(vectors),'full_m7_expected':components(mask),'disk_points':len(DISK)}
 (ROOT/'reports/m7_reference.json').write_text(json.dumps(info,indent=2))
 print('Generated',len(cases),'CCL cases,',len(vectors),'skin cases and 720p skin mask')
if __name__=='__main__':generate()
