from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'tb/tb_haar_integration.v';s=f.read_text();s=s.replace(' reg[7:0]r8,g8,b8;',' reg[1:0] next_expected;\n reg[7:0]r8,g8,b8;')
a='  $display("PASS end-to-end 720p capture -> Haar -> frame-atomic boxes -> blank clear");$finish;'
b='''  // Explicitly exercise simultaneous completion and next-frame capture.
  @(negedge clk);next_expected=dut.next_phase+2'd1;
  force dut.hb=0;force dut.hd=1;force dut.fs=1;force dut.capturing=0;force dut.start=0;
  @(posedge clk);#1;
  if(dut.capture_phase!==next_expected)$fatal(1,"FAIL repeated phase at completion/capture boundary");
  @(negedge clk);release dut.hb;release dut.hd;release dut.fs;release dut.capturing;release dut.start;
  $display("PASS simultaneous completion/capture preserves phase rotation");
  $display("PASS end-to-end 720p capture -> Haar -> frame-atomic boxes -> blank clear");$finish;'''
assert a in s;s=s.replace(a,b);f.write_text(s)
