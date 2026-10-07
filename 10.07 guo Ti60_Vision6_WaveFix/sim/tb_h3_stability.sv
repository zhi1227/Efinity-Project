`timescale 1ns/1ps
module tb_h3_stability;
 reg clk=0,rst=0,en=1,fd=0,fault=0,rv=1;always #5 clk=~clk;
 reg[41:0]rb;reg[2:0]rc=1;wire sv;wire[41:0]sb;wire[2:0]sg;
 gesture_stabilizer st(clk,rst,en,fd,fault,rv,rb,rc,sv,sb,sg);
 task tick(input integer centre,input[2:0]c,input valid_i);begin
  @(negedge clk);rv=valid_i;rc=c;rb={10'd450,10'd200,11'(centre+99),11'(centre-100)};fd=1;
  @(negedge clk);fd=0;#1;
 end endtask
 integer i;
 initial begin
  rb={10'd450,10'd200,11'd549,11'd350};repeat(4)@(negedge clk);rst=1;
  for(i=0;i<4;i=i+1)begin tick(450,2,1);if(sg!=0)$fatal(1,"Early thumb confirmation");end
  tick(450,2,1);if(sg!=2)$fatal(1,"Thumb 5/7 vote");
  tick(450,0,1);if(sg!=2)$fatal(1,"Single uncertain frame flicker");
  for(i=0;i<8;i=i+1)tick(450,1,1);if(sg!=0)$fatal(1,"Static palm became wave");
  for(i=0;i<40;i=i+1)begin tick(450+(i%3)*4,1,1);if(sg)$fatal(1,"Jitter caused wave");end
  tick(530,1,1);tick(570,1,1);tick(480,1,1);tick(400,1,1);tick(490,1,1);
  if(sg!=1)$fatal(1,"Two palm reversals did not wave");
  for(i=0;i<7;i=i+1)tick(490,3,1);if(sg!=3)$fatal(1,"Heart confirmation/wave cancel");
  tick(950,3,1);if(sg!=0)$fatal(1,"New target inherited votes");
  for(i=0;i<5;i=i+1)tick(950,3,1);if(sg!=3)$fatal(1,"Reacquisition");
  tick(950,0,0);tick(950,0,0);tick(950,0,0);if(sv||sg)$fatal(1,"Removal left a gesture");
  for(i=0;i<7;i=i+1)tick(450,2,1);if(sg!=2)$fatal(1,"Thumb confirmation");
  @(negedge clk);fault=1;@(negedge clk);if(sv||sg)$fatal(1,"Fault did not clear");fault=0;
  for(i=0;i<7;i=i+1)tick(450,3,1);en=0;repeat(2)@(negedge clk);if(sv||sg)$fatal(1,"Disable did not clear");
  $display("PASS: only 3 output IDs, 5-of-7 vote, static palm/jitter rejection, two-reversal wave, target reset, removal/fault/disable clearing");$finish;
 end
endmodule
