from board_tools import *
import time,hashlib,shutil

docs=json.loads((OUT/'routed_state.json').read_text(encoding='utf8'))
source=read_project(SOURCE)
now=int(time.time()*1000)

# Modified embedded footprints get independent identities in the copied project.
fmap={}
for old in ['e37f6b13aa154279','6dbcb49763fcec05','fe2d03bc43ed8a05','c5555808f571eea1']:
    new=uuid.uuid4().hex[:16];fmap[old]=new
    docs[new]=copy.deepcopy(docs[old]);docs[new]['head'].update(uuid=new,version=str(now),updateTime=now)
    meta=docs[new]['records']['META']['data'];meta['source']=None
    docs[old]=copy.deepcopy(source[old])
dmap={}
used={a['Device'] for records in [docs[SCH]['records'],docs[PCB]['records']] for _,_,a in components(records).values() if a.get('Device')}
for did in used:
    m=docs[did]['records']['META']['data'];f=m.get('attributes',{}).get('Footprint')
    if f not in fmap:continue
    if did in source:
        new=uuid.uuid4().hex[:16];docs[new]=copy.deepcopy(docs[did]);docs[new]['head']['uuid']=new;dmap[did]=new
    else:new=did
    meta=docs[new]['records']['META']['data'];meta['source']=None;meta['attributes']['Footprint']=fmap[f]
for records in [docs[SCH]['records'],docs[PCB]['records']]:
    for v in records.values():
        if v['head']['type']=='ATTR':
            p=v['data']
            if p['key']=='Footprint' and p['value'] in fmap:p['value']=fmap[p['value']]
            if p['key']=='Device' and p['value'] in dmap:p['value']=dmap[p['value']]
    a=attrs(records)
    for cid,v in records.items():
        if v['head']['type']=='COMPONENT' and a[cid].get('Designator'):
            # Keep PCB embedded attributes consistent with the component attribute records.
            if records is docs[PCB]['records']:
                for key in ['Value','Supplier Part','Manufacturer','Manufacturer Part','Unique ID']:
                    if key in a[cid]:v['data'].setdefault('attrs',{})[key]=a[cid][key]

# Filled copper is invalid after rerouting. Retain outlines for native rebuilding.
for rid,v in list(docs[PCB]['records'].items()):
    if v['head']['type']=='POURED':del docs[PCB]['records'][rid]

shutil.copy2(SOURCE,TARGET)
con=sqlite3.connect(TARGET);con.row_factory=sqlite3.Row
project=dict(con.execute('SELECT * FROM projects').fetchone())
oldproject=project['uuid'];newproject=uuid.uuid4().hex+uuid.uuid4().hex
oldbranch=project['branch_uuid'];newbranch=uuid.uuid4().hex
newstart=uuid.uuid4().hex
histtable='project_history_'+oldbranch;newhisttable='project_history_'+newbranch
parent=con.execute('SELECT history_uuid FROM branches WHERE uuid=?',(oldbranch,)).fetchone()[0]
max_ticket=max((r['head'].get('ticket',0) for d in source.values() for r in d['records'].values()),default=4000)
ticket=max_ticket+100
def compact(x):return json.dumps(x,ensure_ascii=False,separators=(',',':'))
lines=[compact({'type':'EDIT_HEAD'})+'||'+compact({'uuid':project['owner_uuid'],'username':'','nickname':'','updateTime':now})+'|']
changed=[]
for did,doc in docs.items():
    before=source.get(did,{'records':{}})['records'];after=doc['records'];ops=[]
    for rid,rec in after.items():
        if rid not in before or rec['data']!=before[rid]['data'] or rec['head']['type']!=before[rid]['head']['type']:
            ticket+=1;head=copy.deepcopy(rec['head']);head['ticket']=ticket;ops.append(compact(head)+'||'+compact(rec['data'])+'|');rec['head']=head
    for rid,rec in before.items():
        if rid not in after:
            ticket+=1;head=copy.deepcopy(rec['head']);head['ticket']=ticket;ops.append(compact(head)+'|||')
    if not ops:continue
    ticket+=1;doc['head'].update(updateTime=now,version=str(now))
    lines.append(compact({'type':'DOCHEAD','ticket':ticket})+'||'+compact(doc['head'])+'|');lines.extend(ops);changed.append(did)
stream='\n'.join(lines)+'\n'
histid=uuid.uuid4().hex;key=uuid.uuid4().hex
payload=base64.b64encode(AESGCM(bytes.fromhex(key)).encrypt(bytes.fromhex(histid),gzip.compress(stream.encode('utf8')),None)).decode('ascii')
con.execute('ALTER TABLE "'+histtable+'" RENAME TO "'+newhisttable+'"')
hid=con.execute('SELECT COALESCE(MAX(id),0)+1 FROM "'+newhisttable+'"').fetchone()[0]
con.execute('INSERT INTO "'+newhisttable+'"(id,uuid,parent,key,num) VALUES(?,?,?,?,0)',(hid,histid,parent,key))
con.execute('INSERT INTO history_data(uuid,history_uuid,dataStr) VALUES(?,?,?)',(histid,histid,payload))
for (table,) in con.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall():
    cols={r['name'] for r in con.execute('PRAGMA table_info("'+table+'")')}
    if 'project_uuid' in cols:con.execute('UPDATE "'+table+'" SET project_uuid=?',(newproject,))
    if 'branch_uuid' in cols:con.execute('UPDATE "'+table+'" SET branch_uuid=? WHERE branch_uuid=?',(newbranch,oldbranch))
con.execute('UPDATE branches SET uuid=? WHERE name=?',(newstart,'start'))
con.execute('UPDATE branches SET uuid=?,parent_uuid=?,history_uuid=? WHERE uuid=?',(newbranch,newstart,histid,oldbranch))
con.execute('UPDATE projects SET uuid=?,name=?,branch_uuid=?,updated_at=datetime(\'now\',\'localtime\')',(newproject,'底板_双屏Flash_V3',newbranch))
structure=con.execute('SELECT structure FROM project_structures ORDER BY id DESC LIMIT 1').fetchone()[0]
structure=json.loads(structure)
for group,did in [('sheets',SCH),('pcbs',PCB)]:
    structure[group][did].update(version=str(now),updateTime=now)
con.execute('INSERT INTO project_structures(ticket,project_uuid,branch_uuid,structure) VALUES(?,?,?,?)',(ticket,newproject,newbranch,compact(structure)))
con.commit();assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok';con.close()
loaded=read_project(TARGET)
for did in changed:
    assert {k:r['data'] for k,r in loaded[did]['records'].items()}=={k:r['data'] for k,r in docs[did]['records'].items()},did
(OUT/'final_state.json').write_text(json.dumps(docs,ensure_ascii=False),encoding='utf8')
verification={'original_backup_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'modified_project_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),'database_integrity':'ok','history_decode_roundtrip':'passed','project_uuid':newproject,'branch_uuid':newbranch,'edited_documents':len(changed),'native_copper_rebuild':'pending','native_drc':'pending'}
(OUT/'文件验证.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2),encoding='utf8')
print('SAVED',str(TARGET),'changed documents',len(changed),'bytes',TARGET.stat().st_size)
