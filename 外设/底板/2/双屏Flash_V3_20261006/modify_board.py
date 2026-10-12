from board_tools import *
import time

docs=read_project(SOURCE)
S=docs[SCH]['records'];P=docs[PCB]['records']
new_ids={}; changes=[]

def add(records,typ,payload,rid=None):
    rid=rid or uuid.uuid4().hex[:16]
    payload=copy.deepcopy(payload)
    if 'zIndex' in payload:payload['zIndex']=max((v['data'].get('zIndex',0) or 0 for v in records.values()),default=0)+1
    records[rid]={'head':{'type':typ,'id':rid},'data':payload}
    return rid

def attr(records,cid,key,value):
    for v in records.values():
        if v['head']['type']=='ATTR' and v['data'].get('parentId')==cid and v['data']['key']==key:
            v['data']['value']=value;return
    template=next(v['data'] for v in records.values() if v['head']['type']=='ATTR' and v['data'].get('key')=='Device')
    p=copy.deepcopy(template);p.update(parentId=cid,key=key,value=value,keyVisible=False,valueVisible=False,x=None,y=None)
    add(records,'ATTR',p)

def clone_component(records,template,des,x,y,angle=None):
    old=records[template]['data'];n=copy.deepcopy(old)
    n.update(x=x,y=y,locked=False)
    if angle is not None:n['angle' if records is P else 'rotation']=angle
    cid=add(records,'COMPONENT',n)
    for v in list(records.values()):
        p=v['data']
        if v['head']['type']=='ATTR' and p.get('parentId')==template:
            p=copy.deepcopy(p);p['parentId']=cid
            if p.get('x') is not None:p['x']+=x-old['x']
            if p.get('y') is not None:p['y']+=y-old['y']
            add(records,'ATTR',p)
    attr(records,cid,'Designator',des)
    uid='v3_'+des
    attr(records,cid,'Unique ID',uid)
    if records is P:
        n=records[cid]['data'];n['layerId']=1;n['attrs'].update({'Unique ID':uid,'Channel ID':'$1'+new_ids[des]['sch']})
    new_ids.setdefault(des,{})['pcb' if records is P else 'sch']=cid
    return cid

def device_copy(template,title,mpn,code,value,extra=None):
    did=uuid.uuid4().hex[:16];doc=copy.deepcopy(docs[template]);doc['head']['uuid']=did
    m=doc['records']['META']['data'];m.update(title=title,source=None)
    a=m['attributes'];a.update({'Manufacturer':'UNI-ROYAL' if title.startswith('0603WAF') or title.startswith('0805W8F') else 'YAGEO','Manufacturer Part':mpn,'Supplier Part':code,'Value':value,'LCSC Part Name':title,'Name':'={Value}','Description':value+' '+a.get('Supplier Footprint',''),'Datasheet':'https://www.lcsc.com/product-detail/'+code+'.html'})
    if extra:a.update(extra)
    docs[did]=doc
    return did

specs={
 '20R':device_copy('23bb92b3ccbbad35','0603WAF200JT5E','0603WAF200JT5E','C22950','20R',{'Resistance':'20Ω','Tolerance':'±1%'}),
 '5.1K':device_copy('23bb92b3ccbbad35','0603WAF5101T5E','0603WAF5101T5E','C23186','5.1K',{'Resistance':'5.1kΩ','Tolerance':'±1%'}),
 '1K':device_copy('d4b3a0c7db06b48c','0603WAF1001T5E','0603WAF1001T5E','C21190','1K',{'Resistance':'1kΩ','Tolerance':'±1%'}),
 '100K_0805':device_copy('a5c2f0d76dda8c25','0805W8F1003T5E','0805W8F1003T5E','C149504','100K',{'Resistance':'100kΩ','Tolerance':'±1%'}),
 '100K_0603':device_copy('23bb92b3ccbbad35','0603WAF1003T5E','0603WAF1003T5E','C25803','100K',{'Resistance':'100kΩ','Tolerance':'±1%'}),
 '100nF':device_copy('9893c66ea841dd25','CC0603KRX7R9BB104','CC0603KRX7R9BB104','C14663','100nF',{'Capacitance':'100nF','Voltage Rating':'50V','Temperature Coefficient':'X7R','Tolerance':'±10%'}),
}

def set_part(records,des,did,value=None):
    cid,_,a=components(records)[des];meta=docs[did]['records']['META']['data']; da=meta['attributes']
    attr(records,cid,'Device',did)
    for key in ['Supplier Part','Manufacturer','Manufacturer Part']:
        attr(records,cid,key,da[key])
    if value:attr(records,cid,'Value',value)
    if records is P:
        records[cid]['data']['attrs'].update({key:da[key] for key in ['Supplier Part','Manufacturer','Manufacturer Part']})
        if value:records[cid]['data']['attrs']['Value']=value

for records in (S,P):
    for des in ['R3','R4','R5','R6','R7','R8','R9','R10','R12','R13']:set_part(records,des,specs['20R'],'20R')
    set_part(records,'R2',specs['5.1K'],'5.1K')
    for des in ['R1','R20']:set_part(records,des,specs['1K'],'1K')
    for des in ['R14','R15','R17','R18','R19']:set_part(records,des,specs['100K_0805'],'100K')
    for des in ['C1','C2','C3','C5','C7']:set_part(records,des,specs['100nF'],'100nF')
changes.append('修正原有电阻电容的真实器件型号及采购编号，保留符号和焊盘连接。')

# CN2: keep positions of all eight signal anchors/pads exactly; assign pin 9 to PWR.
scn=components(S)['CN2'][0];pcn=components(P)['CN2'][0]
S[scn]['data']['partId']='BX-GH1.25-9PWT.1';S[scn]['data']['y']-=5
for records,cid in [(S,scn),(P,pcn)]:
    attr(records,cid,'Device','ad525a962f6a08a1');attr(records,cid,'Footprint','438a56b3bcf2b8a5')
    if records is S:attr(records,cid,'Symbol','61928621969d5233')
    attr(records,cid,'Supplier Part','C18077725');attr(records,cid,'Manufacturer Part','BX-GH1.25-9PWT')
P[pcn]['data']['x']-=24.62;P[pcn]['data']['y']-=.98
for v in S.values():
    p=v['data']
    if v['head']['type']=='ATTR' and p.get('parentId')==scn and p.get('y') is not None:p['y']-=5
    if v['head']['type']=='LINE' and p.get('lineGroup')=='w272':p['startY']-=10;p['endY']-=10
S['e156']['data']['y']-=10
for v in S.values():
    if v['head']['type']=='ATTR' and v['data'].get('parentId')=='e156' and v['data'].get('y') is not None:v['data']['y']-=10
for rid,v in list(P.items()):
    if v['head']['type']=='PAD_NET' and json.loads(rid)[1]==pcn:del P[rid]

def set_padnet(cid,num,net):
    fp=attrs(P)[cid]['Footprint']; pad=next((k for k,r in docs[fp]['records'].items() if r['head']['type']=='PAD' and str(r['data']['num'])==str(num)),None)
    if pad is None:raise ValueError((cid,num))
    for rid,v in list(P.items()):
        if v['head']['type']=='PAD_NET':
            a=json.loads(rid)
            if a[1]==cid and str(a[2])==str(num):del P[rid]
    rid=json.dumps(['PAD_NET',cid,str(num),pad],separators=(',',':'))
    add(P,'PAD_NET',{'partitionId':'','padNet':net,'padLen':0},rid)

cn1nets={1:'3V3',2:'GND',3:'EPD_DIN',4:'EPD_CLK',5:'EPD_CS',6:'EPD_DC',7:'EPD_RST',8:'EPD_BUSY',9:'EPD_PWR',10:'GND',11:'GND'}
for n,net in cn1nets.items():set_padnet(pcn,n,net)

def sch_point(cid,num):
    a=attrs(S)[cid];pin=pins(docs,a['Symbol'])[str(num)][1]
    return transform(pin['x'],pin['y'],S[cid]['data'])

def sch_label(cid,num,net,length=65):
    x,y=sch_point(cid,num);p=pins(docs,attrs(S)[cid]['Symbol'])[str(num)][1]
    rotation=(p['rotation']+S[cid]['data'].get('rotation',0))%360
    # Pin rotation points towards the body. Extend wire in the opposite direction.
    th=math.radians(rotation);xx=x-math.cos(th)*length;yy=y-math.sin(th)*length
    wid=add(S,'WIRE',{'groupId':'','locked':False,'zIndex':0})
    add(S,'LINE',{'lineGroup':wid,'startX':x,'startY':y,'endX':xx,'endY':yy,'strokeColor':None,'strokeStyle':'SOLID','fillColor':None,'strokeWidth':1,'fillStyle':'NONE'})
    a=copy.deepcopy(S['e1245']['data']);a.update(parentId=wid,value=net,x=min(x,xx),y=min(y,yy)-1,fontSize=7,rotation=0)
    add(S,'ATTR',a)

sch_label(scn,9,'EPD_PWR',77)
# Reclaim U2 A1/Y1, removing the ground branch and the old no-connect flag.
S.pop('a11c20eae0961b0e');S.pop('w112',None)
for rid,r in list(S.items()):
    p=r['data']
    if r['head']['type']=='ATTR' and (p.get('parentId')=='w112' or p.get('parentId')=='e41-e74' and p.get('key')=='NO_CONNECT'):del S[rid]
sch_label('e41',2,'EPD2_BUSY',50);sch_label('e41',18,'EPD2_BUSY_BUF',65)
u2=components(P)['U2'][0]
set_padnet(u2,2,'EPD2_BUSY');set_padnet(u2,18,'EPD2_BUSY_BUF')

clone_component(S,'e40','U3',1300,-960)
clone_component(S,scn,'CN3',1550,-760)
clone_component(P,'e22','U3',1400,3450,90)
clone_component(P,pcn,'CN3',1420,3844.02,180)

outputs=[('EPD_PWR',22,2,18),('EPD2_DIN',8,4,16),('EPD2_CLK',9,6,14),('EPD2_CS',11,8,12),('EPD2_DC',12,11,9),('EPD2_RST',13,13,7),('EPD2_PWR',15,15,5)]
u3nets={1:'BUF_nOE',19:'BUF_nOE',20:'3V3',10:'GND',17:'GND',3:''}
for net,io,inp,out in outputs:u3nets[inp]='User_3V3_IO'+str(io);u3nets[out]=net+'_BUF'
for num,net in u3nets.items():
    if net:sch_label(new_ids['U3']['sch'],num,net,85);set_padnet(new_ids['U3']['pcb'],num,net)
    else:
        x,y=sch_point(new_ids['U3']['sch'],num);pid=pins(docs,attrs(S)[new_ids['U3']['sch']]['Symbol'])[str(num)][0]
        a=copy.deepcopy(S['e1400']['data']);a.update(parentId=new_ids['U3']['sch']+'-'+pid,x=x,y=y);add(S,'ATTR',a);set_padnet(new_ids['U3']['pcb'],num,'')

cn2nets={1:'3V3',2:'GND',3:'EPD2_DIN',4:'EPD2_CLK',5:'EPD2_CS',6:'EPD2_DC',7:'EPD2_RST',8:'EPD2_BUSY',9:'EPD2_PWR',10:'GND',11:'GND'}
for num,net in cn2nets.items():sch_label(new_ids['CN3']['sch'],num,net,80 if num<10 else 20);set_padnet(new_ids['CN3']['pcb'],num,net)

locs=[(1130,3386.02,180),(1090,3437.22,180),(1050,3488.41,180),(1010,3539.61,180),(1700,3539.57,0),(1700,3488.39,0),(1700,3437.2,0),(2320,1855,180)]
for i in range(8):
    des='R'+str(21+i);clone_component(S,'e70',des,1260,-745+i*28,0);x,y,a=locs[i];clone_component(P,'e78',des,x,y,a)
    for rec in (S,P):set_part(rec,des,specs['20R'],'20R')
    n1,n2=(outputs[i][0]+'_BUF',outputs[i][0]) if i<7 else ('EPD2_BUSY_BUF','User_3V3_IO17')
    for num,net in [(1,n1),(2,n2)]:sch_label(new_ids[des]['sch'],num,net,75);set_padnet(new_ids[des]['pcb'],num,net)

pulls=[('R29','EPD2_CS','3V3',1420,3650,90),('R30','EPD2_RST','3V3',1310,3650,90),('R31','EPD_PWR','GND',390,3700,0),('R32','EPD2_PWR','GND',1200,3710,0),('R33','EPD2_BUSY','GND',1080,3650,0)]
for i,(des,n1,n2,x,y,a) in enumerate(pulls):
    sx=1220+(i%3)*140;sy=-350+(i//3)*100
    clone_component(S,'e70',des,sx,sy,90);clone_component(P,'e78',des,x,y,a)
    for rec in (S,P):set_part(rec,des,specs['100K_0603'],'100K')
    for num,net in [(1,n1),(2,n2)]:sch_label(new_ids[des]['sch'],num,net,25);set_padnet(new_ids[des]['pcb'],num,net)

for des,templ,sx,sy,px,py,pcbtempl in [('C9','e83',1500,-250,1220,3290,'e42'),('C10','e113',1620,-250,1730,3690,'e54')]:
    clone_component(S,templ,des,sx,sy,90);clone_component(P,pcbtempl,des,px,py,0)
    if des=='C9':
        for rec in (S,P):set_part(rec,des,specs['100nF'],'100nF')
    for num,net in [(1,'GND'),(2,'3V3')]:sch_label(new_ids[des]['sch'],num,net,25);set_padnet(new_ids[des]['pcb'],num,net)

# Increase sheet size so all newly added circuitry remains on the printed page.
for key,value in [('Page Size','A3'),('Size','A3'),('Width','1654'),('Height','1169'),('Version','V3'),('@Project Name','底板_双屏Flash_V3'),('@Update Date','2026-10-06')]:attr(S,'e1',key,value)
text=copy.deepcopy(S['e348']['data']);text.update(x=1180,y=-1080,value='双屏独立接口 / Flash外接模块',fontSize=20);add(S,'TEXT',text)

# Fix mechanical footprints in this copied project only.
for v in docs['e37f6b13aa154279']['records'].values():
    if v['head']['type']=='PAD':
        outer=1.4 if str(v['data']['num'])=='32' else 1.8
        v['data']['defaultPad'].update(width=outer/0.0254,height=outer/0.0254)

# Larger J1 pads require local fanout adjustments. Leave IO26/IO28 intact;
# J1.32 uses a 1.4mm land with a 0.19mm radial annulus to preserve those routes.
def pcb_line(net,a,b,layer=1,width=10):
    if math.dist(a,b)<1e-6:return
    add(P,'LINE',{'partitionId':'','groupId':0,'netName':net,'layerId':layer,'startX':a[0],'startY':a[1],'endX':b[0],'endY':b[1],'width':width,'locked':False,'zIndex':0})
prefixes=[('e330','e185',9),('e323','e186',15),('e235','e187',23),('e194','e190',35),('e196','e191',37),('e669','e192',39),('e442','e443',25),('e448','e447',19),('e450','e449',17),('e456','e455',13),('e460','e459',7),('e465','e466',3)]
for horizontal,diagonal,num in prefixes:
    hp=P[horizontal]['data'];dp=P[diagonal]['data']
    src=next(p for p in pads(docs) if p['des']=='J1' and p['num']==str(num))
    old_y=hp['startY'];new_y=src['y']+50;turn=(src['x']+50,new_y)
    P.pop(diagonal)
    if hp['startX']<hp['endX']:hp['startX']=170
    else:hp['endX']=170
    pcb_line(hp['netName'],(src['x'],src['y']),turn)
    pcb_line(hp['netName'],turn,(150,new_y))
    bend=(150+abs(old_y-new_y),old_y)
    pcb_line(hp['netName'],(150,new_y),bend)
    pcb_line(hp['netName'],bend,(170,old_y))
P.pop('e427');P.pop('e430')
pcb_line('3V3',(-55.1616,1405),(-5.1616,1455),2,10)
pcb_line('3V3',(-5.1616,1455),(100,1455),2,10)
pcb_line('3V3',(100,1455),(113.2843,1450),2,10)
for v in docs['6dbcb49763fcec05']['records'].values():
    if v['head']['type']=='PAD':
        v['data']['plated']=False;v['data']['hole'].update(width=3.2/.0254,height=3.2/.0254);v['data']['defaultPad'].update(width=3.2/.0254,height=3.2/.0254)

# The inherited R0603 footprint disables the paste aperture with a -100mm expansion.
for v in docs['fe2d03bc43ed8a05']['records'].values():
    if v['head']['type']=='PAD':v['data'].update(topPasteExpansion=0,bottomPasteExpansion=0)

# New parts must not sit on stitching holes. Retain all non-ground vias.
removed_vias=[]
for rid,v in list(P.items()):
    p=v['data']
    if v['head']['type']=='VIA' and p['netName'].upper()=='GND' and 900<p['centerX']<1820 and 3200<p['centerY']<3960:
        removed_vias.append(rid);del P[rid]

# Remove the former ground connection, including its dedicated via, at U2.2.
if 'e1754' in P:
    old_ground_via=P['e1754']['data']
    assert P['e1754']['head']['type']=='VIA' and old_ground_via['netName']=='GND'
    assert (old_ground_via['centerX'],old_ground_via['centerY'])==(2740,1855)
    del P['e1754'];removed_vias.append('e1754')
pad2=next(p for p in pads(docs) if p['des']=='U2' and p['num']=='2')
removed_ground=[]
for rid,v in list(P.items()):
    p=v['data']
    if v['head']['type']!='LINE' or p.get('layerId')!=1 or p.get('netName','').upper()!='GND':continue
    ax,ay=p['startX'],p['startY'];bx,by=p['endX'],p['endY'];dx=bx-ax;dy=by-ay
    t=max(0,min(1,((pad2['x']-ax)*dx+(pad2['y']-ay)*dy)/(dx*dx+dy*dy or 1)))
    if abs(ax+t*dx-pad2['x'])<48 and abs(ay+t*dy-pad2['y'])<19:
        removed_ground.append(rid);del P[rid]

changes.extend(['CN2恢复9P，前八个信号焊盘保持原位置，第9脚新增PWR；新增CN3、U3、R21-R33、C9-C10。','U2第2脚解除接地，接屏2 BUSY；第18脚通过R28返回IO17。','J1焊盘外径1.8mm，孔径保持原值；四个M3孔改3.2mm NPTH。','修正R0603异常焊膏层扩展，恢复标准焊膏开窗。'])
manifest={'new_ids':new_ids,'removed_stitching_vias':removed_vias,'removed_u2_ground_tracks':removed_ground,'changes':changes,'outputs':outputs}
(OUT/'modified_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
(OUT/'修改清单.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
render(docs,'修改后PCB_布线前.png')
print('parts',len(components(P)),'removed GND vias',len(removed_vias),'U2.2 ground tracks',removed_ground,'U2.2 location',pad2['x'],pad2['y'])
