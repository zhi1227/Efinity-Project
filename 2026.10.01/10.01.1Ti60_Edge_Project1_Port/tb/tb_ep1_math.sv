`timescale 1ns/1ps
module tb_ep1_math;
 reg clk=0;always #5 clk=~clk;reg rst=0,vi=0;reg[71:0]w=0;reg[7:0]t=0;
 wire[7:0]med;wire mv,sv,s,p;wire[10:0]mx,sx;wire[9:0]my,sy;
 ep1_median median(clk,rst,vi,11'd8,10'd9,w,med,mv,mx,my);
 ep1_gradient grad(clk,rst,vi,11'd8,10'd9,w,t,s,p,sv,sx,sy);
 reg[91:0]vectors[0:1999];integer idx=-1,k,errors=0,checked=0;
 always @(posedge clk)if(rst)begin
  #1;
  if(idx>=2&&idx<2002)begin
   k=idx-2;
   if({mv,med,mx,my}!=={1'b1,vectors[k][9:2],11'd8,10'd9})begin errors=errors+1;if(errors<5)$display("median case %0d",k);end
   checked=checked+1;
  end
  if(idx>=3&&idx<2003)begin
   k=idx-3;
   if({sv,s,p,sx,sy}!=={1'b1,vectors[k][1:0],11'd8,10'd9})begin errors=errors+1;if(errors<5)$display("gradient case %0d",k);end
   checked=checked+1;
  end
 end
 initial begin
  $readmemh("tb/neighborhoods.hex",vectors);
  repeat(5)@(negedge clk);rst=1;
  for(integer j=0;j<2004;j=j+1)begin
   idx=j;vi=j<2000;
   if(vi)begin w=vectors[j][89:18];t=vectors[j][17:10];end
   @(negedge clk);
  end
  if(errors||checked!=4000)$fatal(1,"FAIL math errors=%0d checked=%0d",errors,checked);
  $display("PASS 2000 median and 2000 L2 Sobel/Prewitt random neighborhoods");$finish;
 end
endmodule
