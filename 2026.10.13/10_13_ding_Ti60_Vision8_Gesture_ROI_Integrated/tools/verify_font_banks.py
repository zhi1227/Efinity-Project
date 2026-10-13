from pathlib import Path
import re,json
P=Path(__file__).resolve().parents[1]
result={}
for name,base in [('menu','menu'),('vision6','vision6')]:
 data=json.loads((P/f'reports/{name}_font.json').read_text(encoding='utf-8'))
 flat=[int(s,16) for s in (P/f'{base}_font.hex').read_text().split()]
 paths=[P/f'{base}_font_bank{i}.hex' for i in range((data['glyphs']+31)//32)]
 banks=[int(s,16) for path in paths for s in path.read_text().split()]
 n=data['glyphs']*16
 assert flat[:n]==banks[:n],name
 result[name]={'glyphs':data['glyphs'],'banks':len(paths),'valid_words_equal':n}
assert data is not None
menu=json.loads((P/'reports/menu_font.json').read_text(encoding='utf-8'))
assert menu['lines'][31]=='0123456789ABCDEF-+ '
result['numeric_line_31']='PASS'
(P/'reports/vision8/font_banks_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))

shared=[int(s,16) for s in (P/'shared_font.hex').read_text().split()]
assert len(shared)==4096
sets={}
for name in ('menu','vision6'):
 lines=json.loads((P/f'reports/{name}_font.json').read_text(encoding='utf-8'))['lines']
 sets[name]=' '+''.join(sorted(set(''.join(lines))-{' '}))
union=' '+''.join(sorted(set(''.join(sets.values()))-{' '}))
assert len(union)==256
for name,chars in sets.items():
 flat=[int(s,16) for s in (P/f'{name}_font.hex').read_text().split()]
 for local,ch in enumerate(chars):
  common=union.index(ch)
  assert flat[local*16:local*16+16]==shared[common*16:common*16+16],(name,ch)
result['shared']={'characters':256,'words':4096,'pixels_equal_for_both_original_fonts':True}
(P/'reports/cpu_font_ram/font_pixels_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PASS: shared font preserves all original glyph pixels')
