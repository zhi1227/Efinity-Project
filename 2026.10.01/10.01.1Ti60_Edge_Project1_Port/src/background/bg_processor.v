`include "bg_config.vh"
// Immutable background; opening then closing; exact 8-connected flood fill.
// Debug masks double-buffered and published ONLY at display frame boundaries.
// Does NOT claim that foreground objects are semantically hands.
module bg_processor #(
 parameter ROWS=72,DIFF=`BG_DIFF_THRESHOLD,MIN_AREA=`BG_MIN_AREA,MAX_AREA=`BG_MAX_AREA,
 MAX_FOREGROUND=`BG_MAX_FOREGROUND,X0=`BG_ROI_X0,X1=`BG_ROI_X1,Y0=`BG_ROI_Y0,Y1=`BG_ROI_Y1,
 BOOT_FRAMES=`BG_BOOT_FRAMES,RELEARN_FRAMES=`BG_RELEARN_FRAMES,MIN_WIDTH=5,MIN_HEIGHT=5
)(
 input clk,rst_n,frame_start,calibrate,
 input sample_we,input[13:0]sample_addr,input[7:0]sample_gray,input sample_done,
 output capture_enable,output reg bg_ready,output waiting,learning,
 output reg result_done,result_valid,result_multi,result_scene,
 output reg[2:0]result_count,output reg[6:0]result_x,result_y,
 output reg[27:0]result_box,output reg[13:0]result_area,
 input[13:0]debug_addr,output[1:0]debug_mask,output reg display_ready
);
 localparam PIXELS=128*ROWS;
 localparam WAIT_BG=0,LEARN=1,READY=2,CAPTURE=3,F_R=4,F_T=5,F_STORE=6,
 SCAN_R=7,SCAN_T=8,Q_R=9,Q_T=10,N_R=11,N_T=12,DIV_START=13,DIV_WAIT=14,STORE=15,ADVANCE=16,FINISH=17;
 reg[4:0]state;reg[7:0]wait_frames;reg pending,display_bank,write_bank;
 assign waiting=state==WAIT_BG;
 assign learning=state==LEARN;
 assign capture_enable=(state==READY)||(state==WAIT_BG&&wait_frames==0);
 reg[7:0]background[0:PIXELS-1];reg[7:0]bg_q,gray_d;reg[13:0]addr_d;reg sample_d;
 always @(posedge clk)begin
   if(sample_we&&state==LEARN)background[sample_addr]<=sample_gray;
   if(sample_we&&state==CAPTURE)bg_q<=background[sample_addr];
   sample_d<=sample_we&&state==CAPTURE;addr_d<=sample_addr;gray_d<=sample_gray;
 end
 wire[7:0]difference=(gray_d>=bg_q)?gray_d-bg_q:bg_q-gray_d;
 wire in_roi=addr_d[6:0]>=X0&&addr_d[6:0]<X1&&addr_d[13:7]>=Y0&&addr_d[13:7]<Y1;
 wire foreground=in_roi&&difference>=DIFF;
 wire raw_we=sample_d&&state==CAPTURE;
 reg raw_mem[0:PIXELS-1],a_mem[0:PIXELS-1],b_mem[0:PIXELS-1];
 reg raw_q,a_q,b_q;reg raw_re,a_re,b_re,a_we,b_we;
 reg[13:0]raw_ra,a_ra,b_ra,a_wa,b_wa;reg a_wd,b_wd;
 always @(posedge clk)begin
   if(raw_we)raw_mem[addr_d]<=foreground;
   if(raw_re)raw_q<=raw_mem[raw_ra];
   if(a_we)a_mem[a_wa]<=a_wd;
   if(a_re)a_q<=a_mem[a_ra];
   if(b_we)b_mem[b_wa]<=b_wd;
   if(b_re)b_q<=b_mem[b_ra];
 end
 reg[1:0]view0[0:PIXELS-1],view1[0:PIXELS-1];reg[1:0]v0q,v1q;
 reg preview_we;reg[13:0]preview_addr;reg[1:0]preview_data;
 always @(posedge clk)begin
   if(preview_we&&!write_bank)view0[preview_addr]<=preview_data;
   if(preview_we&&write_bank)view1[preview_addr]<=preview_data;
   if(debug_addr<PIXELS)begin v0q<=view0[debug_addr];v1q<=view1[debug_addr];end
 end
 assign debug_mask=display_ready?(display_bank?v1q:v0q):2'b00;
 reg[13:0]queue_mem[0:PIXELS-1];reg[13:0]queue_q;
 reg queue_we,queue_re;reg[13:0]queue_wa,queue_wd,queue_ra;
 always @(posedge clk)begin
   if(queue_we)queue_mem[queue_wa]<=queue_wd;
   if(queue_re)queue_q<=queue_mem[queue_ra];
 end
 reg[13:0]scan,node,head,tail,area,fg_sum;
 reg[1:0]pass;reg[3:0]neighbor;reg acc,center_raw;
 reg[31:0]sum_x,sum_y;
 reg[6:0]xmin,xmax,ymin,ymax;
 reg[13:0]best_area,second_area;reg[6:0]best_x,best_y;reg[27:0]best_box;
 reg[2:0]candidates;
 reg[13:0]f_addr,n_addr;reg f_valid,n_valid;
 wire[6:0]fx=scan[6:0],fy=scan[13:7],nx=node[6:0],ny=node[13:7];
 wire erode=(pass==0||pass==3);
 wire f_bit=f_valid&&((pass==0)?raw_q:((pass==1||pass==3)?a_q:b_q));
 always @*begin
 f_addr=scan;f_valid=0;
 case(neighbor)
 0:begin f_addr=scan-14'd129;f_valid=fx>0&&fy>0;end
 1:begin f_addr=scan-14'd128;f_valid=fy>0;end
 2:begin f_addr=scan-14'd127;f_valid=fx<127&&fy>0;end
 3:begin f_addr=scan-14'd1;f_valid=fx>0;end
 4:begin f_addr=scan;f_valid=1;end
 5:begin f_addr=scan+14'd1;f_valid=fx<127;end
 6:begin f_addr=scan+14'd127;f_valid=fx>0&&fy<ROWS-1;end
 7:begin f_addr=scan+14'd128;f_valid=fy<ROWS-1;end
 8:begin f_addr=scan+14'd129;f_valid=fx<127&&fy<ROWS-1;end
 endcase
 n_addr=node;n_valid=0;
 case(neighbor)
 0:begin n_addr=node-14'd129;n_valid=nx>0&&ny>0;end
 1:begin n_addr=node-14'd128;n_valid=ny>0;end
 2:begin n_addr=node-14'd127;n_valid=nx<127&&ny>0;end
 3:begin n_addr=node-14'd1;n_valid=nx>0;end
 4:begin n_addr=node+14'd1;n_valid=nx<127;end
 5:begin n_addr=node+14'd127;n_valid=nx>0&&ny<ROWS-1;end
 6:begin n_addr=node+14'd128;n_valid=ny<ROWS-1;end
 7:begin n_addr=node+14'd129;n_valid=nx<127&&ny<ROWS-1;end
 endcase
 raw_re=0;raw_ra=f_addr;a_re=0;a_ra=f_addr;b_re=0;b_ra=f_addr;
 a_we=0;a_wa=scan;a_wd=acc;b_we=0;b_wa=scan;b_wd=acc;
 queue_we=0;queue_re=0;queue_ra=head;queue_wa=tail;queue_wd=n_addr;
 preview_we=raw_we;preview_addr=addr_d;preview_data={foreground,1'b0};
 if(state==F_R)begin
   if(pass==0)raw_re=f_valid;
   else if(pass==1||pass==3)a_re=f_valid;else b_re=f_valid;
   if(pass==3&&neighbor==4)begin raw_re=1;raw_ra=scan;end
 end
 if(state==F_STORE)begin
   if(pass==0||pass==2)a_we=1;else b_we=1;
   if(pass==3)begin preview_we=1;preview_addr=scan;preview_data={center_raw,acc};end
 end
 if(state==SCAN_R)begin b_re=1;b_ra=scan;end
 if(state==SCAN_T&&b_q)begin
   b_we=1;b_wa=scan;b_wd=0;queue_we=1;queue_wa=0;queue_wd=scan;
 end
 if(state==Q_R&&head<tail)queue_re=1;
 if(state==N_R&&n_valid)begin b_re=1;b_ra=n_addr;end
 if(state==N_T&&n_valid&&b_q&&tail<PIXELS)begin b_we=1;b_wa=n_addr;b_wd=0;queue_we=1;end
 end
 wire[31:0]qx,qy;wire vx,vy;
 divider dx(.clk_in(clk),.rst_in(!rst_n||calibrate),.dividend_in(sum_x),.divisor_in({18'd0,area}),
 .data_valid_in(state==DIV_START),.quotient_out(qx),.remainder_out(),.data_valid_out(vx),.error_out(),.busy_out());
 divider dy(.clk_in(clk),.rst_in(!rst_n||calibrate),.dividend_in(sum_y),.divisor_in({18'd0,area}),
 .data_valid_in(state==DIV_START),.quotient_out(qy),.remainder_out(),.data_valid_out(vy),.error_out(),.busy_out());
 reg rx,ry;reg[6:0]cx,cy;
 wire ambiguous=second_area!=0&&({1'b0,second_area}<<1)>={1'b0,best_area};
 always @(posedge clk)begin
 if(!rst_n||calibrate)begin
   state<=WAIT_BG;wait_frames<=rst_n?RELEARN_FRAMES:BOOT_FRAMES;
   bg_ready<=0;pending<=0;display_bank<=0;write_bank<=1;display_ready<=0;
   result_done<=0;result_valid<=0;result_multi<=0;result_scene<=0;result_count<=0;
   result_x<=0;result_y<=0;result_box<=0;result_area<=0;
   scan<=0;node<=0;head<=0;tail<=0;area<=0;fg_sum<=0;
   pass<=0;neighbor<=0;acc<=0;center_raw<=0;sum_x<=0;sum_y<=0;
   xmin<=0;xmax<=0;ymin<=0;ymax<=0;best_area<=0;second_area<=0;best_x<=0;best_y<=0;best_box<=0;
   candidates<=0;rx<=0;ry<=0;cx<=0;cy<=0;
 end else begin
   result_done<=0;
   if(frame_start&&pending)begin display_bank<=write_bank;display_ready<=1;pending<=0;end
   case(state)
   WAIT_BG:if(frame_start)begin
     if(wait_frames!=0)wait_frames<=wait_frames-1'b1;else state<=LEARN;
   end
   LEARN:if(sample_done)begin bg_ready<=1;state<=READY;end
   READY:if(frame_start)begin
     state<=CAPTURE;fg_sum<=0;
     write_bank<=pending?display_bank:!display_bank;
   end
   CAPTURE:begin
     if(raw_we&&foreground)fg_sum<=fg_sum+1'b1;
     if(sample_done)begin
       best_area<=0;second_area<=0;candidates<=0;best_x<=0;best_y<=0;best_box<=0;
       if(fg_sum>MAX_FOREGROUND)begin
         result_scene<=1;result_multi<=0;result_valid<=0;result_count<=0;result_area<=0;
         result_x<=0;result_y<=0;result_box<=0;
         result_done<=1;pending<=1;state<=READY;
       end else begin
         result_scene<=0;scan<=0;pass<=0;neighbor<=0;acc<=0;state<=F_R;
       end
     end
   end
   F_R:state<=F_T;
   F_T:begin
     if(neighbor==0)acc<=f_bit;else if(erode)acc<=acc&&f_bit;else acc<=acc||f_bit;
     if(pass==3&&neighbor==4)center_raw<=raw_q;
     if(neighbor==8)state<=F_STORE;else begin neighbor<=neighbor+1'b1;state<=F_R;end
   end
   F_STORE:begin
     neighbor<=0;
     if(scan==PIXELS-1)begin scan<=0;if(pass==3)state<=SCAN_R;else begin pass<=pass+1'b1;state<=F_R;end end
     else begin scan<=scan+1'b1;state<=F_R;end
   end
   SCAN_R:state<=SCAN_T;
   SCAN_T:if(b_q)begin
     head<=0;tail<=1;area<=0;sum_x<=0;sum_y<=0;
     xmin<=127;ymin<=127;xmax<=0;ymax<=0;state<=Q_R;
   end else state<=ADVANCE;
   Q_R:if(head<tail)state<=Q_T;
     else if(area>=MIN_AREA&&area<=MAX_AREA&&(xmax-xmin+1)>=MIN_WIDTH&&(ymax-ymin+1)>=MIN_HEIGHT)state<=DIV_START;
     else state<=ADVANCE;
   Q_T:begin
     node<=queue_q;head<=head+1'b1;area<=area+1'b1;
     sum_x<=sum_x+queue_q[6:0];sum_y<=sum_y+queue_q[13:7];
     if(queue_q[6:0]<xmin)xmin<=queue_q[6:0];if(queue_q[6:0]>xmax)xmax<=queue_q[6:0];
     if(queue_q[13:7]<ymin)ymin<=queue_q[13:7];if(queue_q[13:7]>ymax)ymax<=queue_q[13:7];
     neighbor<=0;state<=N_R;
   end
   N_R:state<=N_T;
   N_T:begin
     if(n_valid&&b_q&&tail<PIXELS)tail<=tail+1'b1;
     if(neighbor==7)state<=Q_R;else begin neighbor<=neighbor+1'b1;state<=N_R;end
   end
   DIV_START:begin rx<=0;ry<=0;state<=DIV_WAIT;end
   DIV_WAIT:begin
     if(vx)begin rx<=1;cx<=qx[6:0];end if(vy)begin ry<=1;cy<=qy[6:0];end
     if(rx&&ry)state<=STORE;
   end
   STORE:begin
     if(candidates<7)candidates<=candidates+1'b1;
     if(area>best_area)begin
       second_area<=best_area;best_area<=area;best_x<=cx;best_y<=cy;best_box<={ymax,ymin,xmax,xmin};
     end else if(area>second_area)second_area<=area;
     state<=ADVANCE;
   end
   ADVANCE:if(scan==PIXELS-1)state<=FINISH;else begin scan<=scan+1'b1;state<=SCAN_R;end
   FINISH:begin
     result_valid<=best_area!=0&&!ambiguous;result_multi<=ambiguous;result_count<=candidates;
     result_x<=best_x;result_y<=best_y;result_box<=best_box;result_area<=best_area;
     result_done<=1;pending<=1;state<=READY;
   end
   default:state<=WAIT_BG;
   endcase
 end
 end
endmodule

