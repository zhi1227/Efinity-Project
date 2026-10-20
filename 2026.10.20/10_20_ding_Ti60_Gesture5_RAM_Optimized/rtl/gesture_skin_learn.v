// Same two-cycle mask latency as ep1_skin; only mode 6 uses this module.
// Palm colour is sampled from a 32x32 crosshair. No camera registers are changed.
module gesture_skin_learn #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,de,fs,input[10:0]x,input[9:0]y,input[23:0]rgb,
 input[7:0]lower,input sample,clear,
 output reg mask,valid,frame_start,output reg[10:0]xo,output reg[9:0]yo,
 output reg calibrated,sample_done,sample_ok);
 localparam CX=WIDTH*7/16,CY=HEIGHT/2;
 reg[15:0]luma;reg[17:0]cb,cr;reg[7:0]diff,lo;reg red_blue,d,f;reg[10:0]xx;reg[9:0]yy;
 reg[7:0]cb_lo,cb_hi,cr_lo,cr_hi;
 reg pending,collect;reg[18:0]cb_sum,cr_sum,y_sum;reg[10:0]count;
 wire[7:0]cb_avg=cb_sum[17:10],cr_avg=cr_sum[17:10],y_avg=y_sum[17:10];
 wire colour_ok=count==1024&&cr_avg>=130&&cr_avg<=185&&cb_avg>=80&&cb_avg<=140&&y_avg>=40&&y_avg<=242;
 always @(posedge clk)begin
  if(!rst_n)begin
   cb<=0;cr<=0;luma<=0;diff<=0;lo<=10;red_blue<=0;d<=0;f<=0;xx<=0;yy<=0;
   mask<=0;valid<=0;frame_start<=0;xo<=0;yo<=0;
   calibrated<=0;sample_done<=0;sample_ok<=0;pending<=0;collect<=0;count<=0;cb_sum<=0;cr_sum<=0;y_sum<=0;
   cb_lo<=80;cb_hi<=140;cr_lo<=132;cr_hi<=185;
  end else begin
   luma<=rgb[23:16]*16'd77+rgb[15:8]*16'd150+rgb[7:0]*16'd29;
   cb<=18'd32768-rgb[23:16]*18'd43-rgb[15:8]*18'd85+rgb[7:0]*18'd128;
   cr<=18'd32768+rgb[23:16]*18'd128-rgb[15:8]*18'd107-rgb[7:0]*18'd21;
   diff<=rgb[23:16]>rgb[15:8]?rgb[23:16]-rgb[15:8]:8'd0;
   red_blue<=rgb[23:16]>rgb[7:0];lo<=lower;d<=de;f<=fs;xx<=x;yy<=y;
   mask<=d&&luma[15:8]>=28&&luma[15:8]<=250&&
     cb>={cb_lo,8'd0}&&cb<={cb_hi,8'd0}&&cr>={cr_lo,8'd0}&&cr<={cr_hi,8'd0}&&
     (calibrated||(diff>=(lo>5?lo-5:0)&&diff<100&&red_blue));
   valid<=d;frame_start<=f;xo<=xx;yo<=yy;
   sample_done<=0;
   if(clear)begin calibrated<=0;pending<=0;collect<=0;cb_lo<=80;cb_hi<=140;cr_lo<=132;cr_hi<=185;end
   else begin
    if(sample)pending<=1;
    if(f)begin
     if(collect)begin
      sample_done<=1;sample_ok<=colour_ok;
      if(colour_ok)begin
       // Luma-independent chroma window tolerates bright and shaded fingers.
       cb_lo<=cb_avg>24?cb_avg-24:0;cb_hi<=cb_avg<231?cb_avg+24:255;
       // Pale fingertips approach neutral chroma as brightness increases.
       cr_lo<=cr_avg<158?130:(cr_avg<163?cr_avg-28:135);
       cr_hi<=cr_avg<233?cr_avg+22:255;calibrated<=1;
      end
     end
     collect<=pending||sample;pending<=0;count<=0;cb_sum<=0;cr_sum<=0;y_sum<=0;
    end else if(collect&&d&&xx>=CX-16&&xx<CX+16&&yy>=CY-16&&yy<CY+16)begin
     cb_sum<=cb_sum+cb[15:8];cr_sum<=cr_sum+cr[15:8];y_sum<=y_sum+luma[15:8];count<=count+1'b1;
    end
   end
  end
 end
endmodule
