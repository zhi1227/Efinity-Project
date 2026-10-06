`include "gesture_config.vh"
// Single-camera Ti60 adaptation; upstream algorithm concepts, portable RAM.
module gesture_video #(parameter BUTTON_CYCLES=1488000,WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,input [23:0] rgb_i,input de_i,vs_i,hs_i,key_mode_n,key_profile_n,
 output reg [23:0] rgb_o,output reg de_o,vs_o,hs_o,output overflow_o);
 wire press_mode,press_profile;
 button_press #(.CYCLES(BUTTON_CYCLES)) bm(clk,rst_n,key_mode_n,press_mode);
 button_press #(.CYCLES(BUTTON_CYCLES)) bp(clk,rst_n,key_profile_n,press_profile);
 reg [1:0] mode_request,profile_request,mode,profile;
 reg vs_last;
 wire fs=vs_i&&!vs_last;
 wire profile_change=fs&&(profile!=profile_request);
 wire algo_rst_n=rst_n&&!profile_change;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin vs_last<=1;mode_request<=0;mode<=0;profile_request<=`GESTURE_DEFAULT_PROFILE;profile<=`GESTURE_DEFAULT_PROFILE;end
 else begin
   vs_last<=vs_i;
   if(press_mode)mode_request<=mode_request+1'b1;
   if(press_profile)profile_request<=(profile_request==2)?0:profile_request+1'b1;
   if(fs)begin mode<=mode_request;profile<=profile_request;end
 end
 reg [10:0] x;reg [9:0] y;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;end
 else if(!vs_i)begin x<=0;y<=0;end
 else if(de_i)begin
   if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
 end
 wire [7:0] r=rgb_i[23:16],g=rgb_i[15:8],b=rgb_i[7:0];
 // Explicit 9-bit addition avoids threshold wraparound at high brightness.
 wire pink=r>=96 && b>=64 && {1'b0,r}>({1'b0,g}+9'd32) && {1'b0,b}>({1'b0,g}+9'd16);
 wire green=g>=80 && {1'b0,g}>({1'b0,r}+9'd32) && {1'b0,g}>({1'b0,b}+9'd24);
 wire skin;wire skin_de;wire [10:0] skin_x;wire [9:0] skin_y;
 rgb565_to_ycbcr_skin sk(.clk(clk),.rst_n(rst_n),.de_i(de_i),.x_i(x),.y_i(y),
   .rgb565_i({r[7:3],g[7:2],b[7:3]}),.cb_min_i(8'd77),.cb_max_i(8'd127),
   .cr_min_i(8'd133),.cr_max_i(8'd173),.y_min_i(8'd40),.y_max_i(8'd235),
   .skin_o(skin),.de_o(skin_de),.x_o(skin_x),.y_o(skin_y));
 reg [23:0] rgb_d;reg de_d,vs_d,hs_d,fs_d,pink_d,green_d;
 reg [10:0] xd;reg [9:0] yd;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rgb_d<=0;de_d<=0;vs_d<=0;hs_d<=0;fs_d<=0;pink_d<=0;green_d<=0;xd<=0;yd<=0;end
 else begin
   rgb_d<=rgb_i;de_d<=de_i;vs_d<=vs_i;hs_d<=hs_i;fs_d<=fs;
   pink_d<=pink;green_d<=green;xd<=x;yd<=y;
 end
 wire roi=xd>=`GESTURE_ROI_X0&&xd<`GESTURE_ROI_X1&&yd>=`GESTURE_ROI_Y0&&yd<`GESTURE_ROI_Y1;
 wire selected_mask=de_d&&roi&&((profile==0)?pink_d:((profile==1)?green_d:skin));
 wire we,load_bit,start,capturing,busy,done,core_overflow;
 wire [11:0] addr;wire [2:0] result_count;
 wire [29:0] cx,cy;wire [119:0] bbox;wire [59:0] areas;
 mask_thumbnail #(.THRESHOLD(`GESTURE_BLOCK_THRESHOLD)) thumb(
   clk,algo_rst_n,fs_d,de_d,selected_mask,!busy,we,addr,load_bit,start,capturing);
 blob_snapshot #(.MIN_AREA(`GESTURE_MIN_CELLS),.MAX_AREA(`GESTURE_MAX_CELLS)) core(
   clk,algo_rst_n,we,addr,load_bit,start,busy,done,core_overflow,result_count,cx,cy,bbox,areas);
 wire wave;wire [7:0] wave_events;
 gesture_motion motion(clk,algo_rst_n,fs_d,done,result_count,cx[5:0],wave,wave_events);
 reg [2:0] shown_count;reg [29:0] shown_x,shown_y;
 reg [119:0] shown_boxes;reg shown_overflow,shown_wave;
 reg [2:0] stale;
 reg got_result;
 // Profile changes are synchronous frame-boundary resets, not new async domains.
 always @(posedge clk)
 if(!algo_rst_n)begin
   shown_count<=0;shown_x<=0;shown_y<=0;shown_boxes<=0;
   shown_overflow<=0;shown_wave<=0;stale<=0;got_result<=0;
 end else begin
   if(done)got_result<=1;
   if(fs_d)begin
     shown_wave<=wave;
     if(got_result || done)begin
       shown_count<=result_count;shown_x<=cx;shown_y<=cy;
       shown_boxes<=bbox;shown_overflow<=core_overflow;stale<=0;got_result<=0;
     end else if(stale<3)stale<=stale+1'b1;
     else begin shown_count<=0;shown_overflow<=0;end
   end
 end
 assign overflow_o=shown_overflow;
 integer i;
 reg border,crosshair;
 reg [10:0] x0,x1,xc;reg [9:0] y0,y1,yc;
 always @*begin
   border=0;crosshair=0;x0=0;x1=0;y0=0;y1=0;xc=0;yc=0;
   for(i=0;i<5;i=i+1)begin
     x0={5'd0,shown_boxes[i*24+:6]}*11'd20;
     x1=({5'd0,shown_boxes[i*24+6+:6]}+11'd1)*11'd20-1;
     y0={4'd0,shown_boxes[i*24+12+:6]}*10'd20;
     y1=({4'd0,shown_boxes[i*24+18+:6]}+10'd1)*10'd20-1;
     xc={5'd0,shown_x[i*6+:6]}*11'd20+11'd10;
     yc={4'd0,shown_y[i*6+:6]}*10'd20+10'd10;
     if(i<shown_count)begin
       if(xd>=x0&&xd<=x1&&yd>=y0&&yd<=y1&&(xd-x0<2||x1-xd<2||yd-y0<2||y1-yd<2))border=1;
       if((xd==xc&&yd+8>=yc&&yd<=yc+8)||(yd==yc&&xd+8>=xc&&xd<=xc+8))crosshair=1;
     end
   end
 end
 wire roi_border=roi&&(xd==`GESTURE_ROI_X0||xd==`GESTURE_ROI_X1-1||yd==`GESTURE_ROI_Y0||yd==`GESTURE_ROI_Y1-1);
 wire hud_area,hud_ink;
 gesture_hud hud(xd,yd,mode,profile,shown_count,shown_wave,shown_overflow,hud_area,hud_ink);
 reg [23:0] colour;
 always @*begin
   case(mode)
   1:colour=selected_mask?24'hffffff:0;
   2:colour=(xd<WIDTH/2)?rgb_d:(selected_mask?24'hffffff:0);
   default:colour=rgb_d;
   endcase
   if(mode!=3)begin
     if(roi_border)colour=24'h00ffff;
     if(border)colour=24'h00ff00;
     if(crosshair)colour=24'hffff00;
   end
   if(hud_area)colour=hud_ink?(shown_wave?24'hffff00:24'hffffff):24'h101020;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de_d?colour:0;de_o<=de_d;vs_o<=vs_d;hs_o<=hs_d;end
endmodule
