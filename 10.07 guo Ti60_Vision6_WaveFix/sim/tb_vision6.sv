`timescale 1ns/1ps
module tb_vision6;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 reg[23:0]rgb=0;reg de=0,vs=0,hs=0;reg[3:0]mode=0;reg pure_en=0,detect=0;
 wire[23:0]out;wire od,ov,oh,overrun,frozen;wire[3:0]committed;
 parallel_video #(.HUD_ENABLE(0),.CANNY_GAUSSIAN(1),.GESTURE_DEBUG(1)) dut(
 .clk(clk),.rst_n(rst_n),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),
 .mode_i(mode),.low_i(12'd40),.high_i(12'd80),.rgb_o(out),.de_o(od),.vs_o(ov),.hs_o(oh),
 .overrun(overrun),.freeze_i(1'b0),.mode_committed_o(committed),.frozen_committed_o(frozen),
 .pure_i(pure_en),.detect_i(detect),.skin_lower_i(8'd10),.health_i(8'hFF),.gesture_short_i(1'b0),.gesture_long_i(1'b0));
 function[23:0]scene(input integer x,input integer y);
 reg[15:0]p;integer dx,dy;
 begin
  dx=x-380;dy=y-360;
  p=16'h19AA;
  if(x>=100&&x<240&&y>=180&&y<600)p=16'hF800;
  if(dx*dx+dy*dy<10000)p=16'hFFE0;
  if(x>=640&&x<980&&y>=200&&y<560)p=16'h07FF;
  if(x>=720&&x<900&&y>=280&&y<480)p=16'h0000;
  if(x>1080&&y>480)p=16'h07E0;
  if(y>=650&&y<660)p=16'hFFFF;
  scene={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};
 end endfunction
 reg canny_mem[0:921599];integer frame=-1,count=0,nonzero=0,changed=0,fd=0,xx,yy,h,v,m;reg[23:0]expected;
 integer ids[0:6];
 always @(negedge clk)if(rst_n&&od&&frame>=0)begin
   if(count>=921600)$fatal(1,"Too many active pixels");
   xx=count%1280;yy=count/1280;
   if(^out===1'bx)$fatal(1,"Unknown pixel frame=%0d xy=%0d,%0d",frame,xx,yy);
   if(out!=0)nonzero=nonzero+1;
   if(out!=scene(xx,yy))changed=changed+1;
   if(frame==0||frame==6)begin
     if(out!==scene(xx,yy))$fatal(1,"Raw/pure_en alignment failed frame=%0d xy=%0d,%0d got=%h expected=%h",frame,xx,yy,out,scene(xx,yy));
   end
   if(frame==1)begin
     if(out!==24'hFFFFFF&&out!==24'd0)$fatal(1,"Canny is not binary");
     canny_mem[count]=(out!=0);
   end
   if(frame==2&&out!==24'hFF0000&&out!==scene(xx,yy))$fatal(1,"Sobel overlay changes unrelated pixel");
   if(frame==4)begin
     expected=xx==640?24'h00FFFF:(xx<640?scene(xx,yy):{24{canny_mem[count]}});
     if(out!==expected)$fatal(1,"Same-frame split mismatch at %0d,%0d",xx,yy);
   end
   $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);count=count+1;
 end
 initial begin
   ids[0]=0;ids[1]=1;ids[2]=10;ids[3]=9;ids[4]=14;ids[5]=15;ids[6]=15;
   repeat(6)@(posedge clk);#1;rst_n=1;
   for(m=0;m<7;m=m+1)begin
     frame=m;count=0;changed=0;nonzero=0;mode=ids[m];pure_en=(m==6);detect=(m==6);
     fd=$fopen($sformatf("reports/hdmi_%0d.ppm",m),"wb");$fwrite(fd,"P6\n1280 720\n255\n");
     for(v=0;v<750;v=v+1)for(h=0;h<1650;h=h+1)begin
       @(posedge clk);#1;vs=v>=3;hs=h>=40;de=v>=25&&v<745&&h>=260&&h<1540;
       rgb=de?scene(h-260,v-25):24'd0;
     end
     @(posedge clk);#1;de=0;
     if(count!=921600)$fatal(1,"Wrong active raster %0d frame %0d",count,m);
     if((m==1||m==3)&&nonzero<100)$fatal(1,"Edge mode is black");
     if(m==2&&changed<100)$fatal(1,"Sobel red edges missing");
     if(m==5&&dut.gesture!==0)$fatal(1,"Unknown/first hand frame triggered avatar");
     $fclose(fd);$display("PASS: 720p frame %0d mode %0d pure_en=%0d pixels=%0d nonzero=%0d changed=%0d",m,mode,pure_en,count,nonzero,changed);
   end
   $display("PASS: six modes, full raster, same-image split, pure_en capture and unknown idle");$finish;
 end
 initial begin #200000000;$fatal(1,"Timeout");end
endmodule
