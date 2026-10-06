from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'tools/generate_test.py';s=f.read_text(encoding='utf-8-sig');s=s.replace('.resize((64,64),Image.Resampling.BILINEAR),(48,12))','.resize((80,80),Image.Resampling.BILINEAR),(40,5))');f.write_text(s)
s=(P/'tb/tb_haar_integration.v').read_text().replace('module tb_haar_integration;','module tb_haar_near;').replace('sim/positive.mem','sim/near.mem').replace('f<18','f<14').replace('rgb=f<4?','rgb=f<1?').replace('||!saw_early','')
s=s.replace('if(dut.display_count>0)begin saw_face=1;','if(dut.display_count>0)begin\n     if(dut.display_boxes[21:11]-dut.display_boxes[10:0]+1<=384)$fatal(1,"FAIL large face was not displayed as a large box");\n     saw_face=1;')
s=s.replace('PASS end-to-end 720p capture -> Haar -> frame-atomic boxes -> blank clear','PASS large face beyond old 384px limit reaches display and clears')
(P/'tb/tb_haar_near.v').write_text(s)
for name in ['tools/run_tests.ps1','tools/program_jtag.ps1','tools/record_verified_build.py']:
 f=P/name;s=f.read_text(encoding='utf-8-sig');s=s.replace("'tb_gray_thumbnail'","'tb_gray_thumbnail','tb_haar_near'")
 if name.endswith('run_tests.ps1'):s=s.replace("'tb/tb_gray_thumbnail.v'","'tb/tb_gray_thumbnail.v','tb/tb_haar_near.v'")
 f.write_text(s,encoding='utf-8')
