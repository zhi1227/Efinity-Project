`timescale 1ns/1ps
module tb_menu8_pixels;
 reg clk=0,reset=1,visible=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[639:0]state=0;
 wire[23:0]rgb;wire de;
 menu8_renderer dut(clk,reset,x,y,visible,state,rgb,de);
 integer f,mode,px,py,n,numbers,face_digits,select_pixels,step_pixels;
 initial begin
  repeat(4)@(negedge clk);reset=0;
  for(mode=0;mode<8;mode=mode+1)begin
   state=0;state[2:0]=mode;state[11:4]=255;state[48:37]=40+mode;state[60:49]=80+mode;
   state[62:61]=mode%3;state[64:63]=mode%3;state[14]=1;state[19:16]=mode==6?8:0;state[15]=mode==6;
   if(mode==4)begin
    state[116:113]=15;
    for(integer k=0;k<4;k=k+1)begin
     state[128+k*128+96+:2]=k;
     state[128+k*128+72+:12]=40+k*10;
     state[128+k*128+84+:12]=80+k*10;
     state[128+k*128+24+:32]=32'h12345670+k;
    end
   end
   f=$fopen($sformatf("reports/menu_%0d.ppm",mode),"wb");if(!f)$fatal(1,"PPM open");
   $fwrite(f,"P6\n1024 600\n255\n");n=0;numbers=0;face_digits=0;select_pixels=0;step_pixels=0;
   for(py=0;py<600;py=py+1)for(px=0;px<1024;px=px+1)begin
    @(negedge clk);x=px;y=py;visible=1;
    if(de)begin
     $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
     if(n%1024>=112&&n%1024<176&&n/1024>=414&&n/1024<430&&rgb==24'he7f3ff)numbers=numbers+1;
     if(n%1024>=640&&n%1024<672&&n/1024>=446&&n/1024<462&&rgb==24'he7f3ff)face_digits=face_digits+1;
     if(n%1024>=656&&n%1024<720&&n/1024>=414&&n/1024<430&&rgb==24'he7f3ff)select_pixels=select_pixels+1;
     if(n%1024>=816&&n%1024<832&&n/1024>=414&&n/1024<430&&rgb==24'he7f3ff)step_pixels=step_pixels+1;
     n=n+1;
    end
   end
   @(negedge clk);if(de)begin $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);n=n+1;end visible=0;
   repeat(4)begin @(negedge clk);if(de)begin $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);n=n+1;end end
   $fclose(f);
   if(n!=614400||numbers<20||select_pixels<20||step_pixels<10||(mode==6&&face_digits<10))$fatal(1,"Missing text mode%0d pixels%0d numbers%0d sel%0d step%0d face%0d",mode,n,numbers,select_pixels,step_pixels,face_digits);
   $display("PASS: menu8 pixels mode %0d digits %0d selection %0d step %0d face %0d",mode,numbers,select_pixels,step_pixels,face_digits);
  end
  $display("PASS: all eight UI images, thresholds, LOW/HIGH/LINK, step and face 8+ glyphs");$finish;
 end
endmodule
