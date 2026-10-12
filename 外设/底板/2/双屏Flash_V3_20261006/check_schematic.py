from board_tools import *
from check_board import pseg

def check(docs):
    r=docs[SCH]['records'];a=attrs(r);parents={};labels=collections.defaultdict(set);segments=[];pin_nodes={};positions={}
    def root(x):
        parents.setdefault(x,x)
        while parents[x]!=x:parents[x]=parents[parents[x]];x=parents[x]
        return x
    def union(x,y):parents[root(x)]=root(y)
    for rid,v in r.items():
        if v['head']['type']=='WIRE':root(rid)
        elif v['head']['type']=='LINE':
            p=v['data'];group=p.get('lineGroup')
            if group and group in r and r[group]['head']['type']=='WIRE':
                root(group);segments.append((group,(p['startX'],p['startY']),(p['endX'],p['endY'])))
    for i,(g,x,y) in enumerate(segments):
        for h,u,v in segments[i+1:]:
            if g!=h and min(pseg(x,u,v),pseg(y,u,v),pseg(u,x,y),pseg(v,x,y))<1e-4:union(g,h)
    for rid,v in r.items():
        if v['head']['type']!='COMPONENT' or not a[rid].get('Symbol'):continue
        c=v['data'];sym=a[rid]['Symbol'];des=a[rid].get('Designator',rid)
        for num,(pid,p,pa) in pins(docs,sym).items():
            node=rid+'-'+pid;pos=transform(p['x'],p['y'],c);root(node)
            pin_nodes[des,str(num)]=node;positions[node]=pos
            for g,x,y in segments:
                if pseg(pos,x,y)<1e-4:union(node,g)
            if a[rid].get('Global Net Name'):labels[node].add(a[rid]['Global Net Name'].upper())
    for v in r.values():
        if v['head']['type']=='ATTR' and v['data']['key']=='NET':
            p=v['data'];labels[p['parentId']].add(p['value'].upper())
    nets=collections.defaultdict(set)
    for node,values in labels.items():nets[root(node)].update(values)
    collisions=[sorted(values) for values in nets.values() if len(values)>1]
    pm=pad_map(docs[PCB]['records']);pcbparts=components(docs[PCB]['records']);schparts=components(r)
    errors=[];mapping=[]
    for des,(cid,c,att) in pcbparts.items():
        if des not in schparts:errors.append({'component':des,'issue':'Missing schematic component'});continue
        for p in pads(docs):
            if p['des']!=des:continue
            node=pin_nodes.get((des,p['num']));values=nets.get(root(node),set()) if node else set()
            assigned=p['net'].upper()
            mapping.append({'component':des,'pin':p['num'],'pcb':assigned,'schematic':sorted(values)})
            if assigned and assigned not in values:errors.append(mapping[-1])
            if not assigned and values:errors.append(mapping[-1])
    report={'conflicting_net_labels':collisions,'schematic_pcb_mismatches':errors,'pins':mapping}
    (OUT/'原理图一致性检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print('Conflicting labels',len(collisions),'PCB mismatches',len(errors))
    for value in collisions:print('COLLISION',value)
    for value in errors:print('MISMATCH',value)
    return report

if __name__=='__main__':
    import sys
    check(json.loads((OUT/(sys.argv[1] if len(sys.argv)>1 else 'modified_state.json')).read_text(encoding='utf8')))
