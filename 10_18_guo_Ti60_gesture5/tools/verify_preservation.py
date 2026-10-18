from pathlib import Path
import hashlib,json
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
results={}
for name,rel in [('ram_baseline','reports/vision8/baseline_manifest.json'),('historical_original','reports/ram_optimization/original_manifest.json')]:
 data=json.loads((P/rel).read_text(encoding='utf-8-sig'));root=Path(data['source'])
 changed=[rel for rel,h in data['files'].items() if not (root/rel).is_file() or sha(root/rel)!=h]
 actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
 added=sorted(actual-set(data['files']))
 assert not changed and not added,(name,changed,added)
 results[name]={'files_checked':len(data['files']),'changed':changed,'added':added}
baseline=Path(json.loads((P/'reports/vision8/baseline_manifest.json').read_text(encoding='utf-8'))['source'])
canny=[p for p in (baseline/'src/vision').rglob('*') if p.is_file()]
assert all(sha(p)==sha(P/p.relative_to(baseline)) for p in canny),'Canny pipeline changed'
results['unchanged_canny_pipeline_files']=len(canny)
(P/'reports/vision8/preservation_verified.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps(results,indent=2))
