"""Negative acceptance tests; fixtures live in a new directory, RTL is untouched."""
from pathlib import Path
import copy,datetime,hashlib,json,sys
sys.dont_write_bytecode=True
import verify_capture_review as v
P=v.P
def main():
 import argparse
 ap=argparse.ArgumentParser();ap.add_argument('--evidence',type=Path,required=True);a=ap.parse_args()
 root=P/'reports/capture_review'/('verifier_tests_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'));root.mkdir()
 spec=v.read(a.evidence);out=[]
 def write(p,x):p.write_text(json.dumps(x,indent=2),encoding='utf-8')
 def rejection(name,changed,pattern):
  f=root/(name+'.json');write(f,changed)
  try:v.verify(f)
  except Exception as e:
   assert pattern in str(e),(name,str(e));out.append(dict(case=name,status='PASS',rejected=str(e)));return
  raise AssertionError('Acceptance failed to reject '+name)
 s=copy.deepcopy(spec)
 for e in s['runs']:e['benches']=[b for b in e['benches'] if b!='tb_review_top']
 s['runs']=[e for e in s['runs'] if e['benches']];rejection('missing_actual_top',s,'Missing required benches:')
 s=copy.deepcopy(spec)
 for e in s['runs']:e['benches']=[b for b in e['benches'] if b!='tb_h4_skin']
 s['runs']=[e for e in s['runs'] if e['benches']];rejection('missing_retained_bench',s,'Missing required benches:')
 first=spec['runs'][0];record=v.read(v.path(first['path']));bench=first['benches'][0]
 def modified(name,mutation,pattern):
  r=copy.deepcopy(record);mutation(r);rf=root/(name+'_run.json');write(rf,r)
  s=copy.deepcopy(spec);s['runs'][0]['path']=str(rf);rejection(name,s,pattern)
 modified('changed_input',lambda r:r['inputs'].update({str(P/'example_top.v'):'0'*64}),'Changed selected test input:')
 modified('failed_selected_bench',lambda r:next(t for t in r['results'] if t['bench']==bench).update(status='FAIL'),'Test not PASS')
 modified('changed_log',lambda r:next(t for t in r['results'] if t['bench']==bench).update(sha256='0'*64),'Changed log')
 fake=root/'incomplete.log';fake.write_text('PASS: incomplete\n',encoding='utf-8')
 modified('missing_finish',lambda r:next(t for t in r['results'] if t['bench']==bench).update(log=str(fake),sha256=v.sha(fake)),'Incomplete/error log')
 for name,old,new in [('sdc_crlf',b'create_clock A\n',b'create_clock A\r\n'),('sdc_prefix_modified',b'create_clock A\n',b'create_clock B\n')]:
  new+=b'set_false_path key_mode_n\nset_false_path key_freeze_n\n'
  try:v.sdc_prefix(old,new)
  except AssertionError as e:out.append(dict(case=name,status='PASS',rejected=str(e)))
  else:raise AssertionError('SDC mutation accepted')
 bad_build=copy.deepcopy(v.read(v.path(spec['build'])));bad_build['build']['resources']['XLRs']['used']=0
 bf=root/'modified_build.json';write(bf,bad_build);s=copy.deepcopy(spec);s['build']=str(bf)
 rejection('modified_build_metrics',s,'Selected build metrics differ')
 result=dict(status='PASS',cases=out,script_sha256=v.sha(Path(__file__)),verifier_sha256=v.sha(P/'tools/verify_capture_review.py'),selected_evidence_sha256=v.sha(a.evidence))
 write(root/'result.json',result);print('PASS:',len(out),'negative acceptance cases;',root/'result.json')
if __name__=='__main__':main()
