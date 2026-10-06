// Original Project1 YCbCr coefficients. Matched pixels, including skin test.
module ep1_color(input clk,rst_n,de,fs,input[10:0]x,input[9:0]y,
 input[23:0]rgb,input skin_enable,
 output reg[7:0]gray,processed,output reg valid,frame_start,
 output reg[10:0]xo,output reg[9:0]yo);
 reg[15:0]yr,yg,yb,crr,crg,crb,cbr,cbg,cbb;
 reg[15:0]ys,cbs,crs;reg[2:0]d,f,skin;
 reg[10:0]xx[0:1];reg[9:0]yy[0:1];integer i;
 always @(posedge clk)begin
  if(!rst_n)begin
   yr<=0;yg<=0;yb<=0;crr<=0;crg<=0;crb<=0;cbr<=0;cbg<=0;cbb<=0;
   ys<=0;cbs<=0;crs<=0;d<=0;f<=0;skin<=0;gray<=0;processed<=0;
   valid<=0;frame_start<=0;xo<=0;yo<=0;
   for(i=0;i<2;i=i+1)begin xx[i]<=0;yy[i]<=0;end
  end else begin
   yr<=rgb[23:16]*16'd77;yg<=rgb[15:8]*16'd150;yb<=rgb[7:0]*16'd29;
   cbr<=rgb[23:16]*16'd43;cbg<=rgb[15:8]*16'd85;cbb<=rgb[7:0]*16'd128;
   crr<=rgb[23:16]*16'd128;crg<=rgb[15:8]*16'd107;crb<=rgb[7:0]*16'd21;
   ys<=yr+yg+yb;cbs<=cbb-cbr-cbg+16'd32768;crs<=crr-crg-crb+16'd32768;
   gray<=ys[15:8];
   processed<=!skin[1]||(cbs[15:8]>77&&cbs[15:8]<127&&crs[15:8]>133&&crs[15:8]<173)?ys[15:8]:8'd0;
   d<={d[1:0],de};f<={f[1:0],fs};skin<={skin[1:0],skin_enable};
   xx[0]<=x;xx[1]<=xx[0];yy[0]<=y;yy[1]<=yy[0];
   valid<=d[1];frame_start<=f[1];xo<=xx[1];yo<=yy[1];
  end
 end
endmodule

// Exact median of nine: sorting network split over three registered stages.
module ep1_median(input clk,rst_n,vi,input[10:0]xi,input[9:0]yi,input[71:0]w,
 output reg[7:0]value,output reg vo,output reg[10:0]xo,output reg[9:0]yo);
 function[7:0]lo;input[7:0]a,b,c;begin lo=(a<b?(a<c?a:c):(b<c?b:c));end endfunction
 function[7:0]hi;input[7:0]a,b,c;begin hi=(a>b?(a>c?a:c):(b>c?b:c));end endfunction
 function[7:0]mid;input[7:0]a,b,c;begin mid=(a<b?(b<c?b:(a<c?c:a)):(a<c?a:(b<c?c:b)));end endfunction
 reg[7:0]l0,l1,l2,m0,m1,m2,h0,h1,h2,a,b,c;
 reg[1:0]v;reg[10:0]x0,x1;reg[9:0]y0,y1;
 always @(posedge clk)begin
  if(!rst_n)begin l0<=0;l1<=0;l2<=0;m0<=0;m1<=0;m2<=0;h0<=0;h1<=0;h2<=0;
   a<=0;b<=0;c<=0;v<=0;vo<=0;x0<=0;x1<=0;xo<=0;y0<=0;y1<=0;yo<=0;value<=0;end
  else begin
   l0<=lo(w[71:64],w[63:56],w[55:48]);m0<=mid(w[71:64],w[63:56],w[55:48]);h0<=hi(w[71:64],w[63:56],w[55:48]);
   l1<=lo(w[47:40],w[39:32],w[31:24]);m1<=mid(w[47:40],w[39:32],w[31:24]);h1<=hi(w[47:40],w[39:32],w[31:24]);
   l2<=lo(w[23:16],w[15:8],w[7:0]);m2<=mid(w[23:16],w[15:8],w[7:0]);h2<=hi(w[23:16],w[15:8],w[7:0]);
   a<=hi(l0,l1,l2);b<=mid(m0,m1,m2);c<=lo(h0,h1,h2);value<=mid(a,b,c);
   v<={v[0],vi};vo<=v[1];x0<=xi;x1<=x0;xo<=x1;y0<=yi;y1<=y0;yo<=y1;
  end
 end
endmodule

// Four stages: directional sums, absolute gradients, squared norm, threshold.
// floor(sqrt(S)) >= T iff S >= T*T for nonnegative integer T.
module ep1_gradient(input clk,rst_n,vi,input[10:0]xi,input[9:0]yi,
 input[71:0]w,input[7:0]threshold,
 output reg sobel,prewitt,vo,output reg[10:0]xo,output reg[9:0]yo);
 wire[9:0]p0={2'b0,w[71:64]},p1={2'b0,w[63:56]},p2={2'b0,w[55:48]},
 p3={2'b0,w[47:40]},p4={2'b0,w[39:32]},p5={2'b0,w[31:24]},
 p6={2'b0,w[23:16]},p7={2'b0,w[15:8]},p8={2'b0,w[7:0]};
 reg[9:0]sl,sr,st,sb,pl,pr,pt,pb,sx,sy,px,py;
 reg[20:0]ss,ps;reg[15:0]ts0,ts1,ts2;
 reg[2:0]v;reg[10:0]xx[0:2];reg[9:0]yy[0:2];integer i;
 always @(posedge clk)begin
  if(!rst_n)begin sl<=0;sr<=0;st<=0;sb<=0;pl<=0;pr<=0;pt<=0;pb<=0;
   sx<=0;sy<=0;px<=0;py<=0;ss<=0;ps<=0;ts0<=0;ts1<=0;ts2<=0;
   v<=0;vo<=0;sobel<=0;prewitt<=0;xo<=0;yo<=0;
   for(i=0;i<3;i=i+1)begin xx[i]<=0;yy[i]<=0;end
  end else begin
   sl<=p0+(p3<<1)+p6;sr<=p2+(p5<<1)+p8;st<=p0+(p1<<1)+p2;sb<=p6+(p7<<1)+p8;
   pl<=p0+p3+p6;pr<=p2+p5+p8;pt<=p0+p1+p2;pb<=p6+p7+p8;
   sx<=sl>sr?sl-sr:sr-sl;sy<=st>sb?st-sb:sb-st;
   px<=pl>pr?pl-pr:pr-pl;py<=pt>pb?pt-pb:pb-pt;
   ss<=sx*sx+sy*sy;ps<=px*px+py*py;
   ts0<=threshold*threshold;ts1<=ts0;ts2<=ts1;
   sobel<=ss>={5'b0,ts2};prewitt<=ps>={5'b0,ts2};
   v<={v[1:0],vi};vo<=v[2];xx[0]<=xi;yy[0]<=yi;
   for(i=1;i<3;i=i+1)begin xx[i]<=xx[i-1];yy[i]<=yy[i-1];end
   xo<=xx[2];yo<=yy[2];
  end
 end
endmodule

module ep1_morph #(parameter DILATE=0)(input clk,rst_n,vi,input[10:0]xi,
 input[9:0]yi,input[8:0]w,output reg value,vo,output reg[10:0]xo,output reg[9:0]yo);
 always @(posedge clk)begin
  if(!rst_n)begin value<=0;vo<=0;xo<=0;yo<=0;end
  else begin value<=DILATE?(|w):(&w);vo<=vi;xo<=xi;yo<=yi;end
 end
endmodule
