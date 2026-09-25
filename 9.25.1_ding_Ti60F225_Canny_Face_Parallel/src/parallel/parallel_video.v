// Same registered DDR source for both branches; stage 1 changes observation only.
`include "vision_config.vh"
module parallel_video #(
 parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,MAX_FACES=`VISION_FACE_MAX_FACES,
 parameter DEFAULT_MODE=`VISION_DEFAULT_MODE,
 parameter DEFAULT_LOW=`VISION_CANNY_LOW,DEFAULT_HIGH=`VISION_CANNY_HIGH,
 parameter [7:0] SKIN_CB_MIN=`VISION_SKIN_CB_MIN,SKIN_CB_MAX=`VISION_SKIN_CB_MAX,
 parameter [7:0] SKIN_CR_MIN=`VISION_SKIN_CR_MIN,SKIN_CR_MAX=`VISION_SKIN_CR_MAX,
 parameter [7:0] SKIN_Y_MIN=`VISION_SKIN_Y_MIN,SKIN_Y_MAX=`VISION_SKIN_Y_MAX,
 parameter FACE_CELL_SHIFT=`VISION_FACE_CELL_SHIFT,FACE_CELL_MIN=`VISION_FACE_CELL_MIN,
 parameter FACE_MIN_W=`VISION_FACE_MIN_W,FACE_MIN_H=`VISION_FACE_MIN_H,
 parameter FACE_MAX_W=`VISION_FACE_MAX_W,FACE_MAX_H=`VISION_FACE_MAX_H,
 parameter FACE_MIN_AREA=`VISION_FACE_MIN_AREA,
 parameter FACE_MIN_FILL_PERCENT=`VISION_FACE_MIN_FILL_PERCENT,
 parameter FACE_MIN_RATIO_X10=`VISION_FACE_MIN_RATIO_X10,
 parameter FACE_MAX_RATIO_X10=`VISION_FACE_MAX_RATIO_X10,
 parameter COMPARE_CANNY=`VISION_COMPARE_CANNY,DEBUG_BOXES=`VISION_DEBUG_BOXES,
 parameter CANNY_GAUSSIAN=0,HUD_ENABLE=0
)(
 input clk,rst_n,input [23:0] rgb_i,input de_i,vs_i,hs_i,
 input [3:0] mode_i,input [11:0] low_i,high_i,
 output [23:0] rgb_o,output de_o,vs_o,hs_o,output overrun,input freeze_i);
 localparam DELAY=4*(H_TOTAL+1)+14;
 localparam MORPH_DELAY=2*(H_TOTAL+1)+7;
 localparam RAW_DELAY=(H_TOTAL+1)+4;
 // Each delay counts all clocks including blanking. Preserve original total latency.
 reg [10:0] x;reg [9:0] y;reg vs_q;
 wire fs=vs_i && !vs_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin x<=0;y<=0;vs_q<=1;end
 else begin
   vs_q<=vs_i;
   if(!vs_i) begin x<=0;y<=0;end
   else if(de_i) begin if(x==WIDTH-1) begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
 end
 wire [15:0] rgb565={rgb_i[23:19],rgb_i[15:10],rgb_i[7:3]};
 reg [11:0] low_active,high_active;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin low_active<=DEFAULT_LOW;high_active<=DEFAULT_HIGH;end
 else if(fs) begin low_active<=low_i;high_active<=high_i;end
 wire ce,cv;wire [10:0] ex;wire [9:0] ey;
 wire [7:0] gray_tap;wire [11:0] sobel_mag;
 wire sobel_valid;wire [10:0] sobel_x;wire [9:0] sobel_y;
 wire [7:0] median_tap;wire median_valid,raw_valid;wire [11:0] raw_mag;
 canny_stream #(.WIDTH(WIDTH),.GAUSSIAN(CANNY_GAUSSIAN)) u_canny(
   .clk(clk),.rst_n(rst_n),.frame_start(fs),.low_i(low_active),.high_i(high_active),
   .de_i(de_i),.x_i(x),.y_i(y),.rgb565_i(rgb565),
   .edge_o(ce),.valid_o(cv),.x_o(ex),.y_o(ey),.gray_o(gray_tap),
   .sobel_mag_o(sobel_mag),.sobel_valid_o(sobel_valid),.sobel_x_o(sobel_x),.sobel_y_o(sobel_y),
   .median_o(median_tap),.median_valid_o(median_valid),.raw_mag_o(raw_mag),.raw_valid_o(raw_valid));
 wire [39:0] aligned;
 video_delay #(.BITS(40),.LATENCY(DELAY)) u_video_delay(
   .clk(clk),.rst_n(rst_n),.din({vs_i,hs_i,de_i,y,x,rgb565}),.dout(aligned));
 wire avs=aligned[39],ahs=aligned[38],ade=aligned[37];
 wire [9:0] ay=aligned[36:27];wire [10:0] ax=aligned[26:16];
 wire [23:0] argb;
 rgb565_to_rgb888 expand(aligned[15:0],argb);
 wire aligned_edge=ce && cv && ade && ex==ax && ey==ay;
 wire skin,sv;wire [10:0] sx;wire [9:0] sy;
 rgb565_to_ycbcr_skin u_skin(
   .clk(clk),.rst_n(rst_n),.de_i(de_i),.x_i(x),.y_i(y),.rgb565_i(rgb565),
   .cb_min_i(SKIN_CB_MIN),.cb_max_i(SKIN_CB_MAX),.cr_min_i(SKIN_CR_MIN),.cr_max_i(SKIN_CR_MAX),
   .y_min_i(SKIN_Y_MIN),.y_max_i(SKIN_Y_MAX),.skin_o(skin),.de_o(sv),.x_o(sx),.y_o(sy));
 wire mb,mv;wire [10:0] mx;wire [9:0] my;
 face_morph #(.WIDTH(WIDTH)) u_morph(clk,rst_n,fs,sv,sx,sy,skin,mb,mv,mx,my);
 // Full raster for CCL: the two-pixel clean-mask border stays zero.
 wire [23:0] mask_raster;
 video_delay #(.BITS(24),.LATENCY(MORPH_DELAY)) u_mask_delay(
   .clk(clk),.rst_n(rst_n),.din({vs_i,hs_i,de_i,y,x}),.dout(mask_raster));
 wire md=mask_raster[21];wire [9:0] mya=mask_raster[20:11];wire [10:0] mxa=mask_raster[10:0];
 wire clean_skin=mv && mb && mx==mxa && my==mya;
 wire sobel_binary=md && sobel_valid && sobel_x==mxa && sobel_y==mya && sobel_mag>=low_active;
 // Reuse existing taps. Gray/raw skin latency=1; Sobel/clean latency=MORPH_DELAY.
 // Narrow packed RAMs avoid delaying redundant coordinates a second time.
 wire [8:0] early_debug;
 video_delay #(.BITS(9),.LATENCY(DELAY-1)) u_early_debug_delay(
   .clk(clk),.rst_n(rst_n),.din({sv && skin,gray_tap}),.dout(early_debug));
 wire [9:0] window_debug;
 wire [7:0] med_strength=sobel_valid?((sobel_mag>255)?8'hff:sobel_mag[7:0]):8'd0;
 video_delay #(.BITS(10),.LATENCY(DELAY-MORPH_DELAY)) u_window_debug_delay(
   .clk(clk),.rst_n(rst_n),.din({med_strength,md && clean_skin,sobel_binary}),.dout(window_debug));
 wire [16:0] raw_preview;
 wire [7:0] raw_strength=raw_valid?((raw_mag>255)?8'hff:raw_mag[7:0]):8'd0;
 video_delay #(.BITS(17),.LATENCY(DELAY-RAW_DELAY)) u_raw_preview_delay(
   .clk(clk),.rst_n(rst_n),.din({raw_valid && raw_mag>=low_active,
      raw_strength,median_valid?median_tap:8'd0}),.dout(raw_preview));
 wire [7:0] aligned_gray=early_debug[7:0];
 wire aligned_raw_skin=ade && early_debug[8];
 wire aligned_clean_skin=ade && window_debug[1];
 wire aligned_sobel=ade && window_debug[0];
 wire [3:0] count;wire [MAX_FACES*42-1:0] boxes;wire busy;
 reg avs_q;wire display_fs=avs&&!avs_q;
 reg [3:0] mode_active;
 reg frozen_active;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin avs_q<=1;mode_active<=DEFAULT_MODE;frozen_active<=0;end
 else begin avs_q<=avs;if(display_fs) begin mode_active<=mode_i;frozen_active<=freeze_i;end end
 face_grid_regions #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES),
   .CELL_SHIFT(FACE_CELL_SHIFT),.CELL_MIN(FACE_CELL_MIN),
   .MIN_W(FACE_MIN_W),.MIN_H(FACE_MIN_H),.MAX_W(FACE_MAX_W),.MAX_H(FACE_MAX_H),
   .MIN_AREA(FACE_MIN_AREA),.MIN_FILL_PERCENT(FACE_MIN_FILL_PERCENT),
   .MIN_RATIO_X10(FACE_MIN_RATIO_X10),.MAX_RATIO_X10(FACE_MAX_RATIO_X10)) u_regions(
   .clk(clk),.rst_n(rst_n),.frame_start(display_fs),.skin_valid(md),.skin(clean_skin),
   .x(mxa),.y(mya),.face_count(count),.boxes(boxes),.busy(busy),.overrun(overrun));
 wire [1:0] shape_class;wire [41:0] shape_box;
 edge_shape_roi #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) u_shape(
   .clk(clk),.rst_n(rst_n),.frame_start(display_fs),.de(ade),.edge_pixel(aligned_sobel),
   .x(ax),.y(ay),.shape_class(shape_class),.box(shape_box));
 parallel_overlay #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES),.DEBUG_BOXES(DEBUG_BOXES),
   .HUD_ENABLE(HUD_ENABLE)) u_overlay(
   .clk(clk),.rst_n(rst_n),.mode(mode_active),.rgb(argb),.de(ade),.vs(avs),.hs(ahs),
   .x(ax),.y(ay),.edge_pixel(aligned_edge),.count(count),.boxes(boxes),
   .gray_pixel(aligned_gray),.compare_edge(COMPARE_CANNY?aligned_edge:aligned_sobel),
   .raw_skin(aligned_raw_skin),.clean_skin(aligned_clean_skin),
   .raw_strength(raw_preview[15:8]),.median_pixel(raw_preview[7:0]),.median_strength(window_debug[9:2]),
   .raw_edge(raw_preview[16]),.frozen(frozen_active),.shape_class(shape_class),.shape_box(shape_box),
   .rgb_o(rgb_o),.de_o(de_o),.vs_o(vs_o),.hs_o(hs_o));
endmodule
