from board_tools import *
from check_board import geometry,distance as copper_distance,pseg
import heapq, numpy as np, time

docs=json.loads((OUT/'modified_state.json').read_text(encoding='utf8'))
P=docs[PCB]['records'];initial=copy.deepcopy(P)
manifest=json.loads((OUT/'修改清单.json').read_text(encoding='utf8'))
new_ids=manifest['new_ids']
STEP=2.0; X0=-170.015;Y0=43.9071;NX=1969;NY=1969
CLEAR=8.27;MARGIN=0.5
route_log=[]
removable_ground_vias=set()
manual_ids=set()

def grid(x,y):return round((x-X0)/STEP),round((y-Y0)/STEP)
def coord(x,y):return X0+x*STEP,Y0+y*STEP
def rid():return uuid.uuid4().hex[:16]
def add(typ,p):
    ident=rid();p.update(locked=False,zIndex=max(v['data'].get('zIndex',0) or 0 for v in P.values())+1)
    P[ident]={'head':{'type':typ,'id':ident},'data':p};return ident

def line(net,a,b,layer,width=10):
    if math.dist(a,b)<1e-6:return
    # Walking within existing copper needs no duplicate stroke at grid-rounded coordinates.
    for v in P.values():
        p=v['data']
        if p.get('netName','').upper()!=net.upper():continue
        if v['head']['type']=='LINE' and p.get('layerId')==layer:
            if max(pseg(a,(p['startX'],p['startY']),(p['endX'],p['endY'])),pseg(b,(p['startX'],p['startY']),(p['endX'],p['endY'])))<p['width']/2-.05:return
        elif v['head']['type']=='VIA' and max(math.dist(a,(p['centerX'],p['centerY'])),math.dist(b,(p['centerX'],p['centerY'])))<p['viaDiameter']/2-.05:return
    add('LINE',{'partitionId':'','groupId':0,'netName':net,'layerId':layer,'startX':round(a[0],5),'startY':round(a[1],5),'endX':round(b[0],5),'endY':round(b[1],5),'width':width})

def via(net,point):
    add('VIA',{'partitionId':'','groupId':0,'netName':net,'ruleName':'','centerX':round(point[0],5),'centerY':round(point[1],5),'holeDiameter':.3/.0254,'viaDiameter':.6/.0254,'viaType':'NORMAL','topSolderExpansion':None,'bottomSolderExpansion':None})

def all_pads():return pads(docs)
def pad(des,num):return next(p for p in all_pads() if p['des']==des and p['num']==str(num))
def endpoint(p):return p['x'],p['y'],0 if p['layerId']!=2 else 1

def draw_obstacles(net,expand,allow_manual=False):
    imgs=[Image.new('1',(NX,NY),0),Image.new('1',(NX,NY),0)];draw=[ImageDraw.Draw(im) for im in imgs]
    def ball(d,x,y,r):
        gx,gy=(x-X0)/STEP,(y-Y0)/STEP;rr=r/STEP;d.ellipse((gx-rr,gy-rr,gx+rr,gy+rr),fill=1)
    for v in P.values():
        typ=v['head']['type'];p=v['data'];n=p.get('netName','')
        if n.upper()==net.upper():continue
        if typ=='LINE' and p.get('layerId') in (1,2):
            d=draw[p['layerId']-1];r=p['width']/2+expand
            d.line([( (p['startX']-X0)/STEP,(p['startY']-Y0)/STEP),((p['endX']-X0)/STEP,(p['endY']-Y0)/STEP)],fill=1,width=math.ceil(2*r/STEP))
            ball(d,p['startX'],p['startY'],r);ball(d,p['endX'],p['endY'],r)
        elif typ=='VIA':
            if v['head']['id'] in removable_ground_vias:continue
            for d in draw:ball(d,p['centerX'],p['centerY'],p['viaDiameter']/2+expand)
        elif typ=='POUR' and n.upper()!='GND' and p.get('layerId') in (1,2):
            # Existing small power pours are fixed obstacles; ground pours will be rebuilt.
            for path in p['path']:
                points=[];i=0
                while i<len(path):
                    if isinstance(path[i],(float,int)) and i+1<len(path) and isinstance(path[i+1],(float,int)):
                        points.append(((path[i]-X0)/STEP,(path[i+1]-Y0)/STEP));i+=2
                    else:i+=1
                if len(points)>2:
                    d=draw[p['layerId']-1];d.polygon(points,fill=1);d.line(points+[points[0]],fill=1,width=math.ceil(2*expand/STEP))
    for p in all_pads():
        if p['net'].upper()==net.upper():continue
        if p['layerId'] not in (1,2,12):continue
        f=p['defaultPad'];w=f['width']/2;h=f['height']/2
        if not p['plated']:
            w=max(w,p['hole']['width']/2);h=max(h,p['hole']['height']/2)
        angle=math.radians(p['angle']);points=[]
        def xy(x,y):return p['x']+x*math.cos(angle)-y*math.sin(angle),p['y']+x*math.sin(angle)+y*math.cos(angle)
        layers=[0,1] if p['layerId']==12 else [p['layerId']-1]
        if f['padType']=='OVAL' or f['padType']=='ELLIPSE' and abs(w-h)<.01:
            radius=min(w,h)+expand
            a,b=(xy(0,-abs(h-w)),xy(0,abs(h-w))) if h>w else (xy(-abs(w-h),0),xy(abs(w-h),0))
            for layer in layers:
                d=draw[layer]
                d.line([((a[0]-X0)/STEP,(a[1]-Y0)/STEP),((b[0]-X0)/STEP,(b[1]-Y0)/STEP)],fill=1,width=math.ceil(radius*2/STEP))
                ball(d,*a,radius);ball(d,*b,radius)
            continue
        for x,y in [(-w,-h),(w,-h),(w,h),(-w,h)]:
            xx,yy=xy(x,y)
            points.append(((xx-X0)/STEP,(yy-Y0)/STEP))
        for layer in layers:
            d=draw[layer];d.polygon(points,fill=1);d.line(points+[points[0]],fill=1,width=math.ceil(2*expand/STEP))
            for x,y in [(-w,-h),(w,-h),(w,h),(-w,h)]:ball(d,*xy(x,y),expand)
    # Stay inside the existing rounded outline, with copper-to-edge clearance.
    allowed=Image.new('1',(NX,NY),0);d=ImageDraw.Draw(allowed)
    edge=12/STEP;d.rounded_rectangle((edge,edge,NX-1-edge,NY-1-edge),radius=(393.7008-12)/STEP,fill=1)
    a=np.asarray(allowed,dtype=bool)
    permitted=[Image.new('1',(NX,NY),0),Image.new('1',(NX,NY),0)]
    if allow_manual:
        for rid in manual_ids:
            v=P.get(rid)
            if not v or v['head']['type']!='LINE':continue
            p=v['data']
            if p.get('netName','').upper()==net.upper() and p.get('layerId') in [1,2]:
                ImageDraw.Draw(permitted[p['layerId']-1]).line([grid(p['startX'],p['startY']),grid(p['endX'],p['endY'])],fill=1,width=1)
    return np.stack([(np.asarray(im,dtype=bool)&~np.asarray(permitted[l],dtype=bool))|~a for l,im in enumerate(imgs)])

def nearest_existing(net,start):
    candidates=[]
    for v in initial.values():
        p=v['data'];typ=v['head']['type']
        if p.get('netName','').upper()!=net.upper():continue
        if typ=='LINE' and p['layerId'] in (1,2):
            a=p['startX'],p['startY'];b=p['endX'],p['endY'];dx=b[0]-a[0];dy=b[1]-a[1]
            t=max(0,min(1,((start[0]-a[0])*dx+(start[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
            xy=a[0]+t*dx,a[1]+t*dy;candidates.append((*xy,p['layerId']-1))
        elif typ=='VIA' and v['head']['id'] not in removable_ground_vias:candidates.append((p['centerX'],p['centerY'],0));candidates.append((p['centerX'],p['centerY'],1))
    oldcids={k for k,r in initial.items() if r['head']['type']=='COMPONENT'}-{v['pcb'] for v in new_ids.values()}
    for p in all_pads():
        if p['net'].upper()==net.upper() and p['cid'] in oldcids:candidates.append(endpoint(p))
    if not candidates:raise ValueError('No existing endpoint for '+net)
    return sorted(candidates,key=lambda xy:math.dist(start[:2],xy[:2])+ (0 if xy[2]==start[2] else 30))

def route(net,start,end,width=10):
    started=time.time();block=draw_obstacles(net,width/2+CLEAR+MARGIN,True)
    vb=draw_obstacles(net,.6/.0254/2+CLEAR+MARGIN)
    own_vias={grid(v['data']['centerX'],v['data']['centerY']):(v['data']['centerX'],v['data']['centerY']) for v in P.values() if v['head']['type']=='VIA' and v['data']['netName'].upper()==net.upper()}
    sx,sy=grid(*start[:2]);sl=start[2]
    choices=end if isinstance(end[0],(tuple,list)) else [end]
    targets={}
    for choice in choices:
        ex,ey=grid(*choice[:2]);el=choice[2]
        if not block[el,ey,ex]:targets[(el*NY+ey)*NX+ex]=choice
    if block[sl,sy,sx] or not targets:
        (OUT/'routing_debug_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
        raise RuntimeError(f'Blocked endpoint {net}: {start} -> {end}; source blocked={block[sl,sy,sx]}, valid targets={len(targets)}')
    def enc(x,y,l):return (l*NY+y)*NX+x
    def dec(n):return n%NX,(n//NX)%NY,n//(NX*NY)
    target_coords=[dec(t) for t in targets]
    def heuristic(x,y,l):
        return min(max(abs(ex-x),abs(ey-y))+(math.sqrt(2)-1)*min(abs(ex-x),abs(ey-y))+(20 if l!=el else 0) for ex,ey,el in target_coords)
    root=enc(sx,sy,sl)
    queue=[(heuristic(sx,sy,sl),0,root)];distance={root:0};parent={};closed=set()
    steps=[(-1,0,1),(1,0,1),(0,-1,1),(0,1,1),(-1,-1,math.sqrt(2)),(-1,1,math.sqrt(2)),(1,-1,math.sqrt(2)),(1,1,math.sqrt(2))]
    while queue:
        _,cost,node=heapq.heappop(queue)
        if node in closed:continue
        if node in targets:
            goal=node;end=targets[node];ex,ey,el=dec(goal);break
        closed.add(node);x,y,l=dec(node)
        for dx,dy,stepcost in steps:
            xx=x+dx;yy=y+dy
            if not (0<=xx<NX and 0<=yy<NY) or block[l,yy,xx]:continue
            if dx and dy and (block[l,y,xx] or block[l,yy,x]):continue
            target=enc(xx,yy,l);g=cost+stepcost
            if g<distance.get(target,1e30):
                distance[target]=g;parent[target]=node;heapq.heappush(queue,(g+heuristic(xx,yy,l),g,target))
        if (x,y) in own_vias or not vb[0,y,x] and not vb[1,y,x]:
            target=enc(x,y,1-l);g=cost+35
            if g<distance.get(target,1e30):distance[target]=g;parent[target]=node;heapq.heappush(queue,(g+heuristic(x,y,1-l),g,target))
        if len(closed)>1000000:raise RuntimeError('Search limit for '+net)
    else:
        (OUT/'routing_debug_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
        print('FAILED',net,'start',start,'end',end,'explored',len(closed),flush=True)
        raise RuntimeError('Unroutable '+net)
    nodes=[goal]
    while nodes[-1]!=root:nodes.append(parent[nodes[-1]])
    nodes=[dec(n) for n in reversed(nodes)]
    # Collapse collinear segments; keep layer changes as explicit vias.
    routepoints=[nodes[0]]
    for i in range(1,len(nodes)-1):
        a=nodes[i-1];b=nodes[i];c=nodes[i+1]
        if (b[0]-a[0],b[1]-a[1],b[2]-a[2])!=(c[0]-b[0],c[1]-b[1],c[2]-b[2]):routepoints.append(b)
    routepoints.append(nodes[-1]);nvia=0
    line(net,start[:2],coord(sx,sy),sl+1,width)
    for a,b in zip(routepoints,routepoints[1:]):
        if a[2]!=b[2]:
            if a[:2] in own_vias:
                for layer in [1,2]:line(net,coord(a[0],a[1]),own_vias[a[:2]],layer,width)
            else:via(net,coord(a[0],a[1]));nvia+=1
        else:line(net,coord(a[0],a[1]),coord(b[0],b[1]),a[2]+1,width)
    line(net,coord(ex,ey),end[:2],el+1,width)
    entry={'net':net,'start':start,'end':end,'vias':nvia,'length_mm':distance[goal]*STEP*.0254,'seconds':round(time.time()-started,2)}
    route_log.append(entry);print('ROUTED',net,'vias',nvia,'mm',round(entry['length_mm'],2),'sec',entry['seconds'],flush=True)

# Any old power line crossing the new U3/resistor block must be rerouted.
removed=[]
for ident,v in list(P.items()):
    p=v['data']
    if v['head']['type']=='LINE' and p.get('netName','').upper()=='3V3' and p.get('layerId')==1 and min(p['startX'],p['endX'])<1770 and max(p['startX'],p['endX'])>1050 and min(p['startY'],p['endY'])<3595 and max(p['startY'],p['endY'])>3240:
        removed.append(ident);del P[ident]
initial=copy.deepcopy(P)
print('REMOVED POWER SEGMENTS',removed,flush=True)
# Keep the screen-1 supply pour over C5/C6/CN2, freeing space beside U3.
power_pour=P['e475']['data']
for path in power_pour['path']:
    for i,x in enumerate(path):
        if isinstance(x,(int,float)):
            for old_x,new_x in [(1035,920),(1015,900),(1019.7813,904.7813)]:
                if abs(x-old_x)<1e-5:path[i]=new_x;break
g=geometry(docs)
ground_anchors=[v for v in g if v['net']=='GND' and v['info'] in ['pad','track']]
for v in g:
    if v['info']=='via' and v['net']=='GND' and not any(copper_distance(v,a)<(5 if a['info']=='pad' else .15) for a in ground_anchors):removable_ground_vias.add(v['id'])
print('SOFT GROUND STITCHING VIAS',len(removable_ground_vias),flush=True)

fanout={}
for num in [1,2,4,6,8,10,11,13,15,17,19]:
    p=pad('U3',num);xy=(1640 if num==1 else 1590 if p['x']>1400 else 1210,p['y'])
    line(p['net'],(p['x'],p['y']),xy,1,10);via(p['net'],xy)
    fanout[num]=(*xy,1)
    if num not in [10,17]:
        exit_xy=(1800 if p['x']>1400 else 960,p['y'])
        line(p['net'],xy,exit_xy,2,10);fanout[num]=(*exit_xy,1)

output_fanout={}
for i in range(7):
    des='R'+str(21+i);p=pad(des,2);xy=(p['x']-30 if i<4 else 1760,p['y'])
    line(p['net'],(p['x'],p['y']),xy,1,10);via(p['net'],xy)
    output_fanout[des]=(*xy,1)
    exit_xy=(960 if i<4 else 1800,p['y'])
    line(p['net'],xy,exit_xy,2,10);output_fanout[des]=(*exit_xy,1)
port_fanout={}
for des,nums in [('CN2',[9]),('CN3',range(3,10))]:
    for num in nums:
        p=pad(des,num);xy=(p['x'],3830 if num%2 else 3860)
        line(p['net'],(p['x'],p['y']),xy,1,10);via(p['net'],xy)
        port_fanout[des,num]=(*xy,1)
        if des=='CN3':
            exit_xy=(p['x'],3940)
            line(p['net'],xy,exit_xy,2,10);port_fanout[des,num]=(*exit_xy,1)

jobs=[]
outputs=manifest['outputs']
for i,(net,io,inp,out) in enumerate(outputs):
    jobs.append((net+'_BUF',endpoint(pad('U3',out)),endpoint(pad('R'+str(21+i),1)),10))
jobs.append(('EPD2_BUSY_BUF',endpoint(pad('U2',18)),endpoint(pad('R28',1)),10))
for i,(net,io,inp,out) in enumerate(outputs):
    targetdes='CN2' if i==0 else 'CN3';targetpin=9 if i==0 else [3,4,5,6,7,9][i-1]
    jobs.append((net,output_fanout['R'+str(21+i)],port_fanout[targetdes,targetpin],10))
jobs.append(('EPD2_BUSY',endpoint(pad('U2',2)),port_fanout['CN3',8],10))
for des,net,targetdes,targetpin in [('R29','EPD2_CS','CN3',5),('R30','EPD2_RST','CN3',7),('R31','EPD_PWR','CN2',9),('R32','EPD2_PWR','CN3',9),('R33','EPD2_BUSY','CN3',8)]:jobs.append((net,endpoint(pad(des,1)),port_fanout[targetdes,targetpin],10))

first_busy=next(job for job in jobs if job[0]=='EPD2_BUSY')
for job in list(jobs):
    if job[0].endswith('_BUF'):
        jobs.remove(job)
        net,a,b,w=job
        assert a[2]==b[2]
        line(net,a[:2],b[:2],a[2]+1,w)
        route_log.append({'net':net,'start':a,'end':b,'vias':0,'length_mm':math.dist(a[:2],b[:2])*.0254,'method':'direct local connection'})
manual_ids=set(P)-set(initial)
jobs.remove(first_busy);route(*first_busy)
for net,a,b,w in jobs:route(net,a,b,w)
# GPIO/OE tap existing connected traces, preserving the original J4 extension wiring.
for net,io,inp,out in outputs:
    start=fanout[inp];end=nearest_existing('USER_3V3_IO'+str(io),start)[:24]
    route('USER_3V3_IO'+str(io),start,end)
route('USER_3V3_IO17',endpoint(pad('R28',2)),nearest_existing('USER_3V3_IO17',endpoint(pad('R28',2)))[:24])
route('BUF_nOE',fanout[1],nearest_existing('BUF_nOE',fanout[1])[:24])
route('BUF_nOE',fanout[19],fanout[1])

# Explicit supply trunks, capacitor connections, and grounds.
route('3V3',endpoint(pad('C5',2)),endpoint(pad('P1',1)),20)
route('3V3',endpoint(pad('C9',2)),endpoint(pad('U3',20)),10)
route('3V3',endpoint(pad('C10',2)),endpoint(pad('CN3',1)),20)
for des,num in [('C9',2),('C10',2),('R29',2),('R30',2)]:
    start=endpoint(pad(des,num));candidates=nearest_existing('3V3',start)
    route('3V3',start,candidates[:40],20)
for des,num in [('U3',10),('U3',17),('CN3',2),('CN3',10),('CN3',11),('C9',1),('C10',1),('R31',2),('R32',2),('R33',2)]:
    start=fanout[num] if des=='U3' else endpoint(pad(des,num));route('GND',start,nearest_existing('GND',start)[:24],10)

new_copper=[v for v in geometry(docs,read_project(SOURCE)) if v['changed'] and v['net']!='GND']
removed_stitches=[]
for v in g:
    if v['id'] in removable_ground_vias and any(set(v['layers'])&set(a['layers']) and copper_distance(v,a)<CLEAR+.1 for a in new_copper):
        P.pop(v['id'],None);removed_stitches.append(v['id'])
print('REMOVED INTERFERING GROUND STITCHING VIAS',len(removed_stitches),flush=True)
(OUT/'routed_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
(OUT/'布线记录.json').write_text(json.dumps({'removed_power_segments':removed,'removed_ground_stitches':removed_stitches,'routes':route_log},ensure_ascii=False,indent=2),encoding='utf8')
render(docs,'修改后PCB_静态预览.png')
print('COMPLETE',len(route_log),'routes',flush=True)
