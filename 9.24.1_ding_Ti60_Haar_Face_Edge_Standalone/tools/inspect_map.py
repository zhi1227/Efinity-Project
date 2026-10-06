from pathlib import Path
p=Path(__file__).resolve().parents[1]
t=(p/'outflow/Ti60_Demo.map.v').read_text()
for key in ['\\u_haar/core/mult_175 ','\\u_haar/core/mult_177 ']:
 i=t.find(key)
 print(t[max(0,i-2400):i+1300])
