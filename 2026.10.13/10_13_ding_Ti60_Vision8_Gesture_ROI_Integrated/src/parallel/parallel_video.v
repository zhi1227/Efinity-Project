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
 parameter SOURCE_TAGGED=0,CANNY_GAUSSIAN=0,HUD_ENABLE=0,GESTURE_DEBUG=0,SHARED_FONT=0
)(
 input clk,rst_n,input [23:0] rgb_i,input de_i,vs_i,hs_i,
 input [3:0] mode_i,input [11:0] low_i,high_i,
 output [23:0] rgb_o,output de_o,vs_o,hs_o,output overrun,input freeze_i,
 output [3:0] mode_committed_o,output frozen_committed_o,
 input pure_i,detect_i,input[7:0]skin_lower_i,health_i,
 input gesture_short_i,gesture_long_i,output gesture_learning_o,
 input[31:0]source_id_i,
 output[3:0]face_count_o,output face_busy_o,face_valid_o,face_saturated_o,
 output[2:0]gesture_o,trained_o,learn_state_o,output[7:0]countdown_o,
 output reg[15:0]result565_o,output reg result_de_o,result_vs_o,
 output reg[10:0]result_x_o,output reg[9:0]result_y_o,output[11:0]shared_addr,input[15:0]shared_bits);
reg [3:0] mode_active,mode_pending;reg freeze_pending,pure_pending,detect_pending;reg[7:0]skin_pending;
reg frozen_active,pure_active,detect_active;reg[7:0]skin_lower_active;wire face_overflow;
 localparam DELAY=4*(H_TOTAL+1)+14;
 localparam MORPH_DELAY=2*(H_TOTAL+1)+7;
 localparam RAW_DELAY=(H_TOTAL+1)+4;
 // Each delay counts all clocks including blanking. Preserve original total latency.
 reg [10:0] x;reg [9:0] y;reg vs_q;
 wire fs=vs_i && !vs_q;
 always @(posedge clk)begin
  if(!rst_n)begin mode_pending<=DEFAULT_MODE;freeze_pending<=0;pure_pending<=0;detect_pending<=0;skin_pending<=10;end
  else if(fs)begin mode_pending<=mode_i;freeze_pending<=freeze_i;pure_pending<=pure_i;detect_pending<=detect_i&&mode_i!=15;skin_pending<=skin_lower_i;end
 end
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
 wire [18:0] aligned;
 video_delay #(.BITS(19),.LATENCY(DELAY)) u_video_delay(
   .clk(clk),.rst_n(rst_n),.din({vs_i,hs_i,de_i,rgb565}),.dout(aligned));
 wire avs=aligned[18],ahs=aligned[17],ade=aligned[16];
 wire [9:0] ay;wire [10:0] ax;
 raster_xy #(.WIDTH(WIDTH)) video_xy(clk,rst_n,avs,ade,ax,ay);
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
 wire [2:0] mask_raster;
 video_delay #(.BITS(3),.LATENCY(MORPH_DELAY)) u_mask_delay(
   .clk(clk),.rst_n(rst_n),.din({vs_i,hs_i,de_i}),.dout(mask_raster));
 wire md=mask_raster[0];wire [9:0] mya;wire [10:0] mxa;
 raster_xy #(.WIDTH(WIDTH)) mask_xy(clk,rst_n,mask_raster[2],md,mxa,mya);
 wire clean_skin=mv && mb && mx==mxa && my==mya;
 wire sobel_binary=md && sobel_valid && sobel_x==mxa && sobel_y==mya && sobel_mag>=12'd40;
 // Reuse existing taps. Gray/raw skin latency=1; Sobel/clean latency=MORPH_DELAY.
 // Narrow packed RAMs avoid delaying redundant coordinates a second time.
 wire [7:0] aligned_gray;
 video_delay #(.BITS(8),.LATENCY(DELAY-1)) gray_delay(clk,rst_n,gray_tap,aligned_gray);
 wire aligned_sobel;
 video_delay #(.BITS(1),.LATENCY(DELAY-MORPH_DELAY)) sobel_delay(clk,rst_n,sobel_binary,aligned_sobel);
 wire [8:0] raw_preview;
 wire [7:0] raw_strength=raw_valid?((raw_mag>255)?8'hff:raw_mag[7:0]):8'd0;
 video_delay #(.BITS(9),.LATENCY(DELAY-RAW_DELAY)) raw_delay(clk,rst_n,
   {raw_valid && raw_mag>=12'd40,raw_strength},raw_preview);
 wire hand_valid,hand_overflow,hand_raw,hand_raw_valid;wire[41:0]hand_box;wire[2:0]gesture;
 wire aligned_hand_skin;
 wire[2:0]learn_step,learn_state,trained,wave_phase;wire[1:0]learn_error;
 wire[7:0]learn_countdown;wire[255:0]hand_preview;wire hand_preview_valid;
 wire hand_enable=mode_active==15&&!pure_active&&!frozen_active&&health_i[7]&&health_i[6]&&health_i[3];
 wire[19:0]hand_debug_raw,hand_debug_clean,hand_debug_ratio;
 wire[9:0]hand_debug_fill;wire[3:0]hand_debug_reject,hand_debug_fault;wire[2:0]hand_debug_class;
 reg[7:0]skin_lower_previous;
 always @(posedge clk)if(!rst_n)skin_lower_previous<=10;else skin_lower_previous<=skin_lower_active;
 wire gesture_rstn=rst_n&&(skin_lower_previous==skin_lower_active);
 gesture_branch #(.SOURCE_TAGGED(SOURCE_TAGGED),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL)) hand(
  .clk(clk),.rst_n(rst_n),.enable(hand_enable),
  .rgb(rgb_i),.de(de_i),.vs(vs_i),.hs(hs_i),.fs(fs),.x(x),.y(y),.skin_lower(skin_lower_active),
  .box_valid(hand_valid),.box(hand_box),.gesture(gesture),.overflow(hand_overflow),
  .skin_raw(hand_raw),.skin_valid(hand_raw_valid),
  .debug_raw(hand_debug_raw),.debug_clean(hand_debug_clean),.debug_fill(hand_debug_fill),.debug_ratio(hand_debug_ratio),
  .debug_reject(hand_debug_reject),.debug_fault(hand_debug_fault),.debug_class(hand_debug_class),
  .key_short(gesture_short_i),.key_long(gesture_long_i),.mode_on(mode_active==15&&!pure_active),.learn_busy(gesture_learning_o),
  .learn_step(learn_step),.learn_state(learn_state),.learn_error(learn_error),.trained(trained),
  .learn_countdown(learn_countdown),.preview(hand_preview),.preview_valid(hand_preview_valid),.wave_phase(wave_phase),.source_id_i(source_id_i));
 video_delay #(.BITS(1),.LATENCY(DELAY-2)) hand_mask_delay(clk,rst_n,hand_raw&&hand_raw_valid,aligned_hand_skin);
 wire [3:0] count;wire [MAX_FACES*42-1:0] boxes;wire busy;
 reg avs_q;wire display_fs=avs&&!avs_q;
 
 
 wire face_published,face_saturated;wire[31:0]face_id;
 vision8_count_filter #(.SOURCE_TAGGED(SOURCE_TAGGED)) count_filter(
 .clk(clk),.rst_n(rst_n&&detect_active),.source_ok(&health_i[6:0]),.frozen(frozen_active),.published(face_published),.source_id(face_id),
 .count_i(count),.saturated_i(face_saturated),.count_o(face_count_o),.valid_o(face_valid_o),.saturated_o(face_saturated_o));
 assign face_busy_o=busy;
 assign gesture_o=gesture;assign trained_o=trained;assign learn_state_o=learn_state;assign countdown_o=learn_countdown;
 reg[23:0]plain,plain_neon;
 always @*begin
  if(raw_preview[7:0]<24)plain_neon=0;
  else if(raw_preview[7:0]<64)plain_neon={8'd0,raw_preview[7:0],raw_preview[5:0],2'b00};
  else if(raw_preview[7:0]<128)plain_neon=24'h00ffff;
  else if(raw_preview[7:0]<192)plain_neon={raw_preview[7:0],8'h20,8'hff};
  else plain_neon=24'hff40e0;
  case(mode_active)1:plain={24{aligned_edge}};10:plain=raw_preview[8]?24'hff0000:argb;9:plain=plain_neon;default:plain=argb;endcase
 end
 always @(posedge clk)begin
  if(!rst_n)begin result565_o<=0;result_de_o<=0;result_vs_o<=0;result_x_o<=0;result_y_o<=0;end
  else begin result565_o<={plain[23:19],plain[15:10],plain[7:3]};result_de_o<=ade;result_vs_o<=avs;result_x_o<=ax;result_y_o<=ay;end
 end

 assign overrun=face_overflow||hand_overflow;
 assign mode_committed_o=mode_active;
 assign frozen_committed_o=frozen_active;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin avs_q<=1;mode_active<=DEFAULT_MODE;frozen_active<=0;pure_active<=0;detect_active<=0;skin_lower_active<=10;end
 else begin avs_q<=avs;if(display_fs) begin mode_active<=mode_pending;frozen_active<=freeze_pending;pure_active<=pure_pending;detect_active<=detect_pending;skin_lower_active<=skin_pending;end end
 face_grid_regions #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES),
   .CELL_SHIFT(FACE_CELL_SHIFT),.CELL_MIN(FACE_CELL_MIN),
   .MIN_W(FACE_MIN_W),.MIN_H(FACE_MIN_H),.MAX_W(FACE_MAX_W),.MAX_H(FACE_MAX_H),
   .MIN_AREA(FACE_MIN_AREA),.MIN_FILL_PERCENT(FACE_MIN_FILL_PERCENT),
   .MIN_RATIO_X10(FACE_MIN_RATIO_X10),.MAX_RATIO_X10(FACE_MAX_RATIO_X10)) u_regions(
   .clk(clk),.rst_n(rst_n&&detect_active&&!pure_active),.frame_start(display_fs),.skin_valid(md),.skin(clean_skin),
   .x(mxa),.y(mya),.face_count(count),.boxes(boxes),.busy(busy),.overrun(face_overflow),.source_id_i(source_id_i),.published(face_published),.result_id(face_id),.saturated(face_saturated));
 wire [1:0] shape_class;wire [41:0] shape_box;
 edge_shape_roi #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) u_shape(
   .clk(clk),.rst_n(rst_n),.frame_start(display_fs),.de(ade),.edge_pixel(aligned_sobel),
   .x(ax),.y(ay),.shape_class(shape_class),.box(shape_box));
 vision6_overlay #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES),.HUD_ENABLE(HUD_ENABLE),.GESTURE_DEBUG(GESTURE_DEBUG),.SHARED_FONT(SHARED_FONT)) u_overlay(
 .shared_addr(shared_addr),.shared_bits(shared_bits),
   .clk(clk),.rst_n(rst_n),.mode(mode_active),.rgb(argb),.de(ade),.vs(avs),.hs(ahs),
   .x(ax),.y(ay),.edge_pixel(aligned_edge),.count(count),.boxes(boxes),
   .gray_pixel(aligned_gray),.compare_edge(aligned_sobel),.raw_strength(raw_preview[7:0]),
   .raw_edge(raw_preview[8]),.frozen(frozen_active),.pure_en(pure_active),.detect(detect_active),
   .shape_class(shape_class),.shape_box(shape_box),.hand_valid(hand_valid),.hand_box(hand_box),
   .gesture(gesture),.hand_skin(aligned_hand_skin),.health(health_i),
   .hand_enable(hand_enable),.hand_overflow(hand_overflow),.debug_raw(hand_debug_raw),.debug_clean(hand_debug_clean),
   .debug_fill(hand_debug_fill),.debug_ratio(hand_debug_ratio),.debug_reject(hand_debug_reject),.debug_fault(hand_debug_fault),
   .debug_class(hand_debug_class),.debug_lower(skin_lower_active),
   .rgb_o(rgb_o),.de_o(de_o),.vs_o(vs_o),.hs_o(hs_o),
   .learn_step(learn_step),.learn_state(learn_state),.learn_error(learn_error),.trained(trained),
   .learn_countdown(learn_countdown),.preview(hand_preview),.preview_valid(hand_preview_valid),.wave_phase(wave_phase));
endmodule
