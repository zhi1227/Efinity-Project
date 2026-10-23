"""Write fresh, evidence-derived warning/timing/history/change inventories.

Does not modify source or build results. Run after collect; all source reports
and exact timing tables are named and hashed in the output.
"""
from pathlib import Path
from collections import Counter
import datetime,hashlib,json,re
P=Path(__file__).resolve().parents[1];R=P/'reports/capture_review'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2),encoding='utf-8')
def warnings(p):
 out=Counter()
 for s in p.read_text(errors='replace').splitlines():
  if not s.startswith('['):continue
  # Compare messages by relative source path and message, allowing line movement.
  m=re.search(r'\(([^()]+\.(?:v|sv)):(\d+)\)',s)
  if not m:out[s]+=1;continue
  file=m[1].replace('\\','/');parts=file.split('/')
  start=next((i for i,x in enumerate(parts) if x in ('rtl','src','ip','vendor')),None)
  file='/'.join(parts[start:]) if start is not None else parts[-1]
  out[s[:m.start()]+'@ '+file+s[m.end():]]+=1
 return out
def timing(p):
 text=p.read_text(errors='replace');out={};matrix={}
 for label,end,kind in [('Setup (Max) Clock Relationship','Hold (Min) Clock Relationship','setup'),('Hold (Min) Clock Relationship','NOTE:','hold')]:
  block=text.split(label,1)[1].split(end,1)[0];rows=[]
  for m in re.finditer(r'^\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(([^)]+)\)\s*$',block,re.M):
   launch,capture,constraint,slack,edge=m.groups();rows.append(dict(launch=launch,capture=capture,constraint_ns=float(constraint),slack_ns=float(slack),edge=edge))
   if launch==capture:
    d=out.setdefault(launch,{});key=kind+'_min_slack_ns';d[key]=min(d.get(key,float('inf')),float(slack))
  assert rows;matrix[kind]=rows
 return dict(path=str(p),sha256=sha(p),domains=out,relationships=matrix)
def main():
 b=read(R/'backup.json');backup=Path(b['backup']);original=P.parent/'10_20_ding_Ti60_Gesture5_4Key_InlineThreshold'
 wp={'original4Key':original/'outflow/Ti60_Demo.warn.log','before_audit':R/'previous_outflow/Ti60_Demo.warn.log','current':P/'outflow/Ti60_Demo.warn.log'}
 wc={k:warnings(f) for k,f in wp.items()};diff={}
 for name in ('original4Key','before_audit'):
  diff[name]=dict(added=[dict(message=m,count=n) for m,n in (wc['current']-wc[name]).items()],removed=[dict(message=m,count=n) for m,n in (wc[name]-wc['current']).items()])
 assert not any('truncated to fit in target size 384' in s for s in wc['current']),'Label width regression'
 tp={'original4Key':original/'outflow/Ti60_Demo.timing.rpt','before_audit':R/'previous_outflow/Ti60_Demo.timing.rpt','current':P/'outflow/Ti60_Demo.timing.rpt'}
 result=dict(status='GENERATED',created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),warnings=dict(inputs={k:dict(path=str(p),sha256=sha(p),count=sum(wc[k].values())) for k,p in wp.items()},difference=diff,note='Grouped by message plus source file; source-line movement ignored. New coordinate/integer width warnings must not all be called inherited. No 392-to-384 label truncation remains.'),timing={k:timing(f) for k,f in tp.items()},hardware='NOT_RUN')
 write(R/'build_analysis.json',result)
 old={e['path']:e['sha256'] for e in b['files']};changes=[]
 for f in [P/'example_top.v',P/'Ti60_Demo.pt.sdc',*list(P.glob('README*.md')),*list((P/'rtl').glob('*.v')),*list((P/'tools').glob('*.py')),*list((P/'sim').glob('*.sv'))]:
  rel=f.relative_to(P).as_posix();h=sha(f)
  if h!=old.get(rel):changes.append(dict(path=rel,kind='modified' if rel in old else 'added',before_sha256=old.get(rel),after_sha256=h))
 write(R/'changed_files.json',changes)
 inventory=[]
 for root in [P/'reports/capture_fix',R/'runs']:
  for f in sorted(root.rglob('*.json')):
   try:j=read(f)
   except Exception:continue
   if isinstance(j,dict) and j.get('status') in ('FAIL','ERROR','RUNNING','INCOMPLETE'):
    inventory.append(dict(path=f.relative_to(P).as_posix(),status=j['status'],sha256=sha(f),classification='historical' if f.is_relative_to(P/'reports/capture_fix') else 'development batch; selected bench evidence is explicit'))
 write(R/'nonpassing_history.json',inventory)
 print('Generated build_analysis.json, changed_files.json, nonpassing_history.json')
if __name__=='__main__':main()
