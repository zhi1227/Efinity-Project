`timescale 1ns/1ps
module tb_face_overlay;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[23:0]rgb=24'h123456;reg de=0,vs=0,hs=1,edge_pixel=0;
 reg[10:0]x=0;reg[9:0]y=0;reg[3:0]count=0;reg[335:0]boxes=0;
 wire[23:0]color,bw;wire cd,cv,ch,bd,bv,bh;
 face_canny_overlay #(.DISPLAY_MODE(0)) a(clk,rst,rgb,de,vs,hs,x,y,edge_pixel,count,boxes,color,cd,cv,ch);
 face_canny_overlay #(.DISPLAY_MODE(1)) b(clk,rst,rgb,de,vs,hs,x,y,edge_pixel,count,boxes,bw,bd,bv,bh);
 task check;
 input [23:0]ec,eb;
 begin @(posedge clk);#1;
 if(color!==ec || bw!==eb || cd!==de || bd!==de || cv!==vs || ch!==hs)
   $fatal(1,"overlay mismatch color %h bw %h",color,bw);
 @(negedge clk);
 end endtask
 initial begin
 repeat(4) @(negedge clk);rst=1;
 boxes[41:0]={10'd29,10'd10,11'd29,11'd10};count=1;
 check(0,0);vs=1;check(0,0);
 de=1;x=5;y=5;check(24'h123456,0);
 edge_pixel=1;check(24'h123456,24'hffffff);
 x=15;y=15;check(24'h00ffff,24'hffffff);
 x=10;check(24'hff3030,24'hff3030);
 count=0;boxes=0;check(24'hff3030,24'hff3030);
 de=0;vs=0;check(0,0);vs=1;check(0,0);
 de=1;check(24'h123456,24'hffffff);
 $display("PASS overlay: color preservation, cyan local contour, B/W edge, red box, frame-atomic clear");
 $finish;
 end
endmodule
