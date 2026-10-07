// H5: button-guided colour calibration and personalized silhouette templates.
// CCL uses its own 3-bit timing delay; the main video has no second framebuffer.
`include "gesture_config.vh"
module gesture_branch #(parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,WIZ_COUNTDOWN=120,WIZ_SETTLE=15,WIZ_TIMEOUT=360)(
 input clk,rst_n,enable,input[23:0]rgb,input de,vs,hs,fs,
 input[10:0]x,input[9:0]y,input[7:0]skin_lower,
 output box_valid,output[41:0]box,output[2:0]gesture,output overflow,
 output skin_raw,skin_valid,
 output reg[19:0]debug_raw,debug_clean,
 output[9:0]debug_fill,output[19:0]debug_ratio,
 output[3:0]debug_reject,debug_fault,output[2:0]debug_class,
 input key_short,key_long,mode_on,output learn_busy,
 output[2:0]learn_step,learn_state,trained,output[1:0]learn_error,
 output[7:0]learn_countdown,output[255:0]preview,output preview_valid,output[2:0]wave_phase);
 wire sfs;wire[10:0]sx;wire[9:0]sy;
 wire clear_models,skin_sample,skin_done,skin_ok,skin_calibrated,capture_done,capture_ok;
 wire[2:0]learn_cmd;wire[1:0]capture_error,capture_count;
 gesture_wizard #(.COUNTDOWN_FRAMES(WIZ_COUNTDOWN),.SETTLE_FRAMES(WIZ_SETTLE),.TIMEOUT_FRAMES(WIZ_TIMEOUT)) wizard(clk,rst_n,mode_on,fs,key_short,key_long,skin_done,skin_ok,capture_done,capture_ok,capture_error,
  learn_busy,clear_models,skin_sample,learn_cmd,learn_step,learn_state,learn_error,learn_countdown);
 gesture_skin_learn #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) skin(clk,rst_n,de,fs,x,y,rgb,skin_lower,skin_sample,clear_models,
  skin_raw,skin_valid,sfs,sx,sy,skin_calibrated,skin_done,skin_ok);
 wire[48:0]sw;wire swv,lp,lpv;wire[10:0]swx,lpx;wire[9:0]swy,lpy;
 ep1_window7 #(.WIDTH(WIDTH)) slb(clk,rst_n,sfs,skin_valid,sx,sy,skin_raw,sw,swv,swx,swy);
 ep1_disk disk(clk,rst_n,swv,swx,swy,sw,lp,lpv,lpx,lpy);
 wire[8:0]ew,dw;wire ewv,eb,ev,dwv,db,dv;
 wire[10:0]ewx,ex,dwx,dx;wire[9:0]ewy,ey,dwy,dy;
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) elb(clk,rst_n,sfs,lpv,lpx,lpy,lp,ew,ewv,ewx,ewy);
 ep1_morph #(.DILATE(1)) ero(clk,rst_n,ewv,ewx,ewy,ew,eb,ev,ex,ey);
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) dlb(clk,rst_n,sfs,ev,ex,ey,eb,dw,dwv,dwx,dwy);
 ep1_morph dil(clk,rst_n,dwv,dwx,dwy,dw,db,dv,dx,dy);
 wire[2:0]raster;wire[10:0]ax;wire[9:0]ay;reg vsq;
 video_delay #(.BITS(3),.LATENCY(5*(H_TOTAL+1)+12)) timing(clk,rst_n,{vs,hs,de},raster);
 raster_xy #(.WIDTH(WIDTH)) xy(clk,rst_n,raster[2],raster[0],ax,ay);
 always @(posedge clk)if(!rst_n)vsq<=1;else vsq<=raster[2];
 wire[19:0]area,ratio;wire[9:0]fill;wire done;
 wire aligned_clean=dv&&db&&dx==ax&&dy==ay;
 wire roi_clean=aligned_clean&&ax>=`HAND_X0&&ax<=`HAND_X1&&ay>=`HAND_Y0&&ay<=`HAND_Y1;
 wire raw_valid;wire[41:0]raw_box;wire[1:0]legacy_gesture;
 wire feature_valid;wire[41:0]feature_box;wire[255:0]bitmap;
 wire[10:0]rw=raw_box[21:11]-raw_box[10:0]+1,fw=feature_box[21:11]-feature_box[10:0]+1;
 wire[9:0]rh=raw_box[41:32]-raw_box[31:22]+1,fh=feature_box[41:32]-feature_box[31:22]+1;
 wire feature_matches=feature_valid&&raw_valid&&raw_box[10:0]<=feature_box[21:11]&&raw_box[21:11]>=feature_box[10:0]&&
  raw_box[31:22]<=feature_box[41:32]&&raw_box[41:32]>=feature_box[31:22]&&rw*4>=fw*3&&fw*4>=rw*3&&rh*4>=fh*3&&fh*4>=rh*3;
 gesture_sample16 features(clk,rst_n,enable,raster[2]&&!vsq,raster[0],roi_clean,ax,ay,raw_valid,raw_box,
  feature_valid,feature_box,bitmap);
 wire classified;wire[9:0]distance;wire[2:0]template_class,stable_gesture;
 wire palm_done,palm_valid,palm_evidence;wire[7:0]palm_lean;wire wave_active;
 gesture_palm_evidence palm_measure(clk,rst_n,enable,done,feature_matches&&!overflow,bitmap,
  palm_done,palm_valid,palm_evidence,palm_lean);
 // The template matcher takes 241 cycles; palm metrics finish in <=33 cycles.
 // Both sample the same committed candidate and feature bitmap.
 wire palm_support=trained==7&&!learn_busy&&feature_matches&&palm_valid&&palm_evidence&&
  fill>=200&&fill<=880&&ratio>=450&&ratio<=2600;
 assign debug_class=palm_support?3'd1:template_class;
 gesture_templates templates(clk,rst_n,enable&&(learn_state==0||learn_state==5),clear_models,learn_cmd,
  done,feature_matches&&!overflow,bitmap,ratio,classified,template_class,trained,capture_done,capture_ok,capture_error,capture_count,distance);
 // Invalid CCL frames must also advance the temporal filter; result_done does so.
 gesture_stabilizer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) stable(clk,rst_n,enable&&!clear_models,learn_busy?done:classified,overflow,
  raw_valid,raw_box,learn_busy?3'd0:debug_class,box_valid,box,stable_gesture);
 gesture_wave #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) wave(clk,rst_n,enable&&!learn_busy&&trained==7,
  classified,overflow,raw_valid,raw_box,debug_class,feature_matches&&palm_valid,palm_lean,wave_active,wave_phase);
 assign gesture=wave_active?3'd1:(stable_gesture>=2?stable_gesture:3'd0);
 assign preview=bitmap;assign preview_valid=feature_matches&&!overflow;
 reg[19:0]raw_count,clean_count;
 always @(posedge clk)begin
  if(!rst_n||!enable)begin raw_count<=0;clean_count<=0;debug_raw<=0;debug_clean<=0;end
  else begin
   if(sfs)begin debug_raw<=raw_count;raw_count<=0;end
   else if(skin_valid&&skin_raw)raw_count<=raw_count+1'b1;
   if(raster[2]&&!vsq)begin debug_clean<=clean_count;clean_count<=0;end
   else if(raster[0]&&aligned_clean)clean_count<=clean_count+1'b1;
  end
 end
 assign debug_fill=fill;assign debug_ratio=ratio;
 ep1_gesture #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.TRACK(1),.ALLOW_BOTTOM(1),.BORDER(2),
 .ROI_X0(`HAND_X0),.ROI_X1(`HAND_X1),.ROI_Y0(`HAND_Y0),.ROI_Y1(`HAND_Y1),
 .MIN_W(WIDTH/16),.MIN_H(HEIGHT/9),.MIN_AREA(WIDTH*HEIGHT/100)) stats(
 .clk(clk),.rst_n(rst_n),.frame_start(raster[2]&&!vsq),.frame_end(!raster[2]&&vsq),
 .enable(enable),.de(raster[0]),.bit_i(roi_clean),.x(ax),.y(ay),
 .box_valid(raw_valid),.xmin(raw_box[10:0]),.xmax(raw_box[21:11]),.ymin(raw_box[31:22]),.ymax(raw_box[41:32]),
 .area(area),.fill(fill),.ratio(ratio),.gesture(legacy_gesture),.overflow(overflow),.result_done(done),.reject_flags(debug_reject),.fault_flags(debug_fault));
endmodule
