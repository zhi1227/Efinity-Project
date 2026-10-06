`include "hand_config.vh"
module hand_video #(parameter BUTTON_CYCLES=1488000,CLEAR_CYCLES=148800000)(
 input clk,rst_n,input[23:0]rgb_i,input de_i,vs_i,hs_i,key_mode_n,key_learn_n,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,output alarm_o);
 wire pm,pk;
 button_press #(.CYCLES(BUTTON_CYCLES)) bm(clk,rst_n,key_mode_n,pm);
 button_press #(.CYCLES(BUTTON_CYCLES)) bk(clk,rst_n,key_learn_n,pk);
 reg vs_last;wire fs=vs_i&&!vs_last;reg[10:0]x;reg[9:0]y;
 reg[2:0]mode_request,mode,learn_id;reg[1:0]profile;
 reg key_s1,key_s2,long_fired;reg[27:0]long_count;reg clear_templates,scene_reset;
 reg learn_armed,teach_release;reg[31:0]release_count;
 wire learned,learn_failed,teach_pending;reg[6:0]save_timer,fail_timer;
 always @(posedge clk)begin
 if(!rst_n)begin vs_last<=1;x<=0;y<=0;mode_request<=0;mode<=0;learn_id<=1;profile<=0;
   key_s1<=1;key_s2<=1;long_fired<=0;long_count<=0;clear_templates<=0;scene_reset<=0;save_timer<=0;fail_timer<=0;
   learn_armed<=0;teach_release<=0;release_count<=0;
 end else begin
   vs_last<=vs_i;key_s1<=key_learn_n;key_s2<=key_s1;clear_templates<=0;scene_reset<=0;teach_release<=0;
   if(pk&&mode==7)begin learn_armed<=1;release_count<=0;end
   if(learn_armed)begin
     if(key_s2)begin
       if(release_count==BUTTON_CYCLES-1)begin teach_release<=1;learn_armed<=0;release_count<=0;end
       else release_count<=release_count+1'b1;
     end else release_count<=0;
   end
   if(pm||mode!=7)begin learn_armed<=0;release_count<=0;end
   if(!vs_i)begin x<=0;y<=0;end else if(de_i)begin if(x==1279)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
   if(pm)mode_request<=mode_request+1'b1;
   if(fs)begin mode<=mode_request;if(save_timer!=0)save_timer<=save_timer-1'b1;if(fail_timer!=0)fail_timer<=fail_timer-1'b1;end
   if(pk&&mode!=7)begin profile<=(profile==2)?0:profile+1'b1;scene_reset<=1;end
   if(learned)begin save_timer<=60;if(learn_id==5)begin learn_id<=1;mode_request<=0;end else learn_id<=learn_id+1'b1;end
   if(learn_failed)fail_timer<=90;
   if(key_s2||mode!=7)begin long_count<=0;long_fired<=0;end
   else if(!long_fired)begin
     if(long_count==CLEAR_CYCLES-1)begin clear_templates<=1;long_fired<=1;learn_id<=1;learn_armed<=0;end else long_count<=long_count+1'b1;
   end
 end end
 wire sample_we,sample_skin,sample_done,capture_enable;wire[13:0]sample_addr;
 hand_capture capture(clk,rst_n&&!scene_reset,fs,capture_enable,de_i,x,y,rgb_i,profile,sample_we,sample_addr,sample_skin,sample_done);
 wire result_done,result_valid,result_multi,result_clip,feature_we,display_ready,match_busy;
 wire[6:0]cx,cy;wire[27:0]box;wire[14:0]area;wire[2:0]count;wire[9:0]feature_addr;wire[1:0]feature_data;
 wire[2:0]debug_mask;wire[13:0]debug_addr;
 hand_segment segment(clk,rst_n,fs,scene_reset,match_busy,sample_we,sample_addr,sample_skin,sample_done,
 capture_enable,result_done,result_valid,result_multi,result_clip,cx,cy,box,area,count,
 feature_we,feature_addr,feature_data,debug_addr,debug_mask,display_ready);
 wire[4:0]trained;wire[2:0]gesture;wire[11:0]score;wire decision_done;
 hand_match matcher(clk,rst_n,fs,scene_reset,clear_templates,feature_we,feature_addr,feature_data,
 result_done,result_valid,teach_release&&mode==7,learn_id,pm,match_busy,teach_pending,learned,learn_failed,trained,gesture,score,decision_done);
 wire[2:0]action;wire ap;wire[7:0]events;wire[6:0]hold;
 // Map hand ROI center into the old full-frame 10-pixel grid for trajectory rules.
 wire[6:0]action_x=(`HAND_X0+{cx,2'b0})/10,action_y=(`HAND_Y0+{cy,2'b0})/10;
 bg_actions actions(clk,rst_n&&!scene_reset,fs,result_done,result_valid,action_x,action_y,action,ap,events,hold);
 wire[23:0]raw;wire de,vs,hs,ev;wire[10:0]ox;wire[9:0]oy;wire[11:0]mag;
 hand_edges edges(clk,rst_n,fs,de_i,vs_i,hs_i,x,y,rgb_i,raw,de,vs,hs,ox,oy,mag,ev);
 wire roi=ox>=`HAND_X0&&ox<`HAND_X0+512&&oy>=`HAND_Y0&&oy<`HAND_Y0+512;
 wire[8:0]rx=ox-`HAND_X0,ry=oy-`HAND_Y0;
 assign debug_addr=roi?{ry[8:2],rx[8:2]}:14'b0;
 reg[23:0]raw_d;reg de_d,vs_d,hs_d,ev_d,roi_d;reg[10:0]oxd;reg[9:0]oyd;reg[11:0]mag_d;
 always @(posedge clk)begin
 if(!rst_n)begin raw_d<=0;de_d<=0;vs_d<=0;hs_d<=0;ev_d<=0;roi_d<=0;oxd<=0;oyd<=0;mag_d<=0;end
 else begin raw_d<=raw;de_d<=de;vs_d<=vs;hs_d<=hs;ev_d<=ev;roi_d<=roi;oxd<=ox;oyd<=oy;mag_d<=mag;end end
 reg shown_valid,shown_multi,shown_clip;reg[27:0]shown_box;reg[6:0]shown_cx,shown_cy;reg[3:0]stale;
 reg got_result;reg[2:0]shown_gesture,shown_action;reg[11:0]shown_score;
 always @(posedge clk)begin
 if(!rst_n||scene_reset)begin shown_valid<=0;shown_multi<=0;shown_clip<=0;shown_box<=0;shown_cx<=0;shown_cy<=0;stale<=0;got_result<=0;shown_gesture<=0;shown_action<=0;shown_score<=4095;end
 else begin
   if(result_done)got_result<=1;
   if(fs)begin
     shown_gesture<=gesture;shown_action<=action;shown_score<=score;
     if(got_result||result_done)begin shown_valid<=result_valid;shown_multi<=result_multi;shown_clip<=result_clip;shown_box<=box;shown_cx<=cx;shown_cy<=cy;stale<=0;got_result<=0;end
     else if(stale<8)stale<=stale+1'b1;else begin shown_valid<=0;shown_gesture<=0;shown_action<=0;end
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
 wire hud_area,hud_ink,big_area,big_ink;
 hand_hud hud(oxd,oyd,mode,shown_gesture,learn_id,shown_action,profile,trained,shown_valid,shown_multi,shown_clip,
 teach_pending,save_timer!=0,fail_timer!=0,shown_score,hud_area,hud_ink,big_area,big_ink);
 wire[15:0]gray_sum=raw_d[23:16]*16'd77+raw_d[15:8]*16'd150+raw_d[7:0]*16'd29;
 wire[7:0]gray=gray_sum[15:8],amp=mag_d>255?255:mag_d[7:0];
 wire edge_bit=ev_d&&mag_d>=`HAND_SOBEL_THRESHOLD;
 reg[23:0]color;
 always @*begin
 color=raw_d;
 case(mode)
 0:if(bbox)color=debug_mask[1]?24'hffffff:24'h080810;
 1:if(roi_d&&debug_mask[0]&&shown_valid)color=24'hff3030;
 2:if(roi_d)color=debug_mask[2]?24'hffffff:0;
 3,7:if(roi_d)color=debug_mask[1]?24'hffffff:0;
 4:if(roi_d)color=debug_mask[0]?24'hffffff:0;
 5:color=(oxd<640)?{gray,gray,gray}:(edge_bit?24'hffffff:0);
 6:color=(ev_d&&amp>=8)?{amp>>1,amp,8'hff-amp}:0;
 endcase
 if(mode!=5&&mode!=6)begin
   if(roi_edge)color=(shown_multi||shown_clip)?24'hff3030:24'h00dddd;
   if(wrist)color=24'h808080;
   if(box_edge)color=24'h00ff40;
   if(center_mark)color=24'hffff00;
 end
 if(mode==5&&oxd==640)color=24'h00ffff;
 if(big_area)color=big_ink?((trained==31)?24'h00ff60:24'hffcc00):24'h101018;
 if(hud_area)color=hud_ink?24'hffffff:24'h101018;
 end
 assign alarm_o=shown_multi||shown_clip;
 always @(posedge clk)begin
 if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de_d?color:0;de_o<=de_d;vs_o<=vs_d;hs_o<=hs_d;end end
endmodule
