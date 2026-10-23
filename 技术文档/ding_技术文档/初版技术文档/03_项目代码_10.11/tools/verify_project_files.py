"""Check that an Efinity project has all local build inputs, without vendor tools."""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET

def verify(root):
    root=Path(root).resolve()
    tree=ET.parse(root/'Ti60_Demo.xml')
    ns={'e':'http://www.efinixinc.com/enf_proj'}
    missing=[]
    checked=set()
    def need(path):
        path=Path(path).resolve()
        if not path.is_file():missing.append(str(path))
        else:checked.add(str(path.relative_to(root)))
        return path
    design=[need(root/n.attrib['name']) for n in tree.findall('.//e:design_file',ns)]
    constraints=[need(root/n.attrib['name']) for n in tree.findall('.//e:sdc_file',ns) if n.attrib.get('name')]
    need(root/'Ti60_Demo.peri.xml')
    include_dirs=[root]
    for n in tree.findall('.//e:synthesis/e:param',ns):
        if n.attrib.get('name')=='include':
            path=root/n.attrib['value']
            if not path.is_dir():missing.append(str(path))
            include_dirs.append(path)
    ips=tree.findall('.//e:ip_info/e:ip',ns)
    for ip in ips:
        config=need(root/ip.attrib['path'])
        if config.is_file():
            data=json.loads(config.read_text(encoding='utf-8-sig'))
            assert 'args' in data and 'conf' in data,f'Invalid IP settings: {config}'
            for key,values in data.get('output',{}).items():
                if key.startswith('external_source'):
                    for value in values:need(config.parent.parent/Path(value.replace('\\','/')))
        for n in ip.findall('e:ip_src_file',ns):design.append(need(config.parent/n.attrib['name']))
    for path in design:
        if not path.is_file():continue
        text=path.read_text(encoding='utf-8-sig',errors='replace')
        text=re.sub(r'"(?:\\.|[^"\\])*"|/\*[\s\S]*?\*/|//[^\n]*',
                    lambda m:m.group(0) if m.group(0).startswith('"') else ' ',text)
        for filename in re.findall(r'\$readmem[hb]\s*\(\s*"([^"\n]+)"',text):
            need(root/filename)
        for filename in re.findall(r'`include\s+"([^"\n]+)"',text):
            matches=[folder/filename for folder in [path.parent]+include_dirs]
            found=next((p for p in matches if p.is_file()),None)
            if found:need(found)
            else:missing.append(f'{path.name}: include {filename}')
    if missing:raise RuntimeError('Missing project inputs:\n'+'\n'.join(sorted(set(missing))))
    return {'project':str(root),'design_and_ip_sources':len(design),'ip_settings':len(ips),
            'sdc_files':len(constraints),'checked_files':len(checked),'missing_files':[]}

if __name__=='__main__':
    print(json.dumps(verify(sys.argv[1] if len(sys.argv)>1 else Path(__file__).resolve().parents[1]),indent=2,ensure_ascii=False))
