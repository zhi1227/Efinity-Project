`timescale 1ns/1ps
module tb_hand_branch;
 reg clk=0,rst=0,en=1,de=0,vs=0,hs=0,vsq=0;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov,sk,sv;wire[41:0]box;wire[1:0]g;
 raster_xy #(.WIDTH(128)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(128),.HEIGHT(96),.H_TOTAL(160))dut(clk,rst,en,rgb,de,vs,hs,vs&&!vsq,x,y,8'd10,bv,box,g,ov,sk,sv,,,,,,,);
 integer n,v,h,xx,yy;
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(n=0;n<7;n=n+1)begin
   for(v=0;v<120;v=v+1)for(h=0;h<160;h=h+1)begin
    @(posedge clk);#1;vs=v>=3;hs=h>=4;de=v>=15&&v<111&&h>=12&&h<140;
    xx=h-12;yy=v-15;
    rgb=de&&n<5&&xx>=34&&xx<94&&yy>=18&&yy<78?24'hC88C6E:24'h204080;
   end
   if(n>=3&&n<5)begin
    if(!bv||ov||g!=2)$fatal(1,"Skin/CCL branch failed at frame %0d: bv=%b g=%d overflow=%b",n,bv,g,ov);
    if(box[10:0]!=34||box[21:11]!=93||box[31:22]!=18||box[41:32]!=77)$fatal(1,"Skin raster/box misalignment: %h",box);
   end
   if(n==6&&(bv||g!=0))$fatal(1,"Removed hand retained");
  end
  en=0;repeat(3)@(posedge clk);#1;if(bv||g!=0)$fatal(1,"Disabled hand retained");
  $display("PASS: RGB skin -> 7x7 majority -> opening -> aligned CCL -> stable fist; removal and disable clear");$finish;
 end
endmodule
