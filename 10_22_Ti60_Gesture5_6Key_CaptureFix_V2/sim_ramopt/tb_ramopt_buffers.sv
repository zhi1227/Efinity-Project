`timescale 1ns/1ps

// Compare every output clock against independently copied, unmodified RTL.
// Unknown RAM contents before filling must match as well as valid pixels.
module ramopt_line_case #(parameter W=1280,DW=1,CROP=0)(
 input clk,rst_n,input integer cycle);
 localparam STRIDE=W+24, FRAME=STRIDE*14;
 integer phase,row,col,valid_count=0;
 reg fs,de; reg[10:0]x; reg[9:0]y; reg[DW-1:0]din;
 wire[9*DW-1:0]wa,wb;wire va,vb;wire[10:0]xa,xb;wire[9:0]ya,yb;
 always @*begin
  phase=cycle%FRAME;row=phase/STRIDE;col=phase%STRIDE;
  fs=phase==0;de=col>=12&&col<12+W-CROP;
  // Deliberate DE holes also exercise cropped/restarted row handling.
  if(cycle>=24000&&cycle<42000&&col%37==0)de=0;
  x=de?col-12+CROP:0;y=row;
  din=(cycle*37)^(cycle>>3)^(row*83);
 end
 line_buffer_3x3 #(.WIDTH(W),.DWIDTH(DW),.AWIDTH(11)) a(clk,rst_n,fs,de,x,y,din,wa,va,xa,ya);
 line_buffer_3x3_baseline #(.WIDTH(W),.DWIDTH(DW),.AWIDTH(11)) b(clk,rst_n,fs,de,x,y,din,wb,vb,xb,yb);
 always @(negedge clk)if(cycle>1)begin
  if({wa,va,xa,ya}!=={wb,vb,xb,yb})
   $fatal(1,"line mismatch W=%0d DW=%0d CROP=%0d cycle=%0d",W,DW,CROP,cycle);
  if(va)valid_count=valid_count+1;
  if(cycle==89999&&valid_count<100)
   $fatal(1,"line coverage missing W=%0d DW=%0d CROP=%0d",W,DW,CROP);
 end
endmodule

module ramopt_window7_case #(parameter W=1280)(
 input clk,rst_n,input integer cycle);
 localparam STRIDE=W+24,FRAME=STRIDE*14;
 integer phase,row,col,valid_count=0;reg fs,de,bit_i;reg[10:0]x;reg[9:0]y;
 wire[48:0]wa,wb;wire va,vb;wire[10:0]xa,xb;wire[9:0]ya,yb;
 always @*begin
  phase=cycle%FRAME;row=phase/STRIDE;col=phase%STRIDE;
  fs=phase==0;de=col>=12&&col<12+W;
  if(cycle>=24000&&cycle<42000&&col%37==0)de=0;
  x=de?col-12:0;y=row;bit_i=((cycle*37)^(cycle>>3)^row)&1;
 end
 ep1_window7 #(.WIDTH(W)) a(clk,rst_n,fs,de,x,y,bit_i,wa,va,xa,ya);
 ep1_window7_baseline #(.WIDTH(W)) b(clk,rst_n,fs,de,x,y,bit_i,wb,vb,xb,yb);
 always @(negedge clk)if(cycle>1)begin
  if({wa,va,xa,ya}!=={wb,vb,xb,yb})
   $fatal(1,"window7 mismatch W=%0d cycle=%0d",W,cycle);
  if(va)valid_count=valid_count+1;
  if(cycle==89999&&valid_count<100)$fatal(1,"window7 coverage missing W=%0d",W);
 end
endmodule

module ramopt_delay_case #(parameter B=19,L=6618)(
 input clk,rst_n,input integer cycle);
 reg[B-1:0]din;wire[B-1:0]a,b;
 always @*din=(64'h81b9b639adc5913d*cycle)^(cycle>>3);
 video_delay #(.BITS(B),.LATENCY(L)) dut(clk,rst_n,din,a);
 video_delay_baseline #(.BITS(B),.LATENCY(L)) ref_dut(clk,rst_n,din,b);
 always @(negedge clk)if(cycle>1&&a!==b)
  $fatal(1,"delay mismatch BITS=%0d LATENCY=%0d cycle=%0d a=%h b=%h",B,L,cycle,a,b);
endmodule

module tb_ramopt_buffers;
 reg clk=0,rst_n=0;integer cycle=0;
 always #5 clk=~clk;
 always @(posedge clk)cycle<=cycle+1;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  wait(cycle==19003);#2;rst_n=0;#17;rst_n=1;
  wait(cycle==45017);#2;rst_n=0;#23;rst_n=1;
  wait(cycle==90000);@(negedge clk);
  $display("PASS: RAM buffers exact equivalence; 90000 clocks, 9 line configurations, 3 window7 widths, 14 delay configurations; DE gaps, cropped coordinates, wraparound, asynchronous mid-stream resets");
  $finish;
 end
 ramopt_line_case #(.DW(1)) l1(clk,rst_n,cycle);
 ramopt_line_case #(.DW(2)) l2(clk,rst_n,cycle);
 ramopt_line_case #(.DW(8)) l8(clk,rst_n,cycle);
 ramopt_line_case #(.DW(12)) l12(clk,rst_n,cycle);
 ramopt_line_case #(.DW(14)) l14(clk,rst_n,cycle);
 ramopt_line_case #(.DW(1),.W(319)) l319(clk,rst_n,cycle);
 ramopt_line_case #(.DW(2),.W(640)) l640(clk,rst_n,cycle);
 ramopt_line_case #(.DW(1),.CROP(3)) lc1(clk,rst_n,cycle);
 ramopt_line_case #(.DW(14),.CROP(3)) lc14(clk,rst_n,cycle);
 ramopt_window7_case #(.W(1280)) w1280(clk,rst_n,cycle);
 ramopt_window7_case #(.W(640)) w640(clk,rst_n,cycle);
 ramopt_window7_case #(.W(319)) w319(clk,rst_n,cycle);
 ramopt_delay_case #(.B(19),.L(6618)) d19(clk,rst_n,cycle);
 ramopt_delay_case #(.B(8),.L(6617)) d8(clk,rst_n,cycle);
 ramopt_delay_case #(.B(9),.L(4963)) d9(clk,rst_n,cycle);
 ramopt_delay_case #(.B(3),.L(8267)) d3g(clk,rst_n,cycle);
 ramopt_delay_case #(.B(3),.L(3309)) d3m(clk,rst_n,cycle);
 ramopt_delay_case #(.B(1),.L(6616)) d1h(clk,rst_n,cycle);
 ramopt_delay_case #(.B(1),.L(3309)) d1s(clk,rst_n,cycle);
 ramopt_delay_case #(.B(8),.L(1024)) dt1024(clk,rst_n,cycle);
 ramopt_delay_case #(.B(8),.L(1025)) dt1025(clk,rst_n,cycle);
 ramopt_delay_case #(.B(8),.L(1536)) dt1536(clk,rst_n,cycle);
 ramopt_delay_case #(.B(8),.L(2048)) dt2048(clk,rst_n,cycle);
 ramopt_delay_case #(.B(20),.L(1025)) dt20(clk,rst_n,cycle);
 ramopt_delay_case #(.B(48),.L(6618)) dt48(clk,rst_n,cycle);
 ramopt_delay_case #(.B(1),.L(16)) dt16(clk,rst_n,cycle);
 initial begin #1000000;$fatal(1,"RAM equivalence timeout");end
endmodule
