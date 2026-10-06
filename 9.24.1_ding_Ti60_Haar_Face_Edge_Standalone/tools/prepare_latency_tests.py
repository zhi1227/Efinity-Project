from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
loads='\n'.join(f'    {i}:$readmemh("sim/expected_{kind}_{phase}.mem",exp,0,expected_n?expected_n-1:0);' for i,(kind,phase) in enumerate((k,p) for k in ['positive','near','blank'] for p in range(4)))
(P/'tb/tb_haar.v').write_text('''`timescale 1ns/1ps
module tb_haar;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,load_we=0,start=0;reg [13:0] addr=0;reg [7:0] pixel=0;reg [1:0] scan_phase=0;
 wire busy,done,dv;wire [10:0] x;wire [9:0] y,s;wire [31:0] cycles;wire [15:0] raw;
 haar_engine dut(.scan_phase(scan_phase),.clk(clk),.rst_n(rst_n),.load_we(load_we),.load_addr(addr),.load_pixel(pixel),.start(start),.busy(busy),.done(done),.det_valid(dv),.det_x(x),.det_y(y),.det_size(s),.cycles(cycles),.raw_count(raw),.debug_addr(14'd0));
 reg [7:0] im[0:14399];reg [31:0] exp[0:255];reg [15:0] counts[0:11];
 integer i,count=0,run=0,total=0,expected_n=0,first_cycle=0,large_count=0;
 initial begin
  $readmemh("sim/expected_counts.mem",counts);
  repeat(5)@(negedge clk);rst_n=1;
  for(run=0;run<12;run=run+1)begin
   count=0;first_cycle=0;scan_phase=run%4;expected_n=counts[run];
   if(run<4)$readmemh("sim/positive.mem",im);
   else if(run<8)$readmemh("sim/near.mem",im);
   else $readmemh("sim/blank.mem",im);
   case(run)
''' +loads+'''
   endcase
   for(i=0;i<14400;i=i+1)begin @(negedge clk);load_we=1;addr=i;pixel=im[i];end
   @(negedge clk);load_we=0;start=1;@(negedge clk);start=0;
   wait(done);@(negedge clk);
   if(count!=expected_n||raw!=expected_n)$fatal(1,"FAIL count run=%d actual=%d expected=%d",run,count,expected_n);
   if(run==0&&cycles>=6678150)$fatal(1,"FAIL did not improve previous 6678150-cycle baseline");
   $display("PASS run=%0d phase=%0d detections=%0d cycles=%0d first_detection_cycle=%0d",run,scan_phase,count,cycles,first_cycle);
  end
  if(large_count==0)$fatal(1,"FAIL no large face exercised");
  $display("PASS tb_haar all four scan phases, large faces, subsequent blanks, exact software equivalence");$finish;
 end
 always @(negedge clk)begin
  if(dv)begin
   if(count>=expected_n)$fatal(1,"FAIL extra detection run=%d",run);
   if({1'b0,s,y,x}!==exp[count])$fatal(1,"FAIL run=%d box=%d actual=%h expected=%h",run,count,{1'b0,s,y,x},exp[count]);
   if(count==0)first_cycle=cycles;
   if(run>=4&&run<8&&s>384)large_count=large_count+1;
   count=count+1;
  end
  total=total+1;if(total>100000000)$fatal(1,"FAIL timeout state=%d",dut.state);
 end
endmodule
''',encoding='utf-8')
(P/'tb/tb_gray_thumbnail.v').write_text('''`timescale 1ns/1ps
module tb_gray_thumbnail;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,valid=0;reg [10:0] x=0;reg [9:0] y=0;reg [7:0] pixel=0;
 wire ov;wire [7:0] op;
 gray_thumbnail #(.WIDTH(16),.HEIGHT(16)) dut(clk,rst,valid,x,y,pixel,ov,op);
 integer sums[0:3];integer expected,idx,outputs=0,f,row,col,n;reg expected_valid;
 always @(posedge clk)if(rst)begin
  expected_valid=valid&&(x%8==7)&&(y%8==7);
  idx=(y/8)*2+x/8;
  if(valid)sums[idx]=sums[idx]+pixel;
  expected=(sums[idx]+32)/64;
  #1;
  if(ov!==expected_valid)$fatal(1,"FAIL thumbnail output timing");
  if(ov)begin
   if(op!==expected[7:0])$fatal(1,"FAIL thumbnail average block=%d actual=%d expected=%d",idx,op,expected);
   outputs=outputs+1;
  end
 end
 initial begin
  for(n=0;n<4;n=n+1)sums[n]=0;
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<2;f=f+1)begin
   for(n=0;n<4;n=n+1)sums[n]=0;
   for(row=0;row<16;row=row+1)for(col=0;col<16;col=col+1)begin
    @(negedge clk);valid=1;x=col;y=row;pixel=f==1?255:(col*17+row*29)%256;
    if((col+row)%5==0)begin @(negedge clk);valid=0;end
   end
   @(negedge clk);valid=0;repeat(4)@(negedge clk);
  end
  if(outputs!=8)$fatal(1,"FAIL output count %d",outputs);
  $display("PASS tb_gray_thumbnail exact 8x8 averages, blanking, white maximum, next-frame reset");$finish;
 end
endmodule
''',encoding='utf-8')
f=P/'tb/tb_haar_integration.v';s=f.read_text();s=s.replace('integer saw_face=0,saw_clear=0,published=0;','integer saw_face=0,saw_clear=0,saw_early=0,published=0;integer clocks=0,first_raw_clock=0,first_display_clock=0,first_done_clock=0,starts=0;')
s=s.replace('  if(dut.start)begin','''  clocks=clocks+1;
  if(dut.dv&&first_raw_clock==0)first_raw_clock=clocks;
  if(dut.hd&&first_done_clock==0)first_done_clock=clocks;
  if(dut.start)begin
   if(dut.capture_phase!==starts%4)$fatal(1,"FAIL phase rotation");
   starts=starts+1;''')
s=s.replace('if(dut.display_count>0)begin saw_face=1;','if(dut.display_count>0)begin saw_face=1;if(dut.hb)saw_early=1;if(first_display_clock==0)first_display_clock=clocks;')
s=s.replace('if(!saw_face||!saw_clear||overflow)','if(!saw_face||!saw_clear||!saw_early||overflow)')
s=s.replace('  $display("PASS end-to-end','  if(first_display_clock-first_raw_clock>1237600)$fatal(1,"FAIL first box publication latency");\n  $display("PASS early publish clocks: raw=%0d display=%0d full_done=%0d",first_raw_clock,first_display_clock,first_done_clock);\n  $display("PASS end-to-end')
f.write_text(s)
print('Prepared all-phase, large-face, averaging and early-publication regressions.')
