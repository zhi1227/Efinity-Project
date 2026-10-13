`timescale 1ns/1ps
module tb_h4_templates;
 reg clk=0,rst=0,en=1,clear=0,sd=0,sv=1;reg[2:0]learn=0;reg[255:0]bmp=0;reg[19:0]ratio=1000;
 always #5 clk=~clk;
 wire done,cd,ok;wire[2:0]raw,trained;wire[1:0]err,count;wire[9:0]distance;
 gesture_templates dut(clk,rst,en,clear,learn,sd,sv,bmp,ratio,done,raw,trained,cd,ok,err,count,distance);
 reg[255:0]palm,thumb,heart;integer r,c,n;reg completed;
 always @(posedge clk)if(cd)completed=1;
 task tick(input integer t);repeat(t)@(negedge clk);endtask
 task sample(input[255:0]v);begin bmp=v;sd=1;tick(1);sd=0;tick(245);end endtask
 task record(input[2:0]id,input[255:0]v);begin completed=0;learn=id;tick(1);learn=0;sample(v);sample(v);sample(v);if(!completed||!ok||err)$fatal(1,"Recording %d failed err%0d dist %0d/%0d/%0d",id,err,dut.d1,dut.d2,dut.d3);end endtask
 initial begin
  palm=0;thumb=0;heart=0;
  for(r=0;r<16;r=r+1)for(c=0;c<16;c=c+1)begin
   palm[r*16+c]=(r>=8&&c>=1&&c<15)||(r<8&&c%4<2);
   thumb[r*16+c]=(r<8&&c>=1&&c<5)||(r>=8&&c>=1&&c<15);
   heart[r*16+c]=(r<5&&((c>=4&&c<7)||(c>=10&&c<13)))||(r>=5&&r<8&&c>=4&&c<13)||(r>=8&&c>=1&&c<15);
  end
  tick(3);rst=1;sample(thumb);if(raw||trained)$fatal(1,"Untrained response");
  record(1,palm);record(2,thumb);record(3,heart);if(trained!=7)$fatal(1,"Missing model");
  sample(palm);if(raw!=1)$fatal(1,"Palm mismatch %0d",raw);
  sample(thumb);if(raw!=2)$fatal(1,"Thumb mismatch %0d",raw);
  sample(heart);if(raw!=3)$fatal(1,"Heart mismatch %0d",raw);
  sample(heart^256'h100010001000100010001000100010);if(raw!=3)$fatal(1,"Sparse noise rejection too strong");
  bmp=0;for(r=0;r<16;r=r+1)bmp[r*16+:16]=thumb[r*16+:16]<<1;
  sample(bmp);if(raw!=2)$fatal(1,"One-cell translation");
  sample(0);if(raw)$fatal(1,"Empty false positive");sample(~256'd0);if(raw)$fatal(1,"Solid false positive");
  sample(~palm);if(raw)$fatal(1,"Out of distribution false positive");
  sv=0;sample(thumb);if(raw)$fatal(1,"Invalid candidate accepted");sv=1;
  en=0;tick(3);if(trained!=7||raw)$fatal(1,"Freeze erased model or kept result");en=1;sample(heart);if(raw!=3)$fatal(1,"Resume model lost");
  // Replacing HEART by an almost identical THUMB must fail, keeping old HEART.
  completed=0;learn=3;tick(1);learn=0;repeat(3)sample(thumb);
  if(!completed||ok||err!=2)$fatal(1,"Ambiguous enrolment not rejected");sample(heart);if(raw!=3)$fatal(1,"Failed enrolment destroyed model");
  clear=1;tick(1);clear=0;if(trained||raw)$fatal(1,"Clear failed");
  $display("PASS: personalized three-class enrollment, sparse noise/translation tolerance, unknown/solid/invalid rejection, ambiguity and freeze persistence");$finish;
 end
endmodule
