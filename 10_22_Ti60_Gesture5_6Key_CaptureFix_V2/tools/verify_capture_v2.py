"""Read-only explicit-evidence acceptance. Optional --out creates a NEW file.

No latest-log search. Selected tests must bind the current production sources,
their own bench, fixtures and runner. Other unelaborated top benches in a batch
are ignored explicitly; batch failures/cancellations remain visible in output.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, re, sys

P=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def require(condition,message):
    if not condition: raise AssertionError(message)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--selection',type=Path,default=P/'reports/capture_v2/selected_evidence.json')
    ap.add_argument('--out',type=Path)
    args=ap.parse_args(); selected=read(args.selection)
    required=set(selected['required_benches']); found={}; batches=[]
    for batch in selected['runs']:
        record=read(P/batch['path']); chosen=set(batch['benches'])
        require(Path(record['base']).resolve()==P,'Selected test is from another project')
        batches.append({'path':batch['path'],'raw_status':record['status'],'selected':sorted(chosen)})
        for name in chosen:
            require(name not in found,'Duplicate selected test '+name)
            matches=[x for x in record['results'] if x['bench']==name]
            require(len(matches)==1 and matches[0]['status']=='PASS','Test not PASS: '+name)
            entry=matches[0]; log=P/entry['log']; text=log.read_text(errors='replace')
            require(sha(log)==entry['sha256'],'Changed log '+name)
            require('PASS:' in text and '$finish called' in text,'Missing terminal result '+name)
            require(not re.search(r'ERROR:|Error:|Fatal:|FATAL',text),'Error in selected log '+name)
            own_bench=False
            for filename,expected in record['inputs'].items():
                f=Path(filename)
                if f.parent==P/'sim' and f.suffix=='.sv' and f.stem!=name: continue
                require(f.is_file() and sha(f)==expected,'Changed input: '+filename+' for '+name)
                own_bench |= f==P/'sim'/(name+'.sv')
            require(own_bench,'Missing testbench binding '+name)
            found[name]={'log':entry['log'],'sha256':entry['sha256'],'markers':entry['markers']}
    require(set(found)==required,'Required test set mismatch')
    baseline=read(P/selected['baseline_failure'])
    require('tb_capture_v2_aux' in [x['bench'] for x in baseline['results']],'Missing baseline test')
    require(any(x['status']=='FAIL' and 'AUX wrapped past end' in x.get('error','') for x in baseline['results']),'Baseline did not reproduce wrap')
    build=read(P/selected['build'])
    require(build['status']=='PASS','Build not PASS')
    spec=importlib.util.spec_from_file_location('capture_v2_build',P/'tools/capture_v2_build.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    require(builder.inputs(P)==build['production_inputs'],'Production differs from compiled source')
    for f,h in build['outputs'].items(): require(sha(P/f)==h,'Changed build output '+f)
    for f,h in build['evidence'].items(): require(sha(P/f)==h,'Changed build evidence '+f)
    require(build['build']['min_setup_slack_ns']>=0 and build['build']['min_hold_slack_ns']>=0,'Timing failed')
    require(build['build']['resources']['XLRs']['used']<=60000,'XLR budget')
    require(build['build']['resources']['Memory Blocks']['used']<=230,'RAM budget')
    backup=read(P/'reports/capture_v2/backup.json'); manifest=read(Path(backup['manifest']))
    original=Path(backup['source']); copy=Path(backup['backup'])
    for filename in ('Ti60_Demo.pt.sdc','Ti60_Demo.peri.xml'):
        require(sha(P/filename)==manifest['sha256'][filename],'Protected constraint changed '+filename)
    # Full source/backup hash check is a recorded separate operation, not a name claim.
    protection_path=P/selected['protection']
    require(sha(protection_path)==selected['protection_sha256'],'Changed protection evidence')
    protection=read(protection_path)
    require(sha(Path(backup['manifest']))==protection['manifest_sha256'],'Changed backup manifest')
    require(protection['status']=='PASS' and protection['files']==len(manifest['sha256']),'Backup/source preservation failed')
    result={'status':'PASS','project':str(P),'tests':found,'test_count':len(found),
            'selection_sha256':sha(args.selection),'batches':batches,'build':build['build'],
            'original':str(original),'backup':str(copy),'preserved_files':protection['files'],
            'protection':selected['protection'],'protection_sha256':sha(protection_path),
            'verifier_sha256':sha(Path(__file__)),
            'physical_board':'NOT EXECUTED FOR V2; original board failure photos retained',
            'hardware_programming':'not performed; Flash not written'}
    if args.out:
        with args.out.open('x',encoding='utf-8') as stream: json.dump(result,stream,ensure_ascii=False,indent=2)
    print(json.dumps({k:v for k,v in result.items() if k!='tests'},ensure_ascii=False,indent=2))
    return 0
if __name__=='__main__': sys.exit(main())
