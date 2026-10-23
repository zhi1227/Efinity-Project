`timescale 1ns/1ps
module ramopt_line_case #(parameter W=1280,DW=1,CROP=0,ILLEGAL=0)(
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
  if(ILLEGAL&&col>=12+W&&col<20+W)begin de=1;x=col-12;end
  din=(cycle*37)^(cycle>>3)^(row*83);
 end
 line_buffer_3x3 #(.WIDTH(W),.DWIDTH(DW),.AWIDTH(11)) a(clk,rst_n,fs,de,x,y,din,wa,va,xa,ya);
 line_buffer_3x3_current #(.WIDTH(W),.DWIDTH(DW),.AWIDTH(11)) b(clk,rst_n,fs,de,x,y,din,wb,vb,xb,yb);
 always @(negedge clk)if(cycle>1)begin
  if({wa,va,xa,ya}!=={wb,vb,xb,yb})
   $fatal(1,"line mismatch W=%0d DW=%0d CROP=%0d cycle=%0d",W,DW,CROP,cycle);
  if(va)valid_count=valid_count+1;
  if(cycle==89999&&valid_count<100)
   $fatal(1,"line coverage missing W=%0d DW=%0d CROP=%0d",W,DW,CROP);
 end
endmodule

module tb_wide;
 reg clk=0,rst_n=0;integer cycle=0;always #5 clk=~clk;
 always @(posedge clk)cycle<=cycle+1;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  wait(cycle==19003);#2;rst_n=0;#17;rst_n=1;
  wait(cycle==45017);#2;rst_n=0;#23;rst_n=1;
  wait(cycle==90000);@(negedge clk);
  $display("PASS: wide banked line cycle-exact equivalence, 18 configurations, 90000 clocks; widths1/2/3/4/5/8/9/10/12/14, 1280/640/319 columns, sparse DE/crop/illegal columns/reset");$finish;
 end
 ramopt_line_case #(.W(1280),.DW(1),.CROP(0),.ILLEGAL(0)) l0(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(2),.CROP(0),.ILLEGAL(0)) l1(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(8),.CROP(0),.ILLEGAL(0)) l2(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(12),.CROP(0),.ILLEGAL(0)) l3(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(14),.CROP(0),.ILLEGAL(0)) l4(clk,rst_n,cycle);
 ramopt_line_case #(.W(319),.DW(1),.CROP(0),.ILLEGAL(0)) l5(clk,rst_n,cycle);
 ramopt_line_case #(.W(640),.DW(2),.CROP(0),.ILLEGAL(0)) l6(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(1),.CROP(3),.ILLEGAL(0)) l7(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(14),.CROP(3),.ILLEGAL(0)) l8(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(3),.CROP(0),.ILLEGAL(0)) l9(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(4),.CROP(0),.ILLEGAL(0)) l10(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(5),.CROP(0),.ILLEGAL(0)) l11(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(9),.CROP(0),.ILLEGAL(0)) l12(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(10),.CROP(0),.ILLEGAL(0)) l13(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(8),.CROP(3),.ILLEGAL(0)) l14(clk,rst_n,cycle);
 ramopt_line_case #(.W(319),.DW(8),.CROP(0),.ILLEGAL(0)) l15(clk,rst_n,cycle);
 ramopt_line_case #(.W(1280),.DW(8),.CROP(0),.ILLEGAL(1)) l16(clk,rst_n,cycle);
 ramopt_line_case #(.W(319),.DW(8),.CROP(0),.ILLEGAL(1)) l17(clk,rst_n,cycle);
 initial begin #1000000;$fatal(1,"wide line timeout");end
endmodule
