`include "hand_config.vh"
`include "demo_model.vh"
module demo_video #(parameter BUTTON_CYCLES=1488000)(
 input clk,rst_n,input[23:0]rgb_i,input de_i,vs_i,hs_i,key_mode_n,key_freeze_n,freeze_active_async,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,output alarm_o,
 output reg freeze_request,output model_ready,output gesture_valid,output[2:0]gesture_id);
 wire pm,pf;
 button_press #(.CYCLES(BUTTON_CYCLES)) bm(clk,rst_n,key_mode_n,pm);
 button_press #(.CYCLES(BUTTON_CYCLES)) bf(clk,rst_n,key_freeze_n,pf);
 (* async_reg="true" *)reg frozen_meta,frozen_sync;
 reg frozen_last,vs_last;wire fs=vs_i&&!vs_last;reg[10:0]x;reg[9:0]y;
 reg[1:0]mode_request,mode,settle;wire scene_reset=settle!=0||(frozen_sync!=frozen_last);
 always @(posedge clk)begin
 if(!rst_n)begin vs_last<=1;x<=0;y<=0;mode_request<=0;mode<=0;freeze_request<=0;
   frozen_meta<=0;frozen_sync<=0;frozen_last<=0;settle<=0;
 end else begin
   vs_last<=vs_i;frozen_meta<=freeze_active_async;frozen_sync<=frozen_meta;frozen_last<=frozen_sync;
   if(!vs_i)begin x<=0;y<=0;end else if(de_i)begin if(x==1279)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
   if(pm)mode_request<=mode_request==2?0:mode_request+1'b1;
   if(pf)freeze_request<=!freeze_request;
   if(fs)begin mode<=mode_request;if(settle!=0)settle<=settle-1'b1;end
   if(frozen_sync!=frozen_last)settle<=2;
 end end
 wire sample_we,sample_skin,sample_done,capture_enable;wire[13:0]sample_addr;
 hand_capture capture(clk,rst_n&&!scene_reset,fs,capture_enable,de_i,x,y,rgb_i,`DEMO_PROFILE,sample_we,sample_addr,sample_skin,sample_done);
 wire result_done,result_valid,result_multi,result_clip,feature_we,display_ready,match_busy;
 wire[6:0]cx,cy;wire[27:0]box;wire[14:0]area;wire[2:0]count;
 wire[9:0]feature_addr;wire[1:0]feature_data;wire[2:0]debug_mask;wire[13:0]debug_addr;
 hand_segment segment(clk,rst_n,fs,scene_reset,match_busy,sample_we,sample_addr,sample_skin,sample_done,
 capture_enable,result_done,result_valid,result_multi,result_clip,cx,cy,box,area,count,
 feature_we,feature_addr,feature_data,debug_addr,debug_mask,display_ready);
 wire model_error;wire[11:0]score;wire decision_done;
 demo_match matcher(clk,rst_n,fs,scene_reset,feature_we,feature_addr,feature_data,
 result_done,result_valid,match_busy,model_ready,model_error,gesture_id,gesture_valid,score,decision_done);
 wire[23:0]raw;wire de,vs,hs,ev;wire[10:0]ox;wire[9:0]oy;wire[11:0]mag;
 hand_edges edges(clk,rst_n,fs,de_i,vs_i,hs_i,x,y,rgb_i,raw,de,vs,hs,ox,oy,mag,ev);
 wire roi=ox>=`HAND_X0&&ox<`HAND_X0+512&&oy>=`HAND_Y0&&oy<`HAND_Y0+512;
 wire tile=ox>=976&&ox<1232&&oy>=140&&oy<396;
 wire[8:0]rx=ox-`HAND_X0,ry=oy-`HAND_Y0;
 wire[7:0]tx=ox-976,ty=oy-140;
 assign debug_addr=tile?{ty[7:1],tx[7:1]}:(roi?{ry[8:2],rx[8:2]}:14'b0);
 reg[23:0]raw_d;reg de_d,vs_d,hs_d,ev_d,roi_d,tile_d;reg[10:0]oxd;reg[9:0]oyd;reg[11:0]mag_d;
 always @(posedge clk)begin
 if(!rst_n)begin raw_d<=0;de_d<=0;vs_d<=0;hs_d<=0;ev_d<=0;roi_d<=0;tile_d<=0;oxd<=0;oyd<=0;mag_d<=0;end
 else begin raw_d<=raw;de_d<=de;vs_d<=vs;hs_d<=hs;ev_d<=ev;roi_d<=roi;tile_d<=tile;oxd<=ox;oyd<=oy;mag_d<=mag;end end
 reg shown_valid,shown_multi,shown_clip;reg[27:0]shown_box;reg[6:0]shown_cx,shown_cy;
 reg[3:0]stale;reg got_result;reg[2:0]shown_gesture;
 always @(posedge clk)begin
 if(!rst_n||scene_reset)begin shown_valid<=0;shown_multi<=0;shown_clip<=0;shown_box<=0;shown_cx<=0;shown_cy<=0;stale<=0;got_result<=0;shown_gesture<=0;end
 else begin
   if(result_done)got_result<=1;
   if(fs)begin
     shown_gesture<=gesture_valid?gesture_id:0;
     if(got_result||result_done)begin shown_valid<=result_valid;shown_multi<=result_multi;shown_clip<=result_clip;shown_box<=box;shown_cx<=cx;shown_cy<=cy;stale<=0;got_result<=0;end
     else if(stale<8)stale<=stale+1'b1;else begin shown_valid<=0;shown_gesture<=0;end
   end
 end end
 wire[10:0]bx0=`HAND_X0+{shown_box[6:0],2'b0},bx1=`HAND_X0+{shown_box[13:7],2'b0}+3;
 wire[9:0]by0=`HAND_Y0+{shown_box[20:14],2'b0},by1=`HAND_Y0+{shown_box[27:21],2'b0}+3;
 wire bbox=shown_valid&&oxd>=bx0&&oxd<=bx1&&oyd>=by0&&oyd<=by1;
 wire box_edge=bbox&&(oxd-bx0<2||bx1-oxd<2||oyd-by0<2||by1-oyd<2);
 wire[10:0]center_x=`HAND_X0+{shown_cx,2'b0}+2;
 wire[9:0]center_y=`HAND_Y0+{shown_cy,2'b0}+2;
 wire center_mark=shown_valid&&((oxd==center_x&&oyd+8>=center_y&&oyd<=center_y+8)||(oyd==center_y&&oxd+8>=center_x&&oxd<=center_x+8));
 wire roi_edge=roi_d&&(oxd==`HAND_X0||oxd==`HAND_X0+511||oyd==`HAND_Y0||oyd==`HAND_Y0+511);
 wire wrist=roi_d&&oyd==`HAND_Y0+4*`HAND_WRIST_ROW;
 wire hud_area,hud_ink;
 demo_text hud(clk,rst_n,ox,oy,mode,model_ready,model_error,`DEMO_MODEL_VALID!=0,frozen_sync,shown_valid,shown_multi,shown_clip,shown_gesture,hud_area,hud_ink);
 wire[34:0]bigglyph;hand_font bigfont(shown_gesture==0?8'h2d:8'h30+shown_gesture,bigglyph);
 wire[7:0]gx=(oxd-1048)/20,gy=(oyd-480)/20;
 wire big_area=oxd>=976&&oxd<1232&&oyd>=456&&oyd<640;
 wire big_ink=oxd>=1048&&oyd>=480&&gx<5&&gy<7&&bigglyph[34-gy*5-gx];
 wire[15:0]gray_sum=raw_d[23:16]*16'd77+raw_d[15:8]*16'd150+raw_d[7:0]*16'd29;
 wire[7:0]gray=gray_sum[15:8];wire edge_bit=ev_d&&mag_d>=`HAND_SOBEL_THRESHOLD;
 reg[23:0]color;
 always @*begin
 color=raw_d;
 if(mode==0)begin
   if(roi_d&&debug_mask[0]&&shown_valid)color=24'hff3030;
   if(tile_d)color=debug_mask[1]?24'hffffff:24'h101018;
   if(roi_edge)color=(shown_multi||shown_clip)?24'hff3030:24'h00dddd;
   if(wrist)color=24'h808080;
   if(box_edge)color=24'h00ff40;
   if(center_mark)color=24'hffff00;
   if(big_area)color=big_ink?(model_ready?24'h00ff60:24'hffcc00):24'h101018;
 end else if(mode==1)begin
   color=oxd<640?{gray,gray,gray}:(edge_bit?24'hffffff:0);
   if(oxd==640)color=24'h00ffff;
 end
 if(mode!=2&&hud_area)color=hud_ink?24'hffffff:24'h101018;
 end
 assign alarm_o=shown_multi||shown_clip||model_error;
 always @(posedge clk)begin
 if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de_d?color:0;de_o<=de_d;vs_o<=vs_d;hs_o<=hs_d;end end
endmodule
