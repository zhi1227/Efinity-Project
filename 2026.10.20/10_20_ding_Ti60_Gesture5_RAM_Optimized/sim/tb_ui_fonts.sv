`timescale 1ns/1ps
module tb_ui_fonts;
 reg hc=0,lc=0;always #5 hc=~hc;always #7 lc=~lc;
 reg[5:0]hl=0,hi=0,ll=0,li=0;reg[3:0]hr=0,lr=0;
 wire[12:0]ha,la;wire[15:0]hb,lb,hshared,lshared,hlocal,llocal;
 shared_glyph_rom rom(hc,ha,hb,lc,la,lb);
 vision6_glyph_rom #(.SHARED_FONT(1)) h(hc,hl,hi,hr,hshared,ha,hb);
 vision6_glyph_rom href(hc,hl,hi,hr,hlocal,,16'd0);
 menu_glyph_rom #(.SHARED_FONT(1)) l(lc,ll,li,lr,lshared,la,lb);
 menu_glyph_rom lref(lc,ll,li,lr,llocal,,16'd0);
 integer nh=0,nl=0;reg hd=0,ld=0;
 initial begin
  for(integer n=0;n<65536;n=n+1)begin
   @(negedge hc);{hl,hi,hr}=n;@(posedge hc);#1;
   if(hshared!==hlocal||^hshared===1'bx)$fatal(1,"HDMI font mismatch %d",n);nh=nh+1;
  end
  hd=1;
 end
 initial begin
  for(integer n=0;n<65536;n=n+1)begin
   @(negedge lc);{ll,li,lr}=n;@(posedge lc);#1;
   if(lshared!==llocal||^lshared===1'bx)$fatal(1,"LVDS font mismatch %d",n);nl=nl+1;
  end
  ld=1;
 end
 initial begin
  wait(hd&&ld);$display("PASS: all 64 lines x 64 characters x 16 rows per display, shared dual-clock/local parity: HDMI %d LVDS %d",nh,nl);$finish;
 end
endmodule
