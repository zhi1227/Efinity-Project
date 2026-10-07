// HDMI preview of an 8x8 LED matrix. Each bitmap row is left-to-right MSB first.
// This module does not drive physical WS2812 hardware.
module gesture_matrix8(input[10:0]x,input[9:0]y,input[2:0]gesture,input phase,
 output reg paint,output reg[23:0]colour);
 wire panel=x>=1024&&x<1264&&y>=64&&y<312;
 wire grid=x>=1048&&x<1240&&y>=92&&y<284;
 wire[10:0]gx=x-1048;wire[9:0]gy=y-92;
 wire[2:0]column=gx/24,row=gy/24;
 wire dot=(gx%24)>=3&&(gx%24)<21&&(gy%24)>=3&&(gy%24)<21;
 reg[63:0]bitmap;
 always @*begin
  case(gesture)
   1:bitmap=64'h545454567F7F3E1C; // open hand / WAVE
   2:bitmap=64'h1818181F7F7F7E3C; // THUMB UP
   3:bitmap=64'h66FFFFFF7E3C1800; // HEART
   default:bitmap=0;
  endcase
  paint=panel;colour=24'h12151C;
  if(grid&&dot)begin
   colour=24'h30343D;
   if(bitmap[63-{row,column}])colour=(gesture==1&&phase)?24'hFFEAA0:24'hFFCB55;
  end
 end
endmodule
