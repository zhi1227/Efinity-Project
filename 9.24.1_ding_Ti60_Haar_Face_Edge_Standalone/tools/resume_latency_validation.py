from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'tools/record_verified_build.py';s=f.read_text(encoding='utf-8-sig');s=s.replace("assert 'PASS' in t and not re.search(r'Fatal:|FAIL|ERROR:',t),name", "assert 'PASS' in t and '$finish called' in t and not re.search(r'Fatal:|FAIL|ERROR:',t),name");f.write_text(s,encoding='utf-8')
for name in ['tools/run_tests.ps1','tools/program_jtag.ps1']:
 f=P/name;s=f.read_text(encoding='utf-8-sig');s=s.replace("$s -notmatch 'PASS' -or $s -match", "$s -notmatch 'PASS' -or $s -notmatch '\\$finish called' -or $s -match");f.write_text(s,encoding='utf-8')
print('Require completed simulation, not partial PASS lines, before recording or programming.')
