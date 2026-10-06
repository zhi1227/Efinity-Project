"""Independent full-image integer reference; no FPGA models or NumPy dependency."""
from pathlib import Path
import random
import json
import reference_m7

ROOT=Path(__file__).resolve().parents[1]
W,H=32,24

def windows(image, border, op):
    h,w=len(image),len(image[0]);out=[[0]*w for _ in range(h)]
    for y in range(border,h-border):
        for x in range(border,w-border):
            out[y][x]=op([image[yy][xx] for yy in range(y-1,y+2) for xx in range(x-1,x+2)])
    return out

def edges(p,t,prewitt=False):
    k=1 if prewitt else 2
    gx=p[0]+k*p[3]+p[6]-p[2]-k*p[5]-p[8]
    gy=p[0]+k*p[1]+p[2]-p[6]-k*p[7]-p[8]
    return int(gx*gx+gy*gy>=t*t)

def process(rgb,mode,t):
    if mode==7:
        mask=reference_m7.process(rgb)
        return [[0xffffff if p else 0 for p in row] for row in mask],mask
    gray=[];filtered=[]
    for row in rgb:
        gr=[];pr=[]
        for value in row:
            r,g,b=value>>16,(value>>8)&255,value&255
            y=(77*r+150*g+29*b)>>8
            cb=(-43*r-85*g+128*b+32768)>>8
            cr=(128*r-107*g-21*b+32768)>>8
            gr.append(y);pr.append(y if mode!=7 or (77<cb<127 and 133<cr<173) else 0)
        gray.append(gr);filtered.append(pr)
    median=windows(filtered,1,lambda p:sorted(p)[4])
    sobel=windows(median,2,lambda p:edges(p,t))
    prewitt=windows(median,2,lambda p:edges(p,t,True))
    eroded=windows(sobel,3,lambda p:int(all(p)))
    dilated=windows(eroded,4,lambda p:int(any(p)))
    scalar=[None,gray,median,sobel,prewitt,eroded,dilated,dilated][mode]
    if mode==0:out=[row[:] for row in rgb]
    else:out=[[p*0x010101 if mode<3 else (0xffffff if p else 0) for p in row] for row in scalar]
    return out,dilated

def feature(mask):
    result=reference_m7.components(mask)
    if not result[1]:return None
    _,_,area,fill,ratio,x0,x1,y0,y1=result
    return x0,x1,y0,y1,fill

def generate():
    rng=random.Random(20260928)
    patterns=[]
    for kind in range(8):
        image=[]
        for y in range(H):
            row=[]
            for x in range(W):
                if kind==0:v=0
                elif kind==1:v=0xffffff
                elif kind==2:v=0xffffff if x>=W//2 else 0
                elif kind==3:v=0xffffff if y>=H//2 else 0
                elif kind==4:v=0xffffff if (x,y)==(W//2,H//2) else 0
                elif kind==5:v=rng.randrange(1<<24)
                elif kind==6:v=(0xd09070 if ((x//4+y//4)&1) else 0x503020)
                else:v=(x*7<<16)|(y*9<<8)|((x*11+y*3)&255)
                row.append(v)
            image.append(row)
        patterns.append(image)
    inputs=[];outputs=[];metadata=[];previous=None
    for mode in range(8):
        for kind,image in enumerate(patterns):
            threshold=[100,100,100,100,100,20,0,255][kind]
            expected,mask=process(image,mode,threshold)
            if mode==7 and previous and previous[0:2]==(mode,threshold) and previous[2]:
                x0,x1,y0,y1,_=previous[2]
                for y in range(y0,y1+1):
                    for x in range(x0,x1+1):
                        if x in (x0,x1) or y in (y0,y1):expected[y][x]=0xff0000
            previous=(mode,threshold,feature(mask))
            inputs.extend(p for row in image for p in row)
            outputs.extend(p for row in expected for p in row)
            metadata.append((mode<<8)|threshold)
    for name,values,digits in [('pixels',inputs,6),('expected',outputs,6),('modes',metadata,3)]:
        (ROOT/f'tb/{name}.hex').write_text(''.join(f'{n:0{digits}x}\n' for n in values),encoding='ascii')
    # Independent random neighborhoods expose overflow and median sorting errors.
    vectors=[]
    for _ in range(2000):
        p=[rng.randrange(256) for _ in range(9)];t=rng.randrange(256)
        word=0
        for value in p:word=(word<<8)|value
        vectors.append((word<<18)|(t<<10)|(sorted(p)[4]<<2)|(edges(p,t)<<1)|edges(p,t,True))
    (ROOT/'tb/neighborhoods.hex').write_text(''.join(f'{n:023x}\n' for n in vectors),encoding='ascii')
    (ROOT/'reports/reference_cases.json').write_text(json.dumps({'width':W,'height':H,'frames':len(metadata),
        'modes':8,'patterns':['black','white','vertical step','horizontal step','isolated pixel','random RGB','skin checker','ramp'],
        'thresholds':[0,20,100,255],'neighborhood_cases':len(vectors)},indent=2),encoding='utf-8')
    print(f'Generated {len(metadata)} frames, {len(outputs)} expected pixels and {len(vectors)} math cases.')

if __name__=='__main__':generate()
