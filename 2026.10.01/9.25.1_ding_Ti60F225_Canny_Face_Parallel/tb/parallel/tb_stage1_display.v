`timescale 1ns/1ps
// Independent image-domain reference, not a comparison against DUT debug signals.
// Covers RGB565 quantization, grayscale, signed skin, median/Sobel, binary morphology,
// exact raster latency, reset/blanking, frame-boundary controls and parameter propagation.
module tb_stage1_display;
 localparam W=128,H=64,HT=160,D=4*(HT+1)+14,N=W*H;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,vs=0,hs=1;reg[23:0]rgb=0;reg[3:0]mode=3;
 reg[11:0]low=40,high=80;
 wire[23:0]q,qa;wire od,ov,oh,overrun,ad,av,ah,ao;
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT)) dut(
 .clk(clk),.rst_n(rst),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),.mode_i(mode),
 .low_i(low),.high_i(high),.rgb_o(q),.de_o(od),.vs_o(ov),.hs_o(oh),.overrun(overrun));
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT),.MAX_FACES(2),
 .SKIN_CB_MIN(0),.SKIN_CB_MAX(255),.SKIN_CR_MIN(0),.SKIN_CR_MAX(255),.SKIN_Y_MIN(0),.SKIN_Y_MAX(255),
 .FACE_CELL_MIN(1),.FACE_MIN_W(8),.FACE_MIN_H(8),.FACE_MAX_W(W),.FACE_MAX_H(H),
 .FACE_MIN_AREA(64),.FACE_MIN_FILL_PERCENT(1),.FACE_MIN_RATIO_X10(1),.FACE_MAX_RATIO_X10(40)) all_skin(
 .clk(clk),.rst_n(rst),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),.mode_i(mode),
 .low_i(low),.high_i(high),.rgb_o(qa),.de_o(ad),.vs_o(av),.hs_o(ah),.overrun(ao));
 integer gray[0:N-1],med[0:N-1];reg raw[0:N-1],maj[0:N-1],clean[0:N-1],sobel[0:N-1];
 reg[26:0]pipe[0:D],pipe_all[0:D];reg[23:0]expected=0,expected_all=0;
 integer pi,x,y,f,frame_mode,frame_low,pixels=0,seen_raw=0,seen_clean=0,seen_sobel=0;
 reg checking=0;
 function[23:0] sample;
 input integer px,py,fn;
 reg[7:0]r,g,b;
 begin
 case(fn%4)
 0:begin
  r=(px*13+py*7)&255;g=(px*3+py*17)&255;b=(px*23+py*5)&255;
  sample={r,g,b};
  if((px>=24 && px<88 && py>=12 && py<52)||(px<8 && py<8)||(px>=W-8 && py>=H-8))sample=24'hce9e7b;
 end
 1:sample=(px>=W*3/4)?24'hffffff:((py>=H/2 && px>=16 && px<40)?24'hff0000:24'h183052);
 2:sample=24'hce9e7b;
 default:sample=0;
 endcase
 end
 endfunction
 task make_reference;
 input integer fn,threshold;
 integer xx,yy,i,j,k,u,v,r,g,b,cb,cr,total,gx,gy,tmp;
 integer values[0:8];reg[23:0]c;
 begin
 for(yy=0;yy<H;yy=yy+1)for(xx=0;xx<W;xx=xx+1)begin
  i=yy*W+xx;c=sample(xx,yy,fn);
  r=((c[23:16]>>3)<<3)|(c[23:16]>>5);
  g=((c[15:8]>>2)<<2)|(c[15:8]>>6);
  b=((c[7:0]>>3)<<3)|(c[7:0]>>5);
  gray[i]=(77*r+150*g+29*b)>>8;
  cb=128+((-43*r-85*g+128*b)>>>8);
  cr=128+((128*r-107*g-21*b)>>>8);
  raw[i]=(gray[i]>=40 && gray[i]<=235 && cb>=77 && cb<=127 && cr>=133 && cr<=173);
  maj[i]=0;clean[i]=0;med[i]=0;sobel[i]=0;
 end
 for(yy=1;yy<H-1;yy=yy+1)for(xx=1;xx<W-1;xx=xx+1)begin
  total=0;k=0;
  for(v=-1;v<=1;v=v+1)for(u=-1;u<=1;u=u+1)begin
   total=total+raw[(yy+v)*W+xx+u];values[k]=gray[(yy+v)*W+xx+u];k=k+1;
  end
  maj[yy*W+xx]=(total>=5);
  for(i=0;i<8;i=i+1)for(j=i+1;j<9;j=j+1)
   if(values[j]<values[i])begin tmp=values[i];values[i]=values[j];values[j]=tmp;end
  med[yy*W+xx]=values[4];
 end
 for(yy=2;yy<H-2;yy=yy+1)for(xx=2;xx<W-2;xx=xx+1)begin
  total=0;
  for(v=-1;v<=1;v=v+1)for(u=-1;u<=1;u=u+1)total=total+maj[(yy+v)*W+xx+u];
  clean[yy*W+xx]=(total==9);
  gx=med[(yy-1)*W+xx+1]+2*med[yy*W+xx+1]+med[(yy+1)*W+xx+1]
     -med[(yy-1)*W+xx-1]-2*med[yy*W+xx-1]-med[(yy+1)*W+xx-1];
  gy=med[(yy+1)*W+xx-1]+2*med[(yy+1)*W+xx]+med[(yy+1)*W+xx+1]
     -med[(yy-1)*W+xx-1]-2*med[(yy-1)*W+xx]-med[(yy-1)*W+xx+1];
  if(gx<0)gx=-gx;if(gy<0)gy=-gy;
  sobel[yy*W+xx]=(gx+gy>=threshold);
 end
 end
 endtask
 always @(posedge clk)begin
 if(!rst)begin for(pi=0;pi<=D;pi=pi+1)begin pipe[pi]=0;pipe_all[pi]=0;end end
 else begin
  for(pi=D;pi>0;pi=pi-1)begin pipe[pi]=pipe[pi-1];pipe_all[pi]=pipe_all[pi-1];end
  pipe[0]={vs,hs,de,expected};pipe_all[0]={vs,hs,de,expected_all};
  #1;
  if(checking)begin
   if({ov,oh,od,q}!==pipe[D])$fatal(1,"stage1 raster/image mismatch f=%0d got=%h exp=%h",f,{ov,oh,od,q},pipe[D]);
   if({av,ah,ad,qa}!==pipe_all[D])$fatal(1,"all-skin config/image mismatch f=%0d got=%h exp=%h",f,{av,ah,ad,qa},pipe_all[D]);
   if(od)pixels=pixels+1;
   if(overrun || ao)$fatal(1,"unexpected CCL overrun");
  end
 end
 end
 task tick;begin @(negedge clk);end endtask
 initial begin
 if(all_skin.u_regions.CELL_MIN!=1 || all_skin.u_regions.MIN_AREA!=64 ||
    all_skin.u_regions.MAX_RATIO_X10!=40 || all_skin.u_regions.MIN_FILL_PERCENT!=1)
   $fatal(1,"face config did not propagate");
 repeat(6)tick;rst=1;repeat(D+8)tick;checking=1;
 for(f=0;f<8;f=f+1)begin
  frame_mode=(f%3==0)?6:((f%3==1)?7:5);frame_low=40+8*f;
  mode=frame_mode;low=frame_low;high=2*frame_low;
  de=0;vs=0;rgb=0;expected=0;expected_all=0;
  make_reference(f,frame_low);
  repeat(HT*8)tick;vs=1;repeat(HT*2)tick;
  for(y=0;y<H;y=y+1)for(x=0;x<HT;x=x+1)begin
   de=(x<W);hs=(x>=W+4);rgb=de?sample(x,y,f):0;expected=0;expected_all=0;
   if(de)begin
    case(frame_mode)
    6:begin expected=raw[y*W+x]?24'hffffff:0;expected_all=24'hffffff;seen_raw=seen_raw+1;end
    7:begin expected=clean[y*W+x]?24'hffffff:0;
      expected_all=(x>=2 && x<W-2 && y>=2 && y<H-2)?24'hffffff:0;seen_clean=seen_clean+1;end
    5:begin
      if(x==W/2)expected=24'h00ffff;
      else if(x<W/2)expected={gray[y*W+x][7:0],gray[y*W+x][7:0],gray[y*W+x][7:0]};
      else expected=sobel[y*W+x]?24'hffffff:0;
      expected_all=expected;seen_sobel=seen_sobel+1;
    end
    endcase
   end
   // Mid-frame requests must not change either display mode or active thresholds.
   if(y==H/2 && x==W/2)begin mode=1;low=400;high=800;end
   tick;
  end
  de=0;rgb=0;expected=0;expected_all=0;repeat(HT*8)tick;
  $display("PASS stage1 frame=%0d mode=%0d threshold=%0d",f,frame_mode,frame_low);
 end
 if(pixels!=8*W*H || seen_raw==0 || seen_clean==0 || seen_sobel==0)$fatal(1,"missing pixel/mode coverage %0d",pixels);
 if(all_skin.count!=1)$fatal(1,"face geometry overrides not active: count %0d",all_skin.count);
 rst=0;repeat(4)tick;if(q!==0 || od!==0 || qa!==0)$fatal(1,"reset output");
 $display("PASS stage1 independent full-raster reference: %0d pixels; gray, raw/clean skin, Sobel, borders, frame commit, config, reset",pixels);
 $finish;
 end
 initial begin #3000000;$fatal(1,"timeout");end
endmodule
