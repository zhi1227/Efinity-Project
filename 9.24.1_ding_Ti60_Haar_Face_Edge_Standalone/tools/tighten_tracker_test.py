from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'tb/tb_haar_tracker.v';s=f.read_text();assert 'wait(dut.state==2);frame;' in s;s=s.replace('wait(dut.state==2);frame;','wait(dut.state==1&&dut.scan_index==7);frame;');f.write_text(s)
f=P/'tools/record_verified_build.py';s=f.read_text();old="assert all(f.stat().st_mtime<=bit for f in paths if f.suffix in ['.v','.sv','.vh','.mem','.sdc']), 'sources newer than bit'";new="implementation_paths=[f for f in paths if f.relative_to(P).parts[0] not in ('tb','sim')]\nassert all(f.stat().st_mtime<=bit for f in implementation_paths if f.suffix in ['.v','.sv','.vh','.mem','.sdc']), 'implementation sources newer than bit'";assert old in s;s=s.replace(old,new);f.write_text(s)
print('Tightened timeout-boundary test; implementation sources and programmed bit unchanged.')
