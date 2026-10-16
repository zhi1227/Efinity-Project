from pathlib import Path
import xml.etree.ElementTree as ET
import json
P=Path(__file__).resolve().parents[1]
B=Path((P/'reports/vision8/io29_migration_backup_path.txt').read_text(encoding='utf-8-sig').strip())
def gpio(path,name):
    return next(n for n in ET.parse(path).getroot().iter() if n.tag.endswith('comp_gpio') and n.get('name')==name)
a=gpio(P/'Ti60_Demo.peri.xml','io28_button_i')
b=gpio(P/'Ti60_Demo.peri.xml','io29_button_i')
assert ET.tostring(a)==ET.tostring(gpio(B/'Ti60_Demo.peri.xml','io28_button_i')),'IO28 config changed'
assert b.get('gpio_def')=='GPIOL_P_16' and b.get('mode')=='input'
assert b.get('io_standard')==a.get('io_standard')=='1.8 V LVCMOS'
assert {k:v for k,v in b[0].attrib.items() if k!='name'}=={k:v for k,v in a[0].attrib.items() if k!='name'}
nodes=[n for n in ET.parse(P/'Ti60_Demo.peri.xml').getroot().iter() if n.tag.endswith('comp_gpio')]
assert len([n for n in nodes if n.get('gpio_def')=='GPIOL_P_16'])==1
assert not any(n.get('name')=='io35_button_i' for n in nodes)
for relative in ['example_top.v','rtl/vision8_controls.v','Ti60_Demo.pt.sdc']:
    old=(B/relative).read_text(encoding='utf-8-sig')
    new=(P/relative).read_text(encoding='utf-8-sig')
    assert old.replace('io35','io29').replace('IO35','IO29')==new,relative
    assert 'io35' not in new and 'IO35' not in new,relative
c=(P/'rtl/vision8_controls.v').read_text()
assert 'a(clk,rst_n,~io28,' in c and 'b(clk,rst_n,io29,' in c
pinout=(P/'outflow/Ti60_Demo.pinout.csv').read_text()
assert 'D1,GPIOL_P_16,io29_button_i.P,Input,1B,1.8 V,1.8 V LVCMOS' in pinout
assert 'io35_button_i' not in pinout
result={'IO28':'unchanged configuration and receiver','IO29':{'connector':'J7 / DC3-40 pin 34','fpga_pin':'D1 / GPIOL_P_16','mode':'input','standard':'1.8 V LVCMOS','pressed':0,'released':1},'IO35':'button assignment removed','backup':str(B)}
(P/'reports/vision8/io29_input_configuration_verified.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: IO29 pin/configuration/active-low verified; IO28 unchanged')
