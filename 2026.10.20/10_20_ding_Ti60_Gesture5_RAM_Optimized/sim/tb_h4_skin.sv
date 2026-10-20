`timescale 1ns/1ps
module tb_h4_skin;
 reg clk=0,rst=0,de=0,fs=0,sample=0,clear=0;reg[10:0]x=0;reg[9:0]y=0;reg[23:0]rgb=0;
 always #5 clk=~clk;
 wire mask,v,f,cal,done,ok;wire[10:0]xo;wire[9:0]yo;
 gesture_skin_learn #(.WIDTH(128),.HEIGHT(96))dut(clk,rst,de,fs,x,y,rgb,8'd10,sample,clear,mask,v,f,xo,yo,cal,done,ok);
 integer xx,yy;
 task tick(input integer n);repeat(n)@(negedge clk);endtask
 task colour(input[23:0]col,input bit expected);begin de=1;rgb=col;tick(4);if(mask!==expected)$fatal(1,"Mask RGB%h got%b expected%b",col,mask,expected);de=0;tick(3);end endtask
 task capture(input[23:0]col);begin
  fs=1;tick(1);fs=0;sample=1;tick(1);sample=0;tick(4);
  for(yy=32;yy<64;yy=yy+1)for(xx=40;xx<72;xx=xx+1)begin de=1;x=xx;y=yy;rgb=col;tick(1);end
  de=0;tick(4);fs=1;tick(1);fs=0;tick(4);
 end endtask
 initial begin
  tick(3);rst=1;colour(24'hE6D6C9,1);colour(24'hFFFFFF,0);colour(24'h204080,0);
  capture(24'hFFFFFF);if(ok||cal)$fatal(1,"White background calibration accepted");
  capture(24'hC88C6E);if(!ok||!cal)$fatal(1,"Palm calibration failed %0d",dut.count);
  colour(24'hC88C6E,1);colour(24'hE6D6C9,1);colour(24'h80604E,1);
  colour(24'hD0D0D0,0);colour(24'h204080,0);colour(24'h101010,0);
  clear=1;tick(1);clear=0;if(cal)$fatal(1,"Clear calibration");
  $display("PASS: pale fingertip, palm and shadow segmentation; skin calibration; white/blue/dark background rejection");$finish;
 end
endmodule
