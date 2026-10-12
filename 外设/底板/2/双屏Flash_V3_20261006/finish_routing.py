from pathlib import Path
exec((Path(__file__).parent/'route_board.py').read_text(encoding='utf8').split('# Any old power')[0])
docs=json.loads((OUT/'routing_debug_state.json').read_text(encoding='utf8'));P=docs[PCB]['records']
initial=copy.deepcopy(json.loads((OUT/'modified_state.json').read_text(encoding='utf8'))[PCB]['records'])
for key in ['e510','e511']:initial.pop(key,None)
manual_ids=set(P)-set(initial)
g=geometry(docs)
anchors=[v for v in g if v['net']=='GND' and v['info'] in ['pad','track']]
removable_ground_vias={v['id'] for v in g if v['info']=='via' and v['net']=='GND' and not any(copper_distance(v,a)<(5 if a['info']=='pad' else .15) for a in anchors)}
# U3 grounds already have local vias. Ground planes will supply the return;
# avoid long ground tracks that degrade decoupling and congest signal fanout.
ground_fanpoints=[(1590,pad('U3',10)['y']),(1210,pad('U3',17)['y'])]
for ident,v in list(P.items()):
    p=v['data']
    if ident in initial or p.get('netName','').upper()!='GND':continue
    if v['head']['type']=='VIA':
        if not any(math.dist((p['centerX'],p['centerY']),xy)<.1 for xy in ground_fanpoints):del P[ident]
    elif v['head']['type']=='LINE':
        if not any(math.dist((p['startX'],p['startY']),xy)<.1 or math.dist((p['endX'],p['endY']),xy)<.1 for xy in ground_fanpoints):del P[ident]

# Move the BUSY pulldown into the open space ahead of the connector.
rcid,rc,ra=components(P)['R33'];old_busy=endpoint(pad('R33',1));dy=3730-rc['y'];rc['y']=3730
for v in P.values():
    if v['head']['type']=='ATTR' and v['data'].get('parentId')==rcid and v['data'].get('y') is not None:v['data']['y']+=dy
route('EPD2_BUSY',endpoint(pad('R33',1)),old_busy,10)

def local_ground(des,num):
    p=pad(des,num);start=(p['x'],p['y']);gg=geometry(docs)
    ownpad=next(a for a in gg if a['id']==des+'.'+str(num))
    candidates=[(v['data']['centerX'],v['data']['centerY']) for v in P.values() if v['head']['type']=='VIA' and v['data']['netName'].upper()=='GND' and math.dist(start,(v['data']['centerX'],v['data']['centerY']))<120]
    for radius in [40,50,60,80,100]:
        candidates.extend((start[0]+radius*math.cos(i*math.pi/8),start[1]+radius*math.sin(i*math.pi/8)) for i in range(16))
    for xy in candidates:
        if not (-155<xy[0]<3750 and 59<xy[1]<3964):continue
        vp={'kind':'capsule','points':[xy,xy],'radius':.6/.0254/2,'layers':[1,2]}
        lp={'kind':'capsule','points':[start,xy],'radius':5,'layers':[p['layerId']]}
        hole={'kind':'capsule','points':[xy,xy],'radius':.3/.0254/2}
        if copper_distance(hole,ownpad)<.1:continue
        if any(a['net']!='GND' and (set(a['layers'])&set(vp['layers']) and copper_distance(vp,a)<CLEAR+.1 or set(a['layers'])&set(lp['layers']) and copper_distance(lp,a)<CLEAR+.1) for a in gg):continue
        existing=next((v for v in P.values() if v['head']['type']=='VIA' and math.dist(xy,(v['data']['centerX'],v['data']['centerY']))<.1),None)
        if existing is None:
            if any(v['head']['type']=='VIA' and math.dist(xy,(v['data']['centerX'],v['data']['centerY']))<22 for v in P.values()):continue
            via('GND',xy)
        line('GND',start,xy,p['layerId'],10);print('LOCAL GROUND',des,num,xy);return
    raise RuntimeError('No local ground via position for '+des)

for des,num in [('CN3',2),('C9',1),('C10',1),('R31',2),('R32',2),('R33',2)]:local_ground(des,num)
new_copper=[v for v in geometry(docs,read_project(SOURCE)) if v['changed'] and v['net']!='GND']
removed=[]
for v in g:
    if v['id'] in removable_ground_vias and any(set(v['layers'])&set(a['layers']) and copper_distance(v,a)<CLEAR+.1 for a in new_copper):P.pop(v['id'],None);removed.append(v['id'])
(OUT/'routed_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
(OUT/'布线记录.json').write_text(json.dumps({'resumed_from':'routing_debug_state.json','remaining_routes':route_log,'removed_ground_stitches':removed},ensure_ascii=False,indent=2),encoding='utf8')
render(docs,'修改后PCB_静态预览.png')
print('FINISHED',len(removed),'interfering ground stitches removed')
