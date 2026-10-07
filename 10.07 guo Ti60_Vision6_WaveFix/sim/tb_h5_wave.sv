`timescale 1ns/1ps
module tb_h5_wave;
 reg clk=0,rst=0,en=1,fd=0,fault=0,rv=1,lv=1;always #5 clk=~clk;
 reg[41:0]box;reg[2:0]raw=1;reg[7:0]lean=120;wire active;wire[2:0]phase;
 gesture_wave dut(clk,rst,en,fd,fault,rv,box,raw,lv,lean,active,phase);
 integer i;
 task f(input integer cx,input[2:0]c,input integer l,input bit valid_i);begin
  @(negedge clk);box={10'd500,10'd160,11'(cx+150),11'(cx-150)};raw=c;lean=l;rv=valid_i;fd=1;
  @(negedge clk);fd=0;#1;
 end endtask
 task reset;begin rst=0;repeat(3)@(negedge clk);rst=1;end endtask
 initial begin
  reset();for(i=0;i<30;i=i+1)begin f(600+i%3,1,120+i%4,1);if(active)$fatal(1,"Static palm/jitter wave");end
  // Each side is below the threshold relative to the starting midpoint,
  // but peak-to-peak is valid. Both ends must be remembered.
  f(600,1,130,1);f(600,1,109,1);if(active)$fatal(1,"Unreturned span triggered");
  f(600,1,130,1);if(!active)$fatal(1,"Middle-start wrist wave missed");
  reset();repeat(5)f(600,1,120,1);
  // Wrist rocking: bbox centre never moves. Old H4 could not see this wave.
  f(600,1,142,1);if(active||phase<2)$fatal(1,"One direction falsely triggered");
  f(600,0,150,1);f(600,0,150,1);f(600,1,120,1);if(!active)$fatal(1,"Wrist reversal with blur missed");
  f(600,2,120,1);if(active)$fatal(1,"Thumb failed to cancel wave");
  for(i=0;i<12;i=i+1)begin f(600+(i%2)*80,2,90+(i%2)*60,1);if(active)$fatal(1,"Moving thumb wave");end
  for(i=0;i<12;i=i+1)begin f(600+(i%2)*80,3,90+(i%2)*60,1);if(active)$fatal(1,"Moving heart wave");end
  // Three palm confirmations among five frames, then intermittent blur.
  reset();f(600,1,120,1);f(600,0,120,1);f(600,1,120,1);f(600,0,120,1);f(600,1,120,1);
  if(phase!=2)$fatal(1,"3/5 palm confirmation failed");
  for(i=0;i<15;i=i+1)begin f(600,i%3==0?1:0,120,1);if(phase<2||active)$fatal(1,"Intermittent palm lost or false wave");end
  f(600,1,144,1);f(600,0,148,1);f(600,1,120,1);if(!active)$fatal(1,"Intermittent wrist wave missed");
  reset();repeat(5)f(600,1,120,1);
  f(645,1,120,1);repeat(2)f(650,0,120,1);f(600,1,120,1);if(!active)$fatal(1,"Translation wave missed");
  f(600,0,120,0);f(600,0,120,0);f(600,0,120,0);if(active||phase)$fatal(1,"Absent hand retained wave");
  repeat(4)f(600,1,120,1);f(645,1,120,1);f(600,0,120,1);if(active)$fatal(1,"Unknown reversal generated event");
  reset();repeat(5)f(600,1,120,1);f(645,1,120,1);repeat(8)f(645,0,120,1);f(600,1,120,1);if(active)$fatal(1,"Stale palm event");
  reset();repeat(5)f(600,1,120,1);f(645,1,120,1);repeat(182)f(645,1,120,1);f(600,1,120,1);if(active)$fatal(1,"Expired sequence event");
  reset();repeat(5)f(600,1,120,1);f(645,1,120,1);f(1000,1,90,1);if(active)$fatal(1,"New target inherited motion");
  fault=1;@(negedge clk);if(active||phase)$fatal(1,"Fault clearing");fault=0;en=0;@(negedge clk);if(active||phase)$fatal(1,"Disable clearing");
  $display("PASS: wrist-only and translational wave, two blurred frames, static jitter/one-way/unknown/thumb/heart rejection, timeout, removal, target change and disable");$finish;
 end
endmodule
