"""Isolated positive/negative fixtures for the new test-evidence validator."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import copy, json, os, uuid
import verify_inline_threshold_delivery as audit

P=Path(__file__).resolve().parents[1]
fixture=P/'reports/inline_threshold'/('audit_selftest_'+uuid.uuid4().hex)
fixture.mkdir(parents=True)
audit.P=fixture
audit.REQUIRED_CHECKS={'isolated_fixture'}
start=datetime.now(timezone.utc)-timedelta(seconds=10)
(fixture/'bench.sv').write_text('// isolated testbench fixture\n',encoding='utf-8')
(fixture/'simulation.log').write_text('PASS: intermediate case\nPASS: complete isolated suite\n$finish called at time 250 ns\n',encoding='utf-8')
current={'design.v':'0'*64}
protection={'created_utc':(start-timedelta(seconds=1)).isoformat()}
item={'name':'isolated_fixture','status':'PASS','logs':['simulation.log'],
      'expected_log_sha256':{'simulation.log':audit.sha(fixture/'simulation.log')},
      'completion_markers':{'simulation.log':['PASS: complete isolated suite','$finish called at time 250 ns']},
      'sources':[{'path':'bench.sv','sha256':audit.sha(fixture/'bench.sv')}]}
data={'production_inputs':current,'started_utc':start.isoformat(),'checks':[item]}
results=[]

def run(name, mutate=None, fail=True):
    record=copy.deepcopy(data)
    if mutate:mutate(record)
    try:
        audit.check_tests(record,current,protection)
        rejected=False
    except (AssertionError,KeyError,ValueError) as error:
        rejected=True
        reason=str(error)
    assert rejected==fail,(name,rejected,fail)
    results.append({'name':name,'status':'PASS','expected':'rejected' if fail else 'accepted',
                    'reason':reason if rejected else 'complete hash-bound fixture'})

run('complete_fixture',fail=False)
run('missing_final_marker',lambda d:d['checks'][0]['completion_markers'].update({'simulation.log':['PASS: final marker absent']}))
run('missing_finish',lambda d:d['checks'][0]['completion_markers'].update({'simulation.log':['PASS: complete isolated suite','$finish called at time 999 ns']}))
run('log_hash_changed',lambda d:d['checks'][0]['expected_log_sha256'].update({'simulation.log':'1'*64}))
run('source_hash_changed',lambda d:d['checks'][0]['sources'][0].update({'sha256':'2'*64}))
run('production_phase_changed',lambda d:d['production_inputs'].update({'design.v':'3'*64}))
run('test_not_pass',lambda d:d['checks'][0].update({'status':'RUNNING'}))
run('empty_sources',lambda d:d['checks'][0].update({'sources':[]}))
run('empty_markers',lambda d:d['checks'][0]['completion_markers'].update({'simulation.log':[]}))
run('duplicate_checks',lambda d:d['checks'].append(copy.deepcopy(d['checks'][0])))
run('mandatory_check_missing',lambda d:d['checks'][0].update({'name':'another_fixture'}))
run('hash_keys_not_log_keys',lambda d:d['checks'][0]['expected_log_sha256'].update({'another.log':'4'*64}))
run('future_test_start_stale_log',lambda d:d.update({'started_utc':(datetime.now(timezone.utc)+timedelta(minutes=1)).isoformat()}))
run('predates_copy',lambda d:d.update({'started_utc':(start-timedelta(days=1)).isoformat()}))
saved=(fixture/'simulation.log').read_bytes()
(fixture/'simulation.log').write_bytes(saved+b'ERROR: fixture intentional negative\n')
bad=audit.sha(fixture/'simulation.log')
run('failure_even_with_final_pass',lambda d:d['checks'][0]['expected_log_sha256'].update({'simulation.log':bad}))
(fixture/'simulation.log').write_bytes(saved)
try:
    audit.inside('../outside.log')
    raise AssertionError('Traversal unexpectedly accepted')
except AssertionError as error:
    assert 'escapes project' in str(error)
    results.append({'name':'path_traversal','status':'PASS','expected':'rejected'})
report={'status':'PASS','isolated_fixture':str(fixture),'checks':results,'check_count':len(results),
        'production_sources_modified':False,'old_verifiers_modified':False}
(fixture/'results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'status':'PASS','checks':len(results),'results':str(fixture/'results.json')}))
