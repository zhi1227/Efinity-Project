// Median-prefiltered streaming Canny variant:
// grayscale -> median -> Sobel L1 -> directional NMS -> thresholds
// -> local 8-neighbour hysteresis (one pass, not recursive full-frame tracking).
// The valid image is cropped by four pixels per side; coordinates stay in
// original-image coordinates. Pipeline latency = 14 clocks + 4 lines/columns
// of spatial look-ahead. Never infer HDMI DE from this cropped valid signal.
`timescale 1ns/1ps
`include "vision_config.vh"
module canny_stream #(
 parameter WIDTH=1280, parameter TH_LOW=`VISION_CANNY_LOW, parameter TH_HIGH=`VISION_CANNY_HIGH,
 parameter GAUSSIAN=0
)(
 input clk, input rst_n, input frame_start,
 input [11:0] low_i, input [11:0] high_i,
 input de_i, input [10:0] x_i, input [9:0] y_i, input [15:0] rgb565_i,
 output edge_o, output valid_o, output [10:0] x_o, output [9:0] y_o,
 // Observation taps only: no new arithmetic or change to the Canny path.
 output [7:0] gray_o, output [11:0] sobel_mag_o, output sobel_valid_o,
 output [10:0] sobel_x_o, output [9:0] sobel_y_o,
 output [7:0] median_o,output median_valid_o,
 output [11:0] raw_mag_o,output raw_valid_o
);
 wire [7:0] gray, med;
 wire gv,mwv,mv,swv,sv,nwv,nv,tv,hwv;
 wire [10:0] gx,mwx,mx,swx,sx,nwx,nx,tx,hwx;
 wire [9:0] gy,mwy,my,swy,sy,nwy,ny,ty,hwy;
 wire [71:0] mw,sw;
 wire [11:0] mag,nmag;
 wire [1:0] dir,cls;
 wire [125:0] nw;
 wire [17:0] hw;
 rgb565_to_gray u_gray(clk,rst_n,de_i,x_i,y_i,rgb565_i,gray,gv,gx,gy);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(8)) u_med_window
 (clk,rst_n,frame_start,gv,gx,gy,gray,mw,mwv,mwx,mwy);
 median3x3 u_median(clk,rst_n,mwv,mwx,mwy,mw,med,mv,mx,my);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(8)) u_grad_window
 (clk,rst_n,frame_start,mv,mx,my,med,sw,swv,swx,swy);
 sobel3x3 u_sobel(clk,rst_n,swv,swx,swy,sw,mag,dir,sv,sx,sy);
 // Raw Sobel preserves faint details for grayscale/neon previews. Share gray window.
 sobel3x3 u_raw_sobel(.clk(clk),.rst_n(rst_n),.win_valid_i(mwv),.x_i(mwx),.y_i(mwy),
   .window_i(mw),.mag_o(raw_mag_o),.dir_o(),.valid_o(raw_valid_o),.x_o(),.y_o());
 assign median_o=med;
 assign median_valid_o=mv;
 wire [11:0] canny_mag;wire [1:0] canny_dir;wire canny_valid;
 wire [10:0] canny_x;wire [9:0] canny_y;
 generate if(GAUSSIAN) begin:g_gaussian
   wire [7:0] g;wire vg,wv;wire [10:0] xg,wx;wire [9:0] yg,wy;wire [71:0] gw;
   gaussian3x3 u_filter(clk,rst_n,mwv,mwx,mwy,mw,g,vg,xg,yg);
   line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(8)) u_window
     (clk,rst_n,frame_start,vg,xg,yg,g,gw,wv,wx,wy);
   sobel3x3 u_gradient(clk,rst_n,wv,wx,wy,gw,canny_mag,canny_dir,canny_valid,canny_x,canny_y);
 end else begin:g_median_legacy
   assign canny_mag=mag;assign canny_dir=dir;assign canny_valid=sv;
   assign canny_x=sx;assign canny_y=sy;
 end endgenerate
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(14)) u_nms_window
 (clk,rst_n,frame_start,canny_valid,canny_x,canny_y,{canny_dir,canny_mag},nw,nwv,nwx,nwy);
 nms3x3 u_nms(clk,rst_n,nwv,nwx,nwy,nw,nmag,nv,nx,ny);
 canny_threshold #(.TH_LOW(TH_LOW),.TH_HIGH(TH_HIGH),.USE_PORTS(1)) u_threshold
 (clk,rst_n,nv,nx,ny,nmag,high_i,low_i,cls,tv,tx,ty);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(2)) u_hys_window
 (clk,rst_n,frame_start,tv,tx,ty,cls,hw,hwv,hwx,hwy);
 hysteresis_local u_hysteresis(clk,rst_n,hwv,hwx,hwy,hw,edge_o,valid_o,x_o,y_o);
 assign gray_o=gray;
 assign sobel_mag_o=mag;
 assign sobel_valid_o=sv;
 assign sobel_x_o=sx;
 assign sobel_y_o=sy;
endmodule
