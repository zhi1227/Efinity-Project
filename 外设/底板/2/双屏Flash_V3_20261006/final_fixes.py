from board_tools import *
from check_board import geometry,distance,audit
d=json.loads((OUT/'routed_state.json').read_text(encoding='utf8'));P=d[PCB]['records']

# The narrowed top power pour no longer uses these two standalone power vias.
for ident in ['e486','e489']:
    v=P[ident];assert v['head']['type']=='VIA' and v['data']['netName']=='3V3'
    x,y=v['data']['centerX'],v['data']['centerY']
    assert not any(r['head']['type']=='LINE' and r['data'].get('layerId')==2 and r['data'].get('netName','').upper()=='3V3' and (math.dist((x,y),(r['data']['startX'],r['data']['startY']))<15 or math.dist((x,y),(r['data']['endX'],r['data']['endY']))<15) for r in P.values())
    del P[ident]

g=geometry(d);anchors=[v for v in g if v['net']=='GND' and v['info'] in ['pad','track']]
newg=geometry(d,read_project(SOURCE));others=[a for a in newg if a['changed'] and a['net']!='GND']
removed=[]
for v in g:
    if v['info']=='via' and v['net']=='GND' and not any(distance(v,a)<(5 if a['info']=='pad' else .15) for a in anchors) and any(set(v['layers'])&set(a['layers']) and distance(v,a)<8.4 for a in others):
        P.pop(v['id'],None);removed.append(v['id'])

# Correct the inherited suppressed paste apertures on 0805 capacitors as well.
for v in d['c5555808f571eea1']['records'].values():
    if v['head']['type']=='PAD':v['data'].update(topPasteExpansion=0,bottomPasteExpansion=0)

report=audit(d)
for issue in report['new_or_changed_clearance_issues']:
    if issue['a']=='e503' and issue['b_net']=='EPD_PWR' and issue['type']=='clearance':
        rec=P[issue['b']];p=rec['data']
        if rec['head']['type']=='VIA':p['centerX']+=1 if p['centerX']>743.425 else -1
        else:
            shift=1 if (p['startX']+p['endX'])/2>743.425 else -1
            p['startX']+=shift;p['endX']+=shift

(OUT/'routed_state.json').write_text(json.dumps(d,ensure_ascii=False),encoding='utf8')
render(d,'修改后PCB_静态预览.png')
print('REMOVED ADDITIONAL GROUND STITCHES',removed)
audit(d)
