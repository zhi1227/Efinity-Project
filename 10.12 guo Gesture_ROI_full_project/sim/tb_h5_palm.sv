`timescale 1ns/1ps
module tb_h5_palm;
 reg clk=0,rst=0,en=1,sd=0,sv=1;reg[255:0]bmp=0;wire done,v,p;wire[7:0]lean;
 always #5 clk=~clk;
 gesture_palm_evidence dut(clk,rst,en,sd,sv,bmp,done,v,p,lean);
 reg[255:0]open,side,thumb,heart,fist,noise;integer r,c;integer expected,total,moment;
 task sample(input[255:0]b,input bit palm_expected);begin
  @(negedge clk);bmp=b;sd=1;@(negedge clk);sd=0;repeat(40)@(negedge clk);
  if(p!==palm_expected)$fatal(1,"Palm evidence %b expected%b rows%0d cols%0d solid%0d/%0d",p,palm_expected,dut.row_fingers,dut.col_fingers,dut.solid_rows,dut.solid_cols);
  if(sv)begin
   total=0;moment=0;for(r=0;r<8;r=r+1)for(c=0;c<16;c=c+1)if(b[r*16+c])begin total=total+1;moment=moment+c;end
   if(total!=0&&lean!==(moment*16/total))$fatal(1,"Lean centroid %0d expected%0d",lean,moment*16/total);
  end
 end endtask
 initial begin
  open=0;side=0;thumb=0;heart=0;fist=0;noise=0;
  for(r=0;r<16;r=r+1)for(c=0;c<16;c=c+1)begin
   open[r*16+c]=(r>=8&&c>=1&&c<15)||(r<8&&c%4<2);
   thumb[r*16+c]=(r<8&&c>=1&&c<5)||(r>=8&&c>=1&&c<15);
   heart[r*16+c]=(r<5&&((c>=4&&c<7)||(c>=10&&c<13)))||(r>=5&&r<8&&c>=4&&c<13)||(r>=8&&c>=1&&c<15);
   fist[r*16+c]=r>2&&r<14&&c>2&&c<14;noise[r*16+c]=(r+c)%2;
  end
  for(r=0;r<16;r=r+1)for(c=0;c<16;c=c+1)side[r*16+c]=open[c*16+r];
  repeat(3)@(negedge clk);rst=1;
  sample(open,1);sample(side,1);sample(thumb,0);sample(heart,0);sample(fist,0);sample(noise,0);sample(0,0);
  sv=0;sample(open,0);if(v)$fatal(1,"Invalid feature valid");
  $display("PASS: independent upright/sideways open-palm evidence, exact upper-hand centroid, thumb/heart/fist/checkerboard/empty/invalid rejection");$finish;
 end
endmodule
