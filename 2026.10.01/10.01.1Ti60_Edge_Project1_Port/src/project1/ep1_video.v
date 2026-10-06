// Project1 algorithm port. Pixel domain only; board capture/DDR/HDMI unchanged.
// Window centers move by one row and column per 3x3 stage. Every visible mode
// is aligned to that SAME center using a fixed clock delay including blanking.
module ep1_video #(
 parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,
 parameter DEBOUNCE=1488000,LONG_PRESS=59520000,HUD_ENABLE=1
)(input clk,rst_n,input[23:0]rgb_i,input de_i,vs_i,hs_i,key_mode_n,key_threshold_n,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,
 output[2:0]mode_o,output[7:0]threshold_o,output[1:0]gesture_o,
 output[19:0]feature_o,output box_valid_o);
 localparam STEP=H_TOTAL+1, LATENCY=5*STEP+12;
 reg vs_last;reg[10:0]x;reg[9:0]y;
 wire fs=vs_i&&!vs_last;
 always @(posedge clk)begin
  if(!rst_n)begin vs_last<=1;x<=0;y<=0;end
  else begin
   vs_last<=vs_i;
   if(!vs_i)begin x<=0;y<=0;end
   else if(de_i)begin
    if(x==WIDTH-1)begin x<=0;y<=y==HEIGHT-1?10'd0:y+1'b1;end
    else x<=x+1'b1;
   end
  end
 end
 wire[2:0]mode;wire[7:0]threshold,skin_lower;
 ep1_controls #(.DEBOUNCE(DEBOUNCE),.LONG_PRESS(LONG_PRESS))
 controls(clk,rst_n,fs,key_mode_n,key_threshold_n,mode,threshold,skin_lower);
 wire[7:0]gray,processed;wire cv,cfs;wire[10:0]cx;wire[9:0]cy;
 ep1_color color(clk,rst_n,de_i,fs,x,y,rgb_i,1'b0,gray,processed,cv,cfs,cx,cy);
 wire[71:0]mw,ew;wire mwv,mv,ewv,ev;wire[10:0]mwx,mx,ewx,ex;
 wire[9:0]mwy,my,ewy,ey;wire[7:0]median;wire sobel,prewitt;
 line_buffer_3x3 #(.WIDTH(WIDTH)) mlb(clk,rst_n,cfs,cv,cx,cy,processed,mw,mwv,mwx,mwy);
 ep1_median med(clk,rst_n,mwv,mwx,mwy,mw,median,mv,mx,my);
 line_buffer_3x3 #(.WIDTH(WIDTH)) elb(clk,rst_n,cfs,mv,mx,my,median,ew,ewv,ewx,ewy);
 ep1_gradient grad(clk,rst_n,ewv,ewx,ewy,ew,threshold,sobel,prewitt,ev,ex,ey);
 wire[8:0]rw,dw;wire rwv,rv,dwv,dv,eroded,dilated;
 wire[10:0]rwx,rx,dwx,dx;wire[9:0]rwy,ry,dwy,dy;
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) rlb(clk,rst_n,cfs,ev,ex,ey,sobel,rw,rwv,rwx,rwy);
 ep1_morph erosion(clk,rst_n,rwv,rwx,rwy,rw,eroded,rv,rx,ry);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) dlb(clk,rst_n,cfs,rv,rx,ry,eroded,dw,dwv,dwx,dwy);
 ep1_morph #(.DILATE(1)) dilation(clk,rst_n,dwv,dwx,dwy,dw,dilated,dv,dx,dy);

 // M7 operates on a filled binary skin mask, independently of the edge modes.
 wire sk,sv,sfs;wire[10:0]sx;wire[9:0]sy;
 ep1_skin skin(clk,rst_n,de_i,fs,x,y,rgb_i,skin_lower,sk,sv,sfs,sx,sy);
 wire[48:0]sw;wire swv,lp,lpv;wire[10:0]swx,lpx;wire[9:0]swy,lpy;
 ep1_window7 #(.WIDTH(WIDTH)) slb(clk,rst_n,sfs,sv,sx,sy,sk,sw,swv,swx,swy);
 ep1_disk disk(clk,rst_n,swv,swx,swy,sw,lp,lpv,lpx,lpy);
 wire[8:0]sew,sdw;wire sewv,se,sev,sdwv,sd,sdv;
 wire[10:0]sewx,sex,sdwx,sdx;wire[9:0]sewy,sey,sdwy,sdy;
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) selb(clk,rst_n,sfs,lpv,lpx,lpy,lp,sew,sewv,sewx,sewy);
 ep1_morph seop(clk,rst_n,sewv,sewx,sewy,sew,se,sev,sex,sey);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) sdlb(clk,rst_n,sfs,sev,sex,sey,se,sdw,sdwv,sdwx,sdwy);
 ep1_morph #(.DILATE(1)) sdop(clk,rst_n,sdwv,sdwx,sdwy,sdw,sd,sdv,sdx,sdy);

 wire[66:0]raster;wire[23:0]raw;wire ade,avs,ahs;wire[10:0]ax;wire[9:0]ay;
 wire[2:0]amode;wire[7:0]athreshold,askin;
 video_delay #(.BITS(67),.LATENCY(LATENCY)) ra(clk,rst_n,{rgb_i,de_i,vs_i,hs_i,x,y,mode,threshold,skin_lower},raster);
 assign {raw,ade,avs,ahs,ax,ay,amode,athreshold,askin}=raster;
 wire[7:0]ag;wire[8:0]am;wire[2:0]ae;wire[1:0]ar;
 video_delay #(.BITS(8),.LATENCY(5*STEP+9)) ga(clk,rst_n,gray,ag);
 video_delay #(.BITS(9),.LATENCY(4*STEP+4)) ma(clk,rst_n,{mv,median},am);
 video_delay #(.BITS(3),.LATENCY(3*STEP-2)) ea(clk,rst_n,{ev,sobel,prewitt},ae);
 video_delay #(.BITS(2),.LATENCY(2*STEP-5)) erda(clk,rst_n,{rv,eroded},ar);
 wire[1:0]ad;
 video_delay #(.BITS(2),.LATENCY(STEP-8)) dda(clk,rst_n,{dv,dilated},ad);
 wire skin_valid=sdv&&sdx==ax&&sdy==ay;
 reg avs_last;reg[2:0]previous_mode;reg[7:0]previous_skin;
 wire afs=avs&&!avs_last;
 wire afe=!avs&&avs_last;
 wire changed=previous_mode!=amode||previous_skin!=askin;
 always @(posedge clk)begin
  if(!rst_n)begin avs_last<=1;previous_mode<=3;previous_skin<=10;end
  else begin avs_last<=avs;previous_mode<=amode;previous_skin<=askin;end
 end
 wire[10:0]xmin,xmax;wire[9:0]ymin,ymax;wire result_done;
 wire[19:0]area,ratio;wire[9:0]fill;wire overflow;
 ep1_gesture #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) stats(clk,rst_n&&!changed,afs,afe,amode==7,ade,skin_valid&&sd,
 ax,ay,box_valid_o,xmin,xmax,ymin,ymax,area,fill,ratio,gesture_o,overflow,result_done);
 assign feature_o={10'd0,fill};
 wire[23:0]digits,area_digits,ratio_digits;
 ep1_decimal decimal(clk,rst_n&&amode==7,result_done,feature_o,digits);
 ep1_decimal adecimal(clk,rst_n&&amode==7,result_done,area,area_digits);
 ep1_decimal rdecimal(clk,rst_n&&amode==7,result_done,ratio,ratio_digits);
 wire box_edge=box_valid_o&&ax>=xmin&&ax<=xmax&&ay>=ymin&&ay<=ymax&&
 (ax==xmin||ax==xmax||ay==ymin||ay==ymax);
 wire hud_area,hud_ink;
 ep1_hud hud(ax,ay,amode,athreshold,gesture_o,digits,area_digits,ratio_digits,askin,overflow,hud_area,hud_ink);
 reg[23:0]selected;
 always @*begin
  case(amode)
   0:selected=raw;
   1:selected={ag,ag,ag};
   2:selected=am[8]?{am[7:0],am[7:0],am[7:0]}:24'd0;
   3:selected={24{ae[2]&&ae[1]}};
   4:selected={24{ae[2]&&ae[0]}};
   5:selected={24{ar[1]&&ar[0]}};
   6:selected={24{ad[1]&&ad[0]}};
   default:selected=box_edge?24'hff0000:{24{skin_valid&&sd}};
  endcase
  if(HUD_ENABLE&&hud_area)selected=hud_ink?24'hffffff:24'h101020;
 end
 assign mode_o=amode;assign threshold_o=athreshold;
 always @(posedge clk)begin
  if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
  else begin rgb_o<=ade?selected:24'd0;de_o<=ade;vs_o<=avs;hs_o<=ahs;end
 end
endmodule
