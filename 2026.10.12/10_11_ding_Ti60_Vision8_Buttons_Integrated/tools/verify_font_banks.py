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
