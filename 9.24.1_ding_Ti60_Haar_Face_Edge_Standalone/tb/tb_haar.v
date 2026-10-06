`timescale 1ns/1ps
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
    0:$readmemh("sim/expected_positive_0.mem",exp,0,expected_n?expected_n-1:0);
    1:$readmemh("sim/expected_positive_1.mem",exp,0,expected_n?expected_n-1:0);
    2:$readmemh("sim/expected_positive_2.mem",exp,0,expected_n?expected_n-1:0);
    3:$readmemh("sim/expected_positive_3.mem",exp,0,expected_n?expected_n-1:0);
    4:$readmemh("sim/expected_near_0.mem",exp,0,expected_n?expected_n-1:0);
    5:$readmemh("sim/expected_near_1.mem",exp,0,expected_n?expected_n-1:0);
    6:$readmemh("sim/expected_near_2.mem",exp,0,expected_n?expected_n-1:0);
    7:$readmemh("sim/expected_near_3.mem",exp,0,expected_n?expected_n-1:0);
    8:$readmemh("sim/expected_blank_0.mem",exp,0,expected_n?expected_n-1:0);
    9:$readmemh("sim/expected_blank_1.mem",exp,0,expected_n?expected_n-1:0);
    10:$readmemh("sim/expected_blank_2.mem",exp,0,expected_n?expected_n-1:0);
    11:$readmemh("sim/expected_blank_3.mem",exp,0,expected_n?expected_n-1:0);
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
