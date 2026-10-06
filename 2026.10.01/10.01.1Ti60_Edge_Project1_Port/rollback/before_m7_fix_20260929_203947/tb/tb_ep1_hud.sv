`timescale 1ns/1ps
module tb_ep1_hud;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0;reg[19:0]number=0;
 wire[23:0]digits;reg[10:0]x=0;reg[9:0]y=0;wire area,ink;
 ep1_decimal dec(clk,rst,start,number,digits);
 ep1_hud hud(x,y,3'd7,8'd105,2'd2,digits,area,ink);
 wire[34:0]plus;hand_font pf(8'h2b,plus);
 task convert(input integer v,input[23:0]want);
  begin @(negedge clk);number=v;start=1;@(negedge clk);start=0;
   repeat(22)@(negedge clk);if(digits!==want)$fatal(1,"BCD %0d got %h expected %h",v,digits,want);end
 endtask
 integer fd,xx,yy;
 initial begin
  repeat(4)@(negedge clk);rst=1;
  convert(0,24'h000000);convert(999999,24'h999999);convert(250,24'h000250);
  if(plus==0)$fatal(1,"missing plus glyph");
  x=8;y=0;#1;if(hud.ch!="M")$fatal(1,"missing mode label");
  x=8+17*16;#1;if(hud.ch!="1")$fatal(1,"threshold hundreds");
  x=8+18*16;#1;if(hud.ch!="0")$fatal(1,"threshold tens");
  x=8+19*16;#1;if(hud.ch!="5")$fatal(1,"threshold ones");
  x=8;y=32;#1;if(hud.ch!="R")$fatal(1,"truncated rule caption");
  fd=$fopen("reports/hud_preview.ppm","w");$fwrite(fd,"P3\n1040 48\n255\n");
  for(yy=0;yy<48;yy=yy+1)for(xx=0;xx<1040;xx=xx+1)begin
   x=xx;y=yy;#1;
   if(ink)$fwrite(fd,"255 255 255\n");else $fwrite(fd,"16 16 32\n");
  end
  $fclose(fd);$display("PASS decimal conversion, HUD labels, threshold digits and plus glyph; emitted RTL preview");$finish;
 end
endmodule
