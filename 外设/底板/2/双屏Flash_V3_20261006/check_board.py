from board_tools import *
import itertools

def pseg(p,a,b):
    dx=b[0]-a[0];dy=b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy or 1)))
    return math.dist(p,(a[0]+t*dx,a[1]+t*dy))

def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def sdist(a,b,c,d):
    if max(min(a[0],b[0]),min(c[0],d[0]))<=min(max(a[0],b[0]),max(c[0],d[0]))+1e-7 and max(min(a[1],b[1]),min(c[1],d[1]))<=min(max(a[1],b[1]),max(c[1],d[1]))+1e-7:
        if cross(a,b,c)*cross(a,b,d)<=0 and cross(c,d,a)*cross(c,d,b)<=0:return 0
    return min(pseg(a,c,d),pseg(b,c,d),pseg(c,a,b),pseg(d,a,b))

def inside(p,poly):
    signs=[cross(a,b,p) for a,b in zip(poly,poly[1:]+poly[:1])]
    return all(v>=-1e-7 for v in signs) or all(v<=1e-7 for v in signs)

def segpoly(a,b,poly):
    if inside(a,poly) or inside(b,poly):return 0
    return min(sdist(a,b,c,d) for c,d in zip(poly,poly[1:]+poly[:1]))

def distance(a,b):
    if a['kind']=='capsule' and b['kind']=='capsule':return sdist(*a['points'],*b['points'])-a['radius']-b['radius']
    if a['kind']=='capsule':return segpoly(*a['points'],b['points'])-a['radius']
    if b['kind']=='capsule':return segpoly(*b['points'],a['points'])-b['radius']
    if inside(a['points'][0],b['points']) or inside(b['points'][0],a['points']):return 0
    return min(sdist(x,y,u,v) for x,y in zip(a['points'],a['points'][1:]+a['points'][:1]) for u,v in zip(b['points'],b['points'][1:]+b['points'][:1]))

def geometry(docs,source=None):
    P=docs[PCB]['records'];old=source[PCB]['records'] if source else {}
    oldpads={(p['des'],p['num']):p for p in pads(source)} if source else {}
    result=[]
    def add(ident,net,layers,kind,points,radius,changed,info):
        xs=[p[0] for p in points];ys=[p[1] for p in points]
        result.append({'id':ident,'net':net.upper(),'layers':layers,'kind':kind,'points':points,'radius':radius,'changed':changed,'info':info,'bbox':(min(xs)-radius,min(ys)-radius,max(xs)+radius,max(ys)+radius)})
    for rid,v in P.items():
        p=v['data'];typ=v['head']['type'];changed=rid not in old or p!=old[rid]['data']
        if typ=='LINE' and p.get('layerId') in (1,2):add(rid,p.get('netName',''),[p['layerId']], 'capsule',[(p['startX'],p['startY']),(p['endX'],p['endY'])],p['width']/2,changed,'track')
        if typ=='VIA':add(rid,p['netName'],[1,2],'capsule',[(p['centerX'],p['centerY'])]*2,p['viaDiameter']/2,changed,'via')
    for p in pads(docs):
        if p['layerId'] not in (1,2,12):continue
        op=oldpads.get((p['des'],p['num']))
        changed=op is None or any(p[k]!=op[k] for k in ['x','y','angle','defaultPad','hole','plated','net','layerId'])
        f=p['defaultPad'];w=f['width']/2;h=f['height']/2;ang=math.radians(p['angle'])
        def xy(x,y):return (p['x']+x*math.cos(ang)-y*math.sin(ang),p['y']+x*math.sin(ang)+y*math.cos(ang))
        layers=[1,2] if p['layerId']==12 else [p['layerId']]
        if not p['plated']:
            kind='capsule';points=[xy(0,0)]*2;radius=max(p['hole']['width'],p['hole']['height'])/2;net='HOLE_'+p['des']
        elif f['padType']=='OVAL' or f['padType']=='ELLIPSE' and abs(w-h)<.01:
            kind='capsule';radius=min(w,h);points=[xy(0,-abs(h-w)),xy(0,abs(h-w))] if h>w else [xy(-abs(w-h),0),xy(abs(w-h),0)];net=p['net']
        else:kind='polygon';radius=0;points=[xy(x,y) for x,y in [(-w,-h),(w,-h),(w,h),(-w,h)]];net=p['net']
        add(p['des']+'.'+p['num'],net,layers,kind,points,radius,changed,'pad' if p['plated'] else 'NPTH')
    return result

def nearby(g,clear=12):
    buckets=collections.defaultdict(list);seen=set()
    for i,a in enumerate(g):
        x0,y0,x1,y1=a['bbox']
        for l in a['layers']:
            for x in range(math.floor((x0-clear)/100),math.floor((x1+clear)/100)+1):
                for y in range(math.floor((y0-clear)/100),math.floor((y1+clear)/100)+1):buckets[l,x,y].append(i)
    for cell in buckets.values():
        for i,j in itertools.combinations(cell,2):
            if i==j:continue
            if i>j:i,j=j,i
            if (i,j) in seen:continue
            seen.add((i,j));a,b=g[i],g[j]
            ax,ay,bx,by=a['bbox'];cx,cy,dx,dy=b['bbox']
            if bx+clear<cx or dx+clear<ax or by+clear<cy or dy+clear<ay:continue
            yield i,j

def audit(docs):
    source=read_project(SOURCE);g=geometry(docs,source);violations=[];oldviolations=[]
    roots=list(range(len(g)))
    def root(i):
        while roots[i]!=i:roots[i]=roots[roots[i]];i=roots[i]
        return i
    for i,j in nearby(g):
        a,b=g[i],g[j];d=distance(a,b)
        if a['net'] and a['net']==b['net']:
            if d<.15:roots[root(i)]=root(j)
        elif d<7.874-.05:
            item={'a':a['id'],'a_net':a['net'],'b':b['id'],'b_net':b['net'],'gap_mm':round(d*.0254,5),'type':'short' if d<-.01 else 'clearance','layers':sorted(set(a['layers'])&set(b['layers']))}
            (violations if a['changed'] or b['changed'] else oldviolations).append(item)
    nets=collections.defaultdict(lambda:collections.defaultdict(list))
    for i,a in enumerate(g):
        if a['info']=='pad' and a['net']:nets[a['net']][root(i)].append(a['id'])
    disconnected={k:list(v.values()) for k,v in nets.items() if len(v)>1 and k!='GND'}
    report={'scope':'Layer-aware analytical checks, excludes poured copper, silk and manufacturer rules. Native DRC still required.','new_or_changed_clearance_issues':violations,'unchanged_legacy_clearance_issues':oldviolations,'pad_connectivity_without_pours':disconnected}
    (OUT/'静态检查结果.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print('NEW ISSUES',len(violations),'OLD ISSUES',len(oldviolations),'DISCONNECTED',len(disconnected))
    for v in violations[:25]:print(v)
    for net,parts in disconnected.items():print('DISCONNECTED',net,parts)
    return report

if __name__=='__main__':
    import sys
    path=OUT/(sys.argv[1] if len(sys.argv)>1 else 'routed_state.json')
    audit(json.loads(path.read_text(encoding='utf8')))
