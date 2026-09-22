`timescale 1ns/1ps
module tb_modular_video;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg [23:0] rgb=0;reg de=0,vs=0,hs=1;
 wire [23:0] out;wire od,ov,oh;wire[3:0] count;wire overrun;
 localparam W=64,H=48,HT=84;
 face_canny_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut
 (clk,rst,rgb,de,vs,hs,out,od,ov,oh,count,overrun);
 integer im[0:W*H-1],med[0:W*H-1],mag[0:W*H-1],dir[0:W*H-1];
 integer nm[0:W*H-1],cls[0:W*H-1],ed[0:W*H-1],sorter[0:8];
 integer x,y,i,j,k,a,b,gx,gy,ax,ay,rr,gg,bb,pix,frame;
 integer checked=0,edges=0,alignerrors=0,errors=0,valids=0;
 reg checking=0;
 function [23:0] pattern;
 input integer xx,yy,ff;
 integer v;
 begin
   if(ff==1) pattern=0;
   else if(ff==2) pattern=(((xx*7+yy*3)%256)<<16)|(((xx*3+yy*5)%256)<<8)|((xx+yy*11)%256);
   else if(ff==3) begin
     v=(xx>yy?160:80);
     if((xx*19+yy*7)%31==0) v=255;
     pattern={v[7:0],v[7:0],v[7:0]};
   end else begin
     v=((xx>12 && xx<40 && yy>8 && yy<38)?200:24);
     if((xx*13+yy*17)%89==0) v=255-v;
     pattern={v[7:0],v[7:0],v[7:0]};
   end
 end
 endfunction
 task model;
 input integer ff;
 begin
 for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
   pix=pattern(x,y,ff);rr=(pix>>19)&31;gg=(pix>>10)&63;bb=(pix>>3)&31;
   rr=(rr<<3)|(rr>>2);gg=(gg<<2)|(gg>>4);bb=(bb<<3)|(bb>>2);
   im[y*W+x]=(77*rr+150*gg+29*bb)>>8;
   med[y*W+x]=0;mag[y*W+x]=0;nm[y*W+x]=0;cls[y*W+x]=0;ed[y*W+x]=0;
 end
 for(y=1;y<H-1;y=y+1) for(x=1;x<W-1;x=x+1) begin
   k=0;for(j=-1;j<=1;j=j+1) for(i=-1;i<=1;i=i+1) begin sorter[k]=im[(y+j)*W+x+i];k=k+1;end
   for(i=0;i<9;i=i+1) for(j=i+1;j<9;j=j+1)
     if(sorter[i]>sorter[j]) begin a=sorter[i];sorter[i]=sorter[j];sorter[j]=a;end
   med[y*W+x]=sorter[4];
 end
 for(y=2;y<H-2;y=y+1) for(x=2;x<W-2;x=x+1) begin
   gx=med[(y-1)*W+x+1]+2*med[y*W+x+1]+med[(y+1)*W+x+1]
     -med[(y-1)*W+x-1]-2*med[y*W+x-1]-med[(y+1)*W+x-1];
   gy=med[(y+1)*W+x-1]+2*med[(y+1)*W+x]+med[(y+1)*W+x+1]
     -med[(y-1)*W+x-1]-2*med[(y-1)*W+x]-med[(y-1)*W+x+1];
   ax=gx<0?-gx:gx;ay=gy<0?-gy:gy;mag[y*W+x]=ax+ay;
   dir[y*W+x]=(ax>=2*ay)?0:(ay>=2*ax)?2:((gx<0)==(gy<0))?1:3;
 end
 for(y=3;y<H-3;y=y+1) for(x=3;x<W-3;x=x+1) begin
   case(dir[y*W+x])
    0:begin a=mag[y*W+x-1];b=mag[y*W+x+1];end
    2:begin a=mag[(y-1)*W+x];b=mag[(y+1)*W+x];end
    1:begin a=mag[(y-1)*W+x-1];b=mag[(y+1)*W+x+1];end
    3:begin a=mag[(y-1)*W+x+1];b=mag[(y+1)*W+x-1];end
   endcase
   nm[y*W+x]=(mag[y*W+x]>=a && mag[y*W+x]>=b)?mag[y*W+x]:0;
   cls[y*W+x]=nm[y*W+x]>=64?2:nm[y*W+x]>=24?1:0;
 end
 for(y=4;y<H-4;y=y+1) for(x=4;x<W-4;x=x+1) begin
   a=0;for(j=-1;j<=1;j=j+1) for(i=-1;i<=1;i=i+1)
     if(cls[(y+j)*W+x+i]==2) a=1;
   ed[y*W+x]=cls[y*W+x]==2 || (cls[y*W+x]==1 && a);
 end
 end
 endtask
 always @(posedge clk) begin
 #1;
 if(rst && checking && dut.cv) begin
   valids=valids+1;
   if(dut.ex<4 || dut.ex>=W-4 || dut.ey<4 || dut.ey>=H-4) begin
     $display("FAIL crop %d,%d",dut.ex,dut.ey);errors=errors+1;
   end else begin
     checked=checked+1;
     if(dut.ce!==ed[dut.ey*W+dut.ex][0]) begin
       if(errors<5) $display("FAIL edge %d,%d got %b expected %d",dut.ex,dut.ey,dut.ce,ed[dut.ey*W+dut.ex]);
       errors=errors+1;
     end
   end
   if(dut.ce) edges=edges+1;
   if(!dut.ade || dut.ex!==dut.ax || dut.ey!==dut.ay) begin
     if(alignerrors<5) $display("FAIL align edge=%d,%d delayed=%d,%d de=%b",dut.ex,dut.ey,dut.ax,dut.ay,dut.ade);
     alignerrors=alignerrors+1;
   end
 end
 end
 initial begin
 repeat(4) @(negedge clk);rst=1;
 for(frame=0;frame<4;frame=frame+1) begin
   checking=0;vs=0;de=0;repeat(HT*8) @(negedge clk);
   model(frame);vs=1;checking=1;repeat(HT*8) @(negedge clk);
   for(y=0;y<H;y=y+1) begin
     for(x=0;x<HT;x=x+1) begin
       de=x<W;rgb=pattern(x,y,frame);@(negedge clk);
     end
   end
   de=0;rgb=0;repeat(HT*8) @(negedge clk);
 end
 if(checked!=4*(W-8)*(H-8) || errors || alignerrors || edges==0)
   $fatal(1,"VIDEO FAIL checked=%d errors=%d align=%d edges=%d",checked,errors,alignerrors,edges);
 $display("PASS video: %0d golden pixels, %0d edge pixels, coordinate alignment, second blank frame",checked,edges);
 $finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
