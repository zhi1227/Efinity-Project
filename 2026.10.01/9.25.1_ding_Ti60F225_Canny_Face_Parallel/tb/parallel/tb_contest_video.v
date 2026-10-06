`timescale 1ns/1ps
// Independent frame-domain math: raw/median Sobel, Gaussian Canny (local hys),
// saturated intensity, all neon bins, original-color overlay, noise comparison.
module tb_contest_video;
 localparam W=128,H=64,HT=160,D=4*(HT+1)+14,N=W*H;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,vs=0,hs=1;reg [23:0] rgb=0;reg [3:0] mode=8;
 wire [23:0] q;wire od,ov,oh,overrun;
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT),.CANNY_GAUSSIAN(1)) dut(
 .clk(clk),.rst_n(rst),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),.mode_i(mode),
 .low_i(12'd40),.high_i(12'd80),.rgb_o(q),.de_o(od),.vs_o(ov),.hs_o(oh),.overrun(overrun),.freeze_i(1'b0));
 integer gray[0:N-1],med[0:N-1],gauss[0:N-1],rawmag[0:N-1],medmag[0:N-1];
 integer gmag[0:N-1],dir[0:N-1],cls[0:N-1],ce[0:N-1];
 reg [23:0] source_rgb[0:N-1];reg [26:0] pipe[0:D];reg [23:0] expected=0;
 integer f,x,y,k,pixels=0,frame_mode,edge_pixels=0,gray_bins[0:4];reg checking=0;
 function [23:0] sample;
 input integer px,py,fn;reg [7:0] r,g,b;
 begin
 r=(px*3+py*2)&255;g=(px+py*3)&255;b=(px*2+py)&255;
 sample={r,g,b};
 if(px>=32 && px<72 && py>=16 && py<48)sample=24'heeeeee;
 if((px*17+py*19)%71==0)sample=24'hffffff;
 if((px*13+py*11)%97==0)sample=0;
 if(fn==6)sample=0;
 end endfunction
 task reference;
 input integer fn;integer xx,yy,i,j,u,v,n,r,g,b,gx,gy,a,bn,tmp,s;
 integer vals[0:8];reg [23:0] c;
 begin
 for(yy=0;yy<H;yy=yy+1)for(xx=0;xx<W;xx=xx+1)begin
 i=yy*W+xx;c=sample(xx,yy,fn);
 r=((c[23:16]>>3)<<3)|(c[23:16]>>5);g=((c[15:8]>>2)<<2)|(c[15:8]>>6);b=((c[7:0]>>3)<<3)|(c[7:0]>>5);
 source_rgb[i]={r[7:0],g[7:0],b[7:0]};gray[i]=(77*r+150*g+29*b)>>8;
 med[i]=0;gauss[i]=0;rawmag[i]=0;medmag[i]=0;gmag[i]=0;dir[i]=0;cls[i]=0;ce[i]=0;
 end
 for(yy=1;yy<H-1;yy=yy+1)for(xx=1;xx<W-1;xx=xx+1)begin
 i=yy*W+xx;n=0;s=0;
 for(v=-1;v<=1;v=v+1)for(u=-1;u<=1;u=u+1)begin
 vals[n]=gray[(yy+v)*W+xx+u];n=n+1;
 s=s+gray[(yy+v)*W+xx+u]*((u==0)?2:1)*((v==0)?2:1);
 end
 gauss[i]=(s+8)>>4;
 for(n=0;n<8;n=n+1)for(j=n+1;j<9;j=j+1)if(vals[j]<vals[n])begin tmp=vals[n];vals[n]=vals[j];vals[j]=tmp;end
 med[i]=vals[4];
 gx=gray[i-W+1]+2*gray[i+1]+gray[i+W+1]-gray[i-W-1]-2*gray[i-1]-gray[i+W-1];
 gy=gray[i+W-1]+2*gray[i+W]+gray[i+W+1]-gray[i-W-1]-2*gray[i-W]-gray[i-W+1];
 rawmag[i]=((gx<0)?-gx:gx)+((gy<0)?-gy:gy);
 end
 for(yy=2;yy<H-2;yy=yy+1)for(xx=2;xx<W-2;xx=xx+1)begin
 i=yy*W+xx;
 gx=med[i-W+1]+2*med[i+1]+med[i+W+1]-med[i-W-1]-2*med[i-1]-med[i+W-1];
 gy=med[i+W-1]+2*med[i+W]+med[i+W+1]-med[i-W-1]-2*med[i-W]-med[i-W+1];
 medmag[i]=((gx<0)?-gx:gx)+((gy<0)?-gy:gy);
 gx=gauss[i-W+1]+2*gauss[i+1]+gauss[i+W+1]-gauss[i-W-1]-2*gauss[i-1]-gauss[i+W-1];
 gy=gauss[i+W-1]+2*gauss[i+W]+gauss[i+W+1]-gauss[i-W-1]-2*gauss[i-W]-gauss[i-W+1];
 a=(gx<0)?-gx:gx;bn=(gy<0)?-gy:gy;gmag[i]=a+bn;
 dir[i]=(a>=2*bn)?0:((bn>=2*a)?2:(((gx<0)==(gy<0))?1:3));
 end
 for(yy=3;yy<H-3;yy=yy+1)for(xx=3;xx<W-3;xx=xx+1)begin
 i=yy*W+xx;
 case(dir[i])
 0:begin a=gmag[i-1];bn=gmag[i+1];end
 1:begin a=gmag[i-W-1];bn=gmag[i+W+1];end
 2:begin a=gmag[i-W];bn=gmag[i+W];end
 3:begin a=gmag[i-W+1];bn=gmag[i+W-1];end
 endcase
 if(gmag[i]>a && gmag[i]>=bn)cls[i]=(gmag[i]>=80)?2:((gmag[i]>=40)?1:0);
 end
 for(yy=4;yy<H-4;yy=yy+1)for(xx=4;xx<W-4;xx=xx+1)begin
 i=yy*W+xx;s=0;
 for(v=-1;v<=1;v=v+1)for(u=-1;u<=1;u=u+1)if(cls[(yy+v)*W+xx+u]==2)s=1;
 ce[i]=(cls[i]==2)||(cls[i]==1 && s);
 end
 end endtask
 function [23:0] expected_pixel;
 input integer px,py,m;integer i,s;reg [23:0] c;
 begin
 i=py*W+px;s=(rawmag[i]>255)?255:rawmag[i];c=0;
 case(m)
 8:c={s[7:0],s[7:0],s[7:0]};
 9:begin
 if(s<24)c=0;else if(s<64)c={8'd0,s[7:0],s[5:0],2'b0};
 else if(s<128)c=24'h00ffff;else if(s<192)c={s[7:0],8'h20,8'hff};else c=24'hff40e0;
 end
 10:c=(rawmag[i]>=40)?24'hff0000:source_rgb[i];
 11:c=(px==W/2)?24'h00ffff:((px<W/2)?{gray[i][7:0],gray[i][7:0],gray[i][7:0]}:{med[i][7:0],med[i][7:0],med[i][7:0]});
 13:begin s=(medmag[i]>255)?255:medmag[i];c={s[7:0],s[7:0],s[7:0]};end
 1:c=ce[i]?24'hffffff:0;
 12:c=(px>=W/4 && px<W*3/4 && py>=H/4 && py<H*3/4 && (px==W/4 || px==W*3/4-1 || py==H/4 || py==H*3/4-1))?24'h00ffff:0;
 5:c=(px==W/2)?24'h00ffff:((px<W/2)?{gray[i][7:0],gray[i][7:0],gray[i][7:0]}:((medmag[i]>=40)?24'hffffff:0));
 endcase
 expected_pixel=c;
 end endfunction
 always @(posedge clk)begin
 if(!rst)begin for(k=0;k<=D;k=k+1)pipe[k]=0;end
 else begin
 for(k=D;k>0;k=k-1)pipe[k]=pipe[k-1];pipe[0]={vs,hs,de,expected};
 #1;
 if(checking && {ov,oh,od,q}!==pipe[D])$fatal(1,"new raster mismatch frame=%0d mode=%0d ax=%0d ay=%0d got=%h expected=%h",f,frame_mode,dut.ax,dut.ay,{ov,oh,od,q},pipe[D]);
 if(checking && od)pixels=pixels+1;
 if(dut.cv && (!dut.ade || dut.ex!=dut.ax || dut.ey!=dut.ay))$fatal(1,"Gaussian Canny coordinate skew");
 end end
 task tick;begin @(negedge clk);end endtask
 initial begin
 for(k=0;k<5;k=k+1)gray_bins[k]=0;
 repeat(5)tick;rst=1;repeat(D+8)tick;checking=1;
 for(f=0;f<8;f=f+1)begin
 case(f)0:frame_mode=8;1:frame_mode=9;2:frame_mode=10;3:frame_mode=11;4:frame_mode=13;5:frame_mode=1;6:frame_mode=12;7:frame_mode=5;endcase
 mode=frame_mode;de=0;vs=0;rgb=0;expected=0;reference(f);
 repeat(HT*8)tick;vs=1;repeat(HT*2)tick;
 for(y=0;y<H;y=y+1)for(x=0;x<HT;x=x+1)begin
 de=x<W;hs=x>=W+4;rgb=de?sample(x,y,f):0;expected=de?expected_pixel(x,y,frame_mode):0;
 if(de && f==5 && ce[y*W+x])edge_pixels=edge_pixels+1;
 if(de && f==1)begin
 if(rawmag[y*W+x]<24)gray_bins[0]=gray_bins[0]+1;
 else if(rawmag[y*W+x]<64)gray_bins[1]=gray_bins[1]+1;
 else if(rawmag[y*W+x]<128)gray_bins[2]=gray_bins[2]+1;
 else if(rawmag[y*W+x]<192)gray_bins[3]=gray_bins[3]+1;
 else gray_bins[4]=gray_bins[4]+1;
 end
 if(x==W/2 && y==H/2)mode=0; // request must not affect current display frame
 tick;end
 de=0;rgb=0;expected=0;repeat(HT*8)tick;
 $display("PASS new mode %0d independent pixel reference",frame_mode);
 end
 if(pixels!=8*N || edge_pixels==0)$fatal(1,"missing frame or Canny coverage");
 for(k=0;k<5;k=k+1)if(gray_bins[k]==0)$fatal(1,"neon bin missing %d",k);
 $display("PASS contest full raster %0d pixels; Gaussian local-Canny edges=%0d; Sobel/median/neon/overlay/ROI/commit",pixels,edge_pixels);
 $finish;
 end
 initial begin #3000000;$fatal(1,"contest timeout");end
endmodule
