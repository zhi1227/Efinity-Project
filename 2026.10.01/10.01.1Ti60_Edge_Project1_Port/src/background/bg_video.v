`include "bg_config.vh"
// Board-facing module. Same active-low video sync convention as proven base.
// Three registered pixel stages; raw and cleaned masks are frame-atomic snapshots.
module bg_video #(parameter BUTTON_CYCLES=1488000,BOOT_FRAMES=`BG_BOOT_FRAMES,RELEARN_FRAMES=`BG_RELEARN_FRAMES)(
 input clk,rst_n,input[23:0]rgb_i,input de_i,vs_i,hs_i,key_mode_n,key_bg_n,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,output alarm_o);
 wire press_mode,press_bg;
 button_press #(.CYCLES(BUTTON_CYCLES)) bm(clk,rst_n,key_mode_n,press_mode);
 button_press #(.CYCLES(BUTTON_CYCLES)) bb(clk,rst_n,key_bg_n,press_bg);
 reg vs_last;wire fs=vs_i&&!vs_last;
 reg[2:0]mode_request,mode;reg[10:0]x;reg[9:0]y;
 always @(posedge clk)begin
 if(!rst_n)begin vs_last<=1;mode_request<=0;mode<=0;x<=0;y<=0;end
 else begin
   vs_last<=vs_i;
   if(press_mode)mode_request<=(mode_request==4)?0:mode_request+1'b1;
   if(fs)mode<=mode_request;
   if(!vs_i)begin x<=0;y<=0;end
   else if(de_i)begin if(x==1279)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
 end
 end
 wire[9:0]luma_sum={2'b0,rgb_i[23:16]}+{1'b0,rgb_i[15:8],1'b0}+{2'b0,rgb_i[7:0]};
 reg[23:0]rgb0,rgb1;reg[7:0]gray0;reg de0,vs0,hs0,fs0,de1,vs1,hs1;
 reg[10:0]x0,x1;reg[9:0]y0,y1;
 always @(posedge clk)begin
 if(!rst_n)begin rgb0<=0;rgb1<=0;gray0<=0;de0<=0;vs0<=0;hs0<=0;fs0<=0;de1<=0;vs1<=0;hs1<=0;x0<=0;x1<=0;y0<=0;y1<=0;end
 else begin
   rgb0<=rgb_i;gray0<=luma_sum[9:2];de0<=de_i;vs0<=vs_i;hs0<=hs_i;fs0<=fs;x0<=x;y0<=y;
   rgb1<=rgb0;de1<=de0;vs1<=vs0;hs1<=hs0;x1<=x0;y1<=y0;
 end
 end
 wire sample_we,sample_done,capture_enable;wire[13:0]sample_addr;wire[7:0]sample_gray;
 bg_thumbnail thumb(clk,rst_n&&!press_bg,fs0,capture_enable,de0,gray0,sample_we,sample_addr,sample_gray,sample_done);
 wire bg_ready,waiting,learning,result_done,result_valid,result_multi,result_scene,display_ready;
 wire[2:0]result_count;wire[6:0]result_x,result_y;wire[27:0]result_box;wire[13:0]result_area;
 wire[6:0]debug_x=x0/10,debug_y=y0/10;
 wire[13:0]debug_addr={debug_y,debug_x};wire[1:0]mask;
 bg_processor #(.BOOT_FRAMES(BOOT_FRAMES),.RELEARN_FRAMES(RELEARN_FRAMES)) processor(
 clk,rst_n,fs0,press_bg,sample_we,sample_addr,sample_gray,sample_done,capture_enable,bg_ready,waiting,learning,
 result_done,result_valid,result_multi,result_scene,result_count,result_x,result_y,result_box,result_area,
 debug_addr,mask,display_ready);
 wire[2:0]event_code;wire event_pulse;wire[7:0]event_count;wire[6:0]hold_progress;
 bg_actions actions(clk,rst_n&&!press_bg,fs0,result_done,result_valid,result_x,result_y,event_code,event_pulse,event_count,hold_progress);
 reg shown_valid,shown_multi,shown_scene,got_result;reg[2:0]shown_count,shown_event;
 reg[7:0]shown_events;reg[6:0]shown_x,shown_y,shown_hold;reg[27:0]shown_box;
 reg[3:0]stale;
 always @(posedge clk)begin
 if(!rst_n||press_bg)begin
   shown_valid<=0;shown_multi<=0;shown_scene<=0;got_result<=0;shown_count<=0;shown_event<=0;
   shown_events<=0;shown_x<=0;shown_y<=0;shown_hold<=0;shown_box<=0;stale<=0;
 end else begin
   if(result_done)got_result<=1;
   if(fs0)begin
     shown_event<=event_code;shown_events<=event_count;shown_hold<=hold_progress;
     if(got_result||result_done)begin
       shown_valid<=result_valid;shown_multi<=result_multi;shown_scene<=result_scene;
       shown_count<=result_count;shown_x<=result_x;shown_y<=result_y;shown_box<=result_box;
       got_result<=0;stale<=0;
     end else if(stale<6)stale<=stale+1'b1;
     else begin shown_valid<=0;shown_count<=0;shown_hold<=0;end
   end
 end
 end
 wire[10:0]bx0=shown_box[6:0]*11'd10,bx1=(shown_box[13:7]+11'd1)*11'd10-11'd1;
 wire[9:0]by0=shown_box[20:14]*10'd10,by1=(shown_box[27:21]+10'd1)*10'd10-10'd1;
 wire[10:0]center_x=shown_x*11'd10+11'd5;wire[9:0]center_y=shown_y*10'd10+10'd5;
 wire box_edge=shown_valid&&x1>=bx0&&x1<=bx1&&y1>=by0&&y1<=by1&&(x1-bx0<2||bx1-x1<2||y1-by0<2||by1-y1<2);
 wire crosshair=shown_valid&&((x1==center_x&&y1+8>=center_y&&y1<=center_y+8)||(y1==center_y&&x1+8>=center_x&&x1<=center_x+8));
 wire roi=x1>=200&&x1<1080&&y1>=120&&y1<680;
 wire roi_edge=roi&&(x1==200||x1==1079||y1==120||y1==679);
 wire hold_edge=x1>=550&&x1<730&&y1>=250&&y1<510&&(x1==550||x1==729||y1==250||y1==509);
 wire hud_area,hud_ink;
 bg_hud hud(x1,y1,mode,shown_count,shown_event,waiting,learning,bg_ready,shown_valid,shown_multi,shown_scene,shown_events,hud_area,hud_ink);
 reg[23:0]color,accent;
 always @*begin
   case(shown_event)1:accent=24'h0080ff;2:accent=24'hff8000;3:accent=24'hff00ff;4:accent=24'h00ff00;default:accent=24'h00ffff;endcase
   case(mode)
   1:color=mask[1]?24'hffffff:0;
   2:color=mask[0]?24'hffffff:0;
   3:color=(x1<640)?rgb1:(mask[0]?24'hffffff:0);
   default:color=rgb1;
   endcase
   if(mode!=4)begin
     if(roi_edge)color=(waiting||learning||shown_scene)?24'hff3030:accent;
     if(hold_edge)color=24'h406040;
     if(box_edge)color=24'h00ff00;
     if(crosshair)color=24'hffff00;
     if(x1>=200&&x1<1080&&y1>=696&&y1<704)color=(x1-200<shown_hold*14)?24'h00ff00:24'h303030;
   end
   if(hud_area)color=hud_ink?24'hffffff:24'h101020;
 end
 assign alarm_o=shown_multi||shown_scene;
 always @(posedge clk)begin
 if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de1?color:0;de_o<=de1;vs_o<=vs1;hs_o<=hs1;end
 end
endmodule

