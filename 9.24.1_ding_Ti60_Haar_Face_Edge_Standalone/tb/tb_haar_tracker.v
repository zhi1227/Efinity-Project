`timescale 1ns/1ps
module tb_haar_tracker;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,fs=0,rv=0;reg [3:0] count=0;reg [335:0] boxes=0;
 wire [3:0] dc;wire [335:0] db;wire [7:0] mask;wire busy,overrun;
 haar_box_tracker dut(clk,rst_n,fs,rv,count,boxes,dc,db,mask,busy,overrun);
 function [41:0] box;input [10:0] x0;input [9:0] y0;input [9:0] size;
 reg [10:0] x1;reg [9:0] y1;
 begin x1=x0+size-1;y1=y0+size-1;box={y1,y0,x1,x0};end endfunction
 task result;input [3:0] n;input [335:0] b;
 begin
  if(busy)$fatal(1,"FAIL test attempted overlapping results");
  @(negedge clk);rv=1;count=n;boxes=b;
  @(negedge clk);rv=0;repeat(120)@(negedge clk);
 end endtask
 task frame;
 begin @(negedge clk);fs=1;@(negedge clk);fs=0;repeat(3)@(negedge clk);end endtask
 reg old_fs;reg [335:0] old_boxes=0;reg [7:0] old_mask=0;reg [3:0] old_count=0;
 always @(posedge clk)if(rst_n)begin
  old_fs=fs;#1;
  if((db!=old_boxes||mask!=old_mask||dc!=old_count)&&!old_fs)$fatal(1,"FAIL display changed mid-frame");
  old_boxes=db;old_mask=mask;old_count=dc;
 end
 integer n;reg [335:0] b;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  result(0,0);frame;if(dc!=0)$fatal(1,"FAIL blank spawned a face");
  b=0;b[0+:42]=box(100,100,192);b[42+:42]=box(700,200,192);
  result(2,b);if(dc!=0)$fatal(1,"FAIL early publish");frame;
  if(dc!=2||mask!=8'h03||db!=b)$fatal(1,"FAIL first face acquisition");
  result(0,0);repeat(5)begin frame;if(dc!=2||db!=b)$fatal(1,"FAIL dropout flicker");end
  $display("PASS empty detections preserve boxes during bounded dropout");
  b=0;b[0+:42]=box(720,220,192);b[42+:42]=box(110,110,192);
  result(2,b);frame;
  if(dc!=2||mask!=8'h03||db[0+:42]!=box(105,105,192)||db[42+:42]!=box(710,210,192))$fatal(1,"FAIL association or smoothing");
  $display("PASS candidate order reversal preserves associations, coordinates smoothed by one half");
  for(n=1;n<=36;n=n+1)begin
   if(n%10==0)begin b=0;b[0+:42]=box(720,220,192);result(1,b);end
   frame;
   if(n<36&&!mask[0])$fatal(1,"FAIL early timeout");
  end
  if(dc!=1||mask!=8'h02)$fatal(1,"FAIL disappearing face retained alongside visible face");
  $display("PASS each face ages independently; sparse second slot stays visible");
  repeat(36)frame;
  if(dc!=0||mask!=0||db!=0)$fatal(1,"FAIL boxes survived timeout without detector results");
  b=0;for(n=0;n<8;n=n+1)b[n*42+:42]=box(n*120,100,80);
  result(8,b);frame;if(dc!=8||mask!=8'hff)$fatal(1,"FAIL capacity");
  b=0;b[0+:42]=box(1150,500,80);result(1,b);frame;
  if(!overrun||dc!=8)$fatal(1,"FAIL capacity guard");
  repeat(36)frame;result(1,b);frame;
  if(dc!=1||db[0+:42]!=b[0+:42])$fatal(1,"FAIL expired-slot reuse");
  // The old box may expire after it was matched but before APPLY executes.
  // The matcher must preserve those coordinates, not average against cleared RAM.
  repeat(35)frame;
  @(negedge clk);rv=1;count=1;boxes=b;
  @(negedge clk);rv=0;
  wait(dut.state==1&&dut.scan_index==7);frame;
  repeat(4)@(negedge clk);frame;
  if(dc!=1||db[0+:42]!=b[0+:42])$fatal(1,"FAIL association spanning expiry boundary");
  $display("PASS timeout, capacity guard, reacquisition, expiry race and frame-atomic publication");
  $display("PASS tb_haar_tracker");$finish;
 end
 initial begin #1000000;$fatal(1,"FAIL tracker timeout");end
endmodule
