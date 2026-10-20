`timescale 1ns/1ps
// Focused integration rendering: actual/shared glyph paths, new 14-character
// status label, A/B bitmap, crop boundaries and unchanged two-register DE.
module tb_canny_menu;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,visible=0;reg[10:0]x=0;reg[9:0]y=0;reg[639:0]state=0;
 wire[23:0]rgb,local_rgb;wire de,local_de;wire[12:0]address;wire[15:0]bits;
 shared_glyph_rom rom(clk,13'd0,,clk,address,bits);
 menu8_renderer #(.SHARED_FONT(1)) dut(clk,reset,x,y,visible,state,rgb,de,address,bits,1'b0);
 menu8_renderer #(.SHARED_FONT(0)) local_dut(clk,reset,x,y,visible,state,local_rgb,local_de,,16'd0,1'b0);
 integer px,py,s,fd,count,ink_pixels,total=0;
 integer qx=0,qy=0,cx,cy,col,row,index;
 reg qv=0,cv,expected_ink;reg[111:0]expected_label;
 reg[34:0]ab_bitmap;reg[23:0]expected_color;
 always @(posedge clk)begin
  cx=qx;cy=qy;cv=qv;qx=x;qy=y;qv=visible;
  if(!reset&&visible&&x>=56&&x<224&&y>=520&&y<534)begin
   index=(x-56)/12;
   if(dut.canny_label!==expected_label || dut.canny_character!==expected_label[111-index*8-:8])
    $fatal(1,"Canny status string/character index mismatch x=%0d index=%0d",x,index);
  end
  #1;
  if(reset)begin qv=0;end
  else begin
   if(de!==cv)$fatal(1,"Menu DE latency changed");
   if(rgb!==local_rgb||de!==local_de)$fatal(1,"SHARED_FONT/local parity mismatch");
   if(de)begin
    if(^rgb===1'bx)$fatal(1,"Unknown menu RGB");
    $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);count=count+1;total=total+1;
    // First mode-specific character: A or B, slot6. Canonical 5x7 reference.
    if(cx>=128&&cx<140&&cy>=520&&cy<534)begin
     ab_bitmap=state[124]?35'b01110_10001_10001_11111_10001_10001_10001:
       35'b11110_10001_10001_11110_10001_10001_11110;
     col=(cx-128)/2;row=(cy-520)/2;
     expected_ink=col<5?ab_bitmap[34-row*5-col]:1'b0;
     expected_color=expected_ink?(state[124]?24'h65dbab:24'hafc3dc):24'h132336;
     if(rgb!==expected_color)$fatal(1,"A/B bitmap position/color mismatch %0d,%0d",cx,cy);
     if(expected_ink)ink_pixels=ink_pixels+1;
    end
    if((cx==55||cx==224)&&cy>=520&&cy<534&&rgb!==24'h112234)
     $fatal(1,"Status label exceeds 56..223 bounds");
   end
  end
 end
 initial begin
  repeat(4)@(negedge clk);reset=0;
  for(s=0;s<4;s=s+1)begin
   state=0;state[2:0]=1;state[48:37]=40;state[60:49]=80;
   state[123]=s>=2;state[124]=s%2;
   expected_label=state[124]?"CANNY ADAPTIVE":"CANNY BASELINE";
   if($bits(expected_label)!=112)$fatal(1,"Expected status label must be exactly 14 characters");
   fd=$fopen($sformatf("report/menu_label_%0d.ppm",s),"wb");
   if(!fd)$fatal(1,"Cannot open menu PPM");
   $fwrite(fd,"P6\n196 28\n255\n");count=0;ink_pixels=0;
   for(py=512;py<540;py=py+1)for(px=40;px<236;px=px+1)begin
    x=px;y=py;visible=1;@(negedge clk);
   end
   visible=0;repeat(4)@(negedge clk);
   $fclose(fd);
   if(count!=196*28)$fatal(1,"Menu label pixel count mismatch %0d",count);
   if(ink_pixels<60)$fatal(1,"Missing A/B status glyph");
   $display("PASS scenario %0d settings=%0d adaptive=%0d pixels=%0d A/B ink=%0d",s,state[123],state[124],count,ink_pixels);
  end
  $display("PASS: Canny menu labels exact14chars A/B glyph bounds DE shared/local parity total=%0d",total);
  $finish;
 end
endmodule
