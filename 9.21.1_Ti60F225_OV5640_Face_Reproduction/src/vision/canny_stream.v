// Median-prefiltered streaming Canny variant:
// grayscale -> median -> Sobel L1 -> directional NMS -> thresholds
// -> local 8-neighbour hysteresis (one pass, not recursive full-frame tracking).
// The valid image is cropped by four pixels per side; coordinates stay in
// original-image coordinates. Pipeline latency = 14 clocks + 4 lines/columns
// of spatial look-ahead. Never infer HDMI DE from this cropped valid signal.
`timescale 1ns/1ps
module canny_stream #(
 parameter WIDTH=1280, parameter TH_LOW=120, parameter TH_HIGH=240
)(
 input clk, input rst_n, input frame_start,
 input de_i, input [10:0] x_i, input [9:0] y_i, input [15:0] rgb565_i,
 output edge_o, output valid_o, output [10:0] x_o, output [9:0] y_o
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
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(14)) u_nms_window
 (clk,rst_n,frame_start,sv,sx,sy,{dir,mag},nw,nwv,nwx,nwy);
 nms3x3 u_nms(clk,rst_n,nwv,nwx,nwy,nw,nmag,nv,nx,ny);
 canny_threshold #(.TH_LOW(TH_LOW),.TH_HIGH(TH_HIGH)) u_threshold
 (clk,rst_n,nv,nx,ny,nmag,cls,tv,tx,ty);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(2)) u_hys_window
 (clk,rst_n,frame_start,tv,tx,ty,cls,hw,hwv,hwx,hwy);
 hysteresis_local u_hysteresis(clk,rst_n,hwv,hwx,hwy,hw,edge_o,valid_o,x_o,y_o);
endmodule
