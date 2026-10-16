`timescale 1ns/1ps
module tb_gesture_plus;
 reg clk=0,rst=0,en=1,fs=0,de=0,bit_i=0,bv=1;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[41:0]box={10'd159,10'd20,11'd119,11'd30};
 wire fv;wire[41:0]fb;wire[2:0]one,two,many,cls;reg[9:0]fill=500;reg[19:0]ratio=1500;
 gesture_features dut(clk,rst,en,fs,de,bit_i,x,y,bv,box,fv,fb,one,two,many);
 gesture_shape shape(fv,fill,ratio,one,two,many,cls);
 integer xx,yy;
 task probe(input integer kind,input[2:0]expected);begin
  @(negedge clk);fs=1;@(negedge clk);fs=0;
  for(yy=0;yy<180;yy=yy+1)for(xx=0;xx<160;xx=xx+1)begin
   @(negedge clk);de=1;x=xx;y=yy;
   case(kind)
    1:bit_i=(xx>=35&&xx<47)||(xx>=57&&xx<69)||(xx>=79&&xx<91)||(xx>=101&&xx<113);
    2:bit_i=xx>=30&&xx<=119;
    3:bit_i=xx>=67&&xx<81;
    4:bit_i=(xx>=44&&xx<59)||(xx>=91&&xx<106);
    5:bit_i=(yy>=25&&yy<43)||(yy>=60&&yy<78)||(yy>=95&&yy<113)||(yy>=130&&yy<148);
    default:bit_i=(xx%10)==0; // isolated noise cannot count as a finger
   endcase
  end
  @(negedge clk);de=0;fs=1;@(negedge clk);fs=0;#1;
  if(!fv||fb!=box||cls!=expected)$fatal(1,"Probe kind=%0d class=%0d expected=%0d votes=%0d/%0d/%0d",kind,cls,expected,one,two,many);
 end endtask
 reg fd=0,fault=0,rv=1;reg[41:0]rb;reg[2:0]rc=1;wire sv;wire[41:0]sb;wire[2:0]sg;
 gesture_stabilizer st(clk,rst,en,fd,fault,rv,rb,rc,sv,sb,sg);
 task tick(input integer centre,input[2:0]c,input valid_i);begin
  @(negedge clk);rv=valid_i;rc=c;rb={10'd450,10'd200,11'(centre+99),11'(centre-100)};fd=1;
  @(negedge clk);fd=0;#1;
 end endtask
 integer i;
 initial begin
  rb={10'd450,10'd200,11'd549,11'd350};repeat(4)@(negedge clk);rst=1;
  fill=500;ratio=1500;probe(1,1);probe(4,4);ratio=2300;probe(3,3);ratio=550;probe(5,1);
  fill=950;ratio=1000;probe(2,2);fill=400;ratio=1500;probe(0,0);
  for(i=0;i<4;i=i+1)begin tick(450,1,1);if(sg!=0)$fatal(1,"Early palm confirmation");end
  tick(450,1,1);if(sg!=1)$fatal(1,"Palm 5/7 vote");
  tick(450,0,1);if(sg!=1)$fatal(1,"Single uncertain frame flicker");
  for(i=0;i<40;i=i+1)begin tick(450+(i%3)*4,1,1);if(sg==5)$fatal(1,"Jitter caused wave");end
  tick(530,1,1);tick(570,1,1);tick(480,1,1);tick(400,1,1);tick(490,1,1);
  if(sg!=5)$fatal(1,"Two large palm reversals did not wave");
  for(i=0;i<7;i=i+1)tick(490,4,1);if(sg!=4)$fatal(1,"V confirmation/wave cancel");
  tick(950,4,1);if(sg!=0)$fatal(1,"New target inherited prior votes");
  for(i=0;i<5;i=i+1)tick(950,4,1);if(sg!=4)$fatal(1,"Reacquisition");
  tick(950,0,0);tick(950,0,0);tick(950,0,0);if(sv||sg)$fatal(1,"Removal left a gesture");
  for(i=0;i<7;i=i+1)tick(450,2,1);if(sg!=2)$fatal(1,"Fist confirmation");
  @(negedge clk);fault=1;@(negedge clk);if(sv||sg)$fatal(1,"Fault did not clear");fault=0;
  for(i=0;i<7;i=i+1)tick(450,3,1);en=0;repeat(2)@(negedge clk);if(sv||sg)$fatal(1,"Disable did not clear");
  $display("PASS: finger topology / V / fist / index, isolated noise, target-aware 5-of-7 vote, jitter reject, two-reversal wave, new-target reset, removal, fault and disable");$finish;
 end
endmodule
