import base64, collections, copy, gzip, json, math, sqlite3, uuid
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
SOURCE = OUT / '原始备份_底板(修改版).eprj2'
TARGET = OUT / '底板_双屏Flash_V3.eprj2'
SCH = '121c1629dfab46b4'
PCB = '4f72a239a6e0e4ad56712a4bf96f8464'

def read_project(path):
    con = sqlite3.connect(Path(path).as_uri()+'?mode=ro', uri=True)
    con.row_factory=sqlite3.Row
    keys={}
    for (table,) in con.execute("SELECT name FROM sqlite_master WHERE name LIKE 'project_history_%'"):
        keys.update({r['uuid']:r['key'] for r in con.execute('SELECT uuid,key FROM "'+table+'"')})
    docs={}; current=None
    for row in con.execute('SELECT * FROM history_data ORDER BY id'):
        raw=AESGCM(bytes.fromhex(keys[row['history_uuid']])).decrypt(bytes.fromhex(row['uuid'].split('-')[0]),base64.b64decode(row['dataStr']),None)
        for line in gzip.decompress(raw).decode('utf8').splitlines():
            if not line:continue
            head,_,payload=line.rstrip('|').partition('||')
            head=json.loads(head); payload=json.loads(payload) if payload else None
            if head['type']=='DOCHEAD':
                current=payload['uuid']
                docs.setdefault(current,{'head':payload,'records':{}})['head']=payload
            elif head['type']!='EDIT_HEAD' and current is not None:
                rid=head.get('id',json.dumps(head,sort_keys=True))
                if payload is None:docs[current]['records'].pop(rid,None)
                else:docs[current]['records'][rid]={'head':head,'data':payload}
    con.close()
    return docs

def attrs(records):
    result=collections.defaultdict(dict)
    for record in records.values():
        if record['head']['type']=='ATTR':
            p=record['data'];result[p.get('parentId','')][p['key']]=p['value']
    return result

def components(records):
    a=attrs(records)
    return {a[k]['Designator']:(k,r['data'],a[k]) for k,r in records.items() if r['head']['type']=='COMPONENT' and a[k].get('Designator')}

def pins(docs,symbol):
    r=docs[symbol]['records']; a=attrs(r)
    return {a[k]['Pin Number']:(k,v['data'],a[k]) for k,v in r.items() if v['head']['type']=='PIN'}

def pad_map(records):
    result={}
    for r in records.values():
        if r['head']['type']=='PAD_NET':
            a=json.loads(r['head']['id'])
            if a[2]:result[a[1],str(a[2])]=r['data']['padNet']
    return result

def transform(x,y,c,origin=(0,0)):
    x-=origin[0];y-=origin[1]
    if c.get('layerId')==2:y=-y
    angle=math.radians(c.get('angle',c.get('rotation',0)))
    return (c['x']+x*math.cos(angle)-y*math.sin(angle),c['y']+x*math.sin(angle)+y*math.cos(angle))

def pads(docs):
    r=docs[PCB]['records']; pm=pad_map(r); result=[]
    for des,(cid,c,a) in components(r).items():
        f=docs[a['Footprint']]['records'];o=f.get('CANVAS',{}).get('data',{})
        origin=o.get('originX',0),o.get('originY',0)
        for pid,v in f.items():
            if v['head']['type']!='PAD':continue
            p=copy.deepcopy(v['data']);p['x'],p['y']=transform(p['centerX'],p['centerY'],c,origin)
            p['angle']=p.get('padAngle',0)+c.get('angle',0)
            if c.get('layerId')==2:p['angle']=c.get('angle',0)-p.get('padAngle',0)
            p['layerId']=p['layerId'] if p['layerId'] not in (1,2) else (3-p['layerId'] if c.get('layerId')==2 else p['layerId'])
            p.update(des=des,cid=cid,pid=pid,net=pm.get((cid,str(p['num'])),''))
            result.append(p)
    return result

def render(docs,name):
    r=docs[PCB]['records'];scale=.46; xmin=-220;ymin=-10;xmax=3850;ymax=4050
    im=Image.new('RGB',(int((xmax-xmin)*scale),int((ymax-ymin)*scale)),(18,24,30));d=ImageDraw.Draw(im)
    def pt(x,y):return ((x-xmin)*scale,(ymax-y)*scale)
    for layer,color in [(2,(50,75,170)),(1,(210,62,56))]:
        for v in r.values():
            p=v['data']
            if v['head']['type']=='LINE' and p.get('layerId')==layer:
                d.line([pt(p['startX'],p['startY']),pt(p['endX'],p['endY'])],fill=color,width=max(1,round(p['width']*scale)))
    for v in r.values():
        p=v['data']
        if v['head']['type']=='VIA':
            x,y=pt(p['centerX'],p['centerY']);rad=p['viaDiameter']*scale/2
            d.ellipse((x-rad,y-rad,x+rad,y+rad),fill=(75,80,90))
    for p in pads(docs):
        x,y=pt(p['x'],p['y']);f=p['defaultPad']; w=f['width']*scale;h=f['height']*scale
        if not p['plated']:
            rad=p['hole']['width']*scale/2;d.ellipse((x-rad,y-rad,x+rad,y+rad),fill=(18,24,30),outline=(205,210,215),width=2)
            continue
        if f['padType']=='ELLIPSE' and abs(w-h)<.01:
            d.ellipse((x-w/2,y-h/2,x+w/2,y+h/2),fill=(193,172,84) if p['layerId']!=2 else (77,129,192))
            if p['hole']['width']:
                rad=p['hole']['width']*scale/2;d.ellipse((x-rad,y-rad,x+rad,y+rad),fill=(18,24,30))
            continue
        ang=math.radians(p['angle']); points=[]
        for xx,yy in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]:
            points.append((x+xx*math.cos(ang)+yy*math.sin(ang),y+xx*math.sin(ang)-yy*math.cos(ang)))
        d.polygon(points,fill=(193,172,84) if p['layerId']!=2 else (77,129,192))
    font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',18)
    for des,(_,c,a) in components(r).items():
        x,y=pt(c['x'],c['y']);d.text((x+10,y+5),des,font=font,fill='white')
    d.rounded_rectangle([pt(-170.015,3980.915),pt(3766.9929,43.9071)],radius=393.7008*scale,outline=(70,200,150),width=3)
    d.text((10,3),'Top: red | Bottom: blue | White circles: NPTH | Copper fills omitted | Static preview only',font=font,fill=(225,225,225))
    im.save(OUT/name)

if __name__=='__main__':
    docs=read_project(SOURCE)
    (OUT/'source_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
    render(docs,'原版PCB_静态预览.png')
    print('read',len(docs),'documents; physical parts',len(components(docs[PCB]['records'])))
