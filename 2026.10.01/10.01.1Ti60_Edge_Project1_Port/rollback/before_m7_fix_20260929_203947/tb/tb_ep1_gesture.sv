`timescale 1ns/1ps
module tb_ep1_gesture;
 reg clk=0;always #5 clk=~clk;reg rst=0,fs=0,en=1,de=0,bit_i=0;
 reg[10:0]x=0;reg[9:0]y=0;wire valid,done;wire[10:0]xmin,xmax;wire[9:0]ymin,ymax;
 wire[19:0]f;wire[1:0]g;reg cv=1;reg[19:0]cf;wire[1:0]cg;
 ep1_gesture dut(clk,rst,fs,en,de,bit_i,x,y,valid,xmin,xmax,ymin,ymax,f,g,done);
 ep1_classify classify(cv,cf,cg);
 task boundary;begin fs=1;@(negedge clk);fs=0;repeat(30)@(negedge clk);end endtask
 task check_class(input integer value,input integer label);
  begin cf=value;#1;if(cg!==label[1:0])$fatal(1,"class boundary F=%0d expected=%0d got=%0d",value,label,cg);end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;boundary;
  if(valid||f!=0||g!=0)$fatal(1,"empty scene");
  // Rectangle [10..29] x [4..13]: 19*9/(1+20+1+10) = 5.
  for(integer yy=0;yy<20;yy=yy+1)for(integer xx=0;xx<40;xx=xx+1)begin
   de=1;x=xx;y=yy;bit_i=xx>=10&&xx<=29&&yy>=4&&yy<=13;@(negedge clk);
  end
  de=0;bit_i=0;boundary;
  if(!valid||xmin!=10||xmax!=29||ymin!=4||ymax!=13||f!=5||g!=3)
   $fatal(1,"bbox/division F=%0d box=%0d,%0d,%0d,%0d G=%0d",f,xmin,xmax,ymin,ymax,g);
  boundary;if(valid||f!=0||g!=0)$fatal(1,"target removal retained stale result");
  de=1;bit_i=1;x=0;y=0;@(negedge clk);de=0;bit_i=0;boundary;
  if(valid||f!=0)$fatal(1,"degenerate zero area");
  check_class(0,3);check_class(199,3);check_class(200,0);check_class(220,0);
  check_class(221,2);check_class(279,2);check_class(280,0);check_class(300,0);check_class(301,1);
  cv=0;#1;if(cg!=0)$fatal(1,"invalid classification");
  $display("PASS gesture original feature, bbox, division, empty/removed/degenerate target and strict class boundaries");$finish;
 end
endmodule
