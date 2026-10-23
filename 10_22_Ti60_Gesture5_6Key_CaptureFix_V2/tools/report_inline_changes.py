"""Record source/test/document differences against the immutable original."""
from pathlib import Path
import hashlib,json,difflib
P=Path(__file__).resolve().parents[1];R=P/'reports/inline_threshold'
meta=json.loads((R/'protection.json').read_text(encoding='utf-8-sig'))
O=Path(meta.get('source',meta.get('original','')))
if not O.is_dir():
 O=P.parent/'10_20_ding_Ti60_Gesture5_RAM_Optimized'
def digest(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def eligible(f):
 rel=f.relative_to(P);return len(rel.parts)==1 or rel.parts[0] in {'rtl','src','vendor','ip','image','tools','sim'}
changed=[];added=[];patch=[]
for f in sorted(P.rglob('*')):
 if not f.is_file() or not eligible(f) or '__pycache__' in f.parts:continue
 rel=f.relative_to(P);old=O/rel
 if old.is_file():
  if digest(f)==digest(old):continue
  changed.append({'path':rel.as_posix(),'original_sha256':digest(old),'sha256':digest(f)})
  if f.suffix in {'.v','.sv','.vh','.py','.ps1','.md','.xml','.sdc','.json'}:
   patch.extend(difflib.unified_diff(old.read_text(encoding='utf-8-sig',errors='replace').splitlines(True),f.read_text(encoding='utf-8-sig',errors='replace').splitlines(True),fromfile='original/'+rel.as_posix(),tofile='new/'+rel.as_posix()))
 else:added.append({'path':rel.as_posix(),'sha256':digest(f)})
(R/'source_changes.json').write_text(json.dumps({'original':str(O),'project':str(P),'changed':changed,'added':added},ensure_ascii=False,indent=2),encoding='utf-8')
(R/'source_changes.diff').write_text(''.join(patch),encoding='utf-8')
print('PASS: source differences recorded:',len(changed),'changed originals,',len(added),'new files')
