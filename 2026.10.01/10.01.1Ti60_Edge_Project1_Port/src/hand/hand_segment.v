`include "hand_config.vh"
// Snapshot engine: binary median -> exact 8-neighbour components -> largest
// component -> Sobel silhouette -> box-normalized 32x32 mask + Sobel features.
// Fixed wrist line clips the arm. This is NOT semantic hand detection.
module hand_segment #(parameter MIN_AREA=`HAND_MIN_AREA,MAX_AREA=`HAND_MAX_AREA)(
 input clk,rst_n,frame_start,reset_scene,matcher_busy,
 input sample_we,input[13:0]sample_addr,input sample_skin,sample_done,
 output capture_enable,output reg result_done,result_valid,result_multi,result_clip,
 output reg[6:0]result_x,result_y,output reg[27:0]result_box,output reg[14:0]result_area,
 output reg[2:0]result_count,
 output reg feature_we,output reg[9:0]feature_addr,output reg[1:0]feature_data,
 input[13:0]debug_addr,output[2:0]debug_mask,output reg display_ready);
 localparam READY=0,CAPTURE=1,F_R=2,F_T=3,F_W=4,SCAN_R=5,SCAN_T=6,
 Q_R=7,Q_T=8,N_R=9,N_T=10,ADV=11,SELECT=12,CLEAR_R=13,CLEAR_T=14,
 SEED=15,DIV_S=16,DIV_W=17,EDGE_R=18,EDGE_T=19,EDGE_W=20,
 NORM_R=21,NORM_T=22,FE_R=23,FE_T=24,FE_W=25,FINISH=26,WAIT_PUBLISH=27;
 reg[4:0]state;
 reg raw_mem[0:16383],clean_mem[0:16383],work_mem[0:16383],selected_mem[0:16383];
 reg raw_q,clean_q,work_q,selected_q;
 reg raw_re,clean_re,work_re,selected_re,clean_we,work_we,selected_we;
 reg[13:0]raw_ra,clean_ra,work_ra,selected_ra,clean_wa,work_wa,selected_wa;
 reg clean_wd,work_wd,selected_wd;
 reg[13:0]queue_mem[0:16383];reg[13:0]queue_q;
 reg queue_we,queue_re;reg[13:0]queue_wa,queue_ra,queue_wd;
 reg normalized_mem[0:1023];reg norm_q;reg norm_re,norm_we;reg[9:0]norm_ra,norm_wa;reg norm_wd;
 reg[2:0]view0[0:16383],view1[0:16383];reg[2:0]v0q,v1q;
 reg view_we,display_bank,write_bank,pending;reg[13:0]view_addr;reg[2:0]view_data;
 wire roi_ok=sample_addr[6:0]>=2&&sample_addr[6:0]<=125&&sample_addr[13:7]>=2&&sample_addr[13:7]<`HAND_WRIST_ROW;
 always @(posedge clk)begin
   if(sample_we&&state==CAPTURE)raw_mem[sample_addr]<=sample_skin&&roi_ok;
   if(raw_re)raw_q<=raw_mem[raw_ra];
   if(clean_we)clean_mem[clean_wa]<=clean_wd;if(clean_re)clean_q<=clean_mem[clean_ra];
   if(work_we)work_mem[work_wa]<=work_wd;if(work_re)work_q<=work_mem[work_ra];
   if(selected_we)selected_mem[selected_wa]<=selected_wd;if(selected_re)selected_q<=selected_mem[selected_ra];
   if(queue_we)queue_mem[queue_wa]<=queue_wd;if(queue_re)queue_q<=queue_mem[queue_ra];
   if(norm_we)normalized_mem[norm_wa]<=norm_wd;if(norm_re)norm_q<=normalized_mem[norm_ra];
   if(view_we&&!write_bank)view0[view_addr]<=view_data;
   if(view_we&&write_bank)view1[view_addr]<=view_data;
   v0q<=view0[debug_addr];v1q<=view1[debug_addr];
 end
 assign debug_mask=display_ready?(display_bank?v1q:v0q):3'b0;
 assign capture_enable=state==READY&&!matcher_busy;
 reg[13:0]scan,node,best_seed;reg[14:0]head,tail,area,best_area,second_area;
 reg[6:0]xmin,xmax,ymin,ymax,bxmin,bxmax,bymin,bymax;
 reg[31:0]sum_x,sum_y,best_sumx,best_sumy;
 reg[3:0]neighbor,ones;reg second_pass;
 reg[2:0]candidates;
 reg[13:0]neighbor_addr;reg neighbor_valid;
 wire[6:0]nx=node[6:0],ny=node[13:7],sx=scan[6:0],sy=scan[13:7];
 reg[13:0]filter_addr;reg filter_valid;
 reg[9:0]norm_index;reg[9:0]norm_neighbor;reg norm_neighbor_valid;
 reg signed[5:0]gx,gy;reg center_bit,original_bit;
 wire[5:0]abs_gx=gx[5]?-gx:gx,abs_gy=gy[5]?-gy:gy;
 wire sobel_bit=({1'b0,abs_gx}+{1'b0,abs_gy})>=2;
 wire[7:0]box_w={1'b0,bxmax}-{1'b0,bxmin}+1'b1,box_h={1'b0,bymax}-{1'b0,bymin}+1'b1;
 wire[13:0]norm_product_x=({1'b0,norm_index[4:0],1'b1}*box_w);
 wire[13:0]norm_product_y=({1'b0,norm_index[9:5],1'b1}*box_h);
 wire[6:0]norm_source_x=bxmin+norm_product_x[12:6],norm_source_y=bymin+norm_product_y[12:6];
 wire ambiguous=second_area!=0&&({1'b0,second_area}<<1)>={1'b0,best_area};
 // Crop at wrist is intentional; touching top/left/right means an incomplete hand.
 wire clipped=bxmin<=2||bxmax>=125||bymin<=2;
 wire accept=best_area!=0&&!ambiguous&&!clipped;
 wire[31:0]div_x,div_y;wire vx,vy;reg gotx,goty;reg[6:0]cx,cy;
 divider dx(clk,!rst_n||reset_scene,best_sumx,{17'd0,best_area},state==DIV_S,div_x,,vx,,);
 divider dy(clk,!rst_n||reset_scene,best_sumy,{17'd0,best_area},state==DIV_S,div_y,,vy,,);
 function signed[5:0]weight_x;input[3:0]k;begin case(k)0,6:weight_x=-1;3:weight_x=-2;2,8:weight_x=1;5:weight_x=2;default:weight_x=0;endcase end endfunction
 function signed[5:0]weight_y;input[3:0]k;begin case(k)0,2:weight_y=-1;1:weight_y=-2;6,8:weight_y=1;7:weight_y=2;default:weight_y=0;endcase end endfunction
 always @*begin
   filter_addr=scan;filter_valid=0;
   case(neighbor)
   0:begin filter_addr=scan-129;filter_valid=sx>0&&sy>0;end
   1:begin filter_addr=scan-128;filter_valid=sy>0;end
   2:begin filter_addr=scan-127;filter_valid=sx<127&&sy>0;end
   3:begin filter_addr=scan-1;filter_valid=sx>0;end
   4:begin filter_addr=scan;filter_valid=1;end
   5:begin filter_addr=scan+1;filter_valid=sx<127;end
   6:begin filter_addr=scan+127;filter_valid=sx>0&&sy<127;end
   7:begin filter_addr=scan+128;filter_valid=sy<127;end
   8:begin filter_addr=scan+129;filter_valid=sx<127&&sy<127;end endcase
   neighbor_addr=node;neighbor_valid=0;
   case(neighbor)
   0:begin neighbor_addr=node-129;neighbor_valid=nx>0&&ny>0;end
   1:begin neighbor_addr=node-128;neighbor_valid=ny>0;end
   2:begin neighbor_addr=node-127;neighbor_valid=nx<127&&ny>0;end
   3:begin neighbor_addr=node-1;neighbor_valid=nx>0;end
   4:begin neighbor_addr=node+1;neighbor_valid=nx<127;end
   5:begin neighbor_addr=node+127;neighbor_valid=nx>0&&ny<127;end
   6:begin neighbor_addr=node+128;neighbor_valid=ny<127;end
   7:begin neighbor_addr=node+129;neighbor_valid=nx<127&&ny<127;end endcase
   norm_neighbor=norm_index;norm_neighbor_valid=0;
   case(neighbor)
   0:begin norm_neighbor=norm_index-33;norm_neighbor_valid=norm_index[4:0]>0&&norm_index[9:5]>0;end
   1:begin norm_neighbor=norm_index-32;norm_neighbor_valid=norm_index[9:5]>0;end
   2:begin norm_neighbor=norm_index-31;norm_neighbor_valid=norm_index[4:0]<31&&norm_index[9:5]>0;end
   3:begin norm_neighbor=norm_index-1;norm_neighbor_valid=norm_index[4:0]>0;end
   4:begin norm_neighbor=norm_index;norm_neighbor_valid=1;end
   5:begin norm_neighbor=norm_index+1;norm_neighbor_valid=norm_index[4:0]<31;end
   6:begin norm_neighbor=norm_index+31;norm_neighbor_valid=norm_index[4:0]>0&&norm_index[9:5]<31;end
   7:begin norm_neighbor=norm_index+32;norm_neighbor_valid=norm_index[9:5]<31;end
   8:begin norm_neighbor=norm_index+33;norm_neighbor_valid=norm_index[4:0]<31&&norm_index[9:5]<31;end endcase
   raw_re=0;raw_ra=filter_addr;clean_re=0;clean_ra=scan;work_re=0;work_ra=scan;selected_re=0;selected_ra=filter_addr;
   clean_we=0;clean_wa=scan;clean_wd=ones>=5;work_we=0;work_wa=scan;work_wd=0;
   selected_we=0;selected_wa=scan;selected_wd=0;
   queue_we=0;queue_re=0;queue_ra=head[13:0];queue_wa=tail[13:0];queue_wd=neighbor_addr;
   norm_we=0;norm_wa=norm_index;norm_wd=selected_q;norm_re=0;norm_ra=norm_neighbor;
   view_we=0;view_addr=scan;view_data={original_bit,center_bit,sobel_bit};
   if(state==F_R)raw_re=filter_valid;
   if(state==F_W)begin clean_we=1;work_we=1;work_wd=ones>=5;end
   if(state==SCAN_R)work_re=1;
   if(state==SCAN_T&&work_q)begin work_we=1;queue_we=1;queue_wa=0;queue_wd=scan;end
   if(state==Q_R&&head<tail)queue_re=1;
   if(state==N_R&&neighbor_valid)begin work_re=1;work_ra=neighbor_addr;end
   if(state==N_T&&neighbor_valid&&work_q&&tail<16384)begin
     work_we=1;work_wa=neighbor_addr;queue_we=1;
     if(second_pass)begin selected_we=1;selected_wa=neighbor_addr;selected_wd=1;end
   end
   if(state==CLEAR_R)clean_re=1;
   if(state==CLEAR_T)begin work_we=1;work_wd=clean_q;selected_we=1;end
   if(state==SEED)begin
     queue_we=1;queue_wa=0;queue_wd=best_seed;work_we=1;work_wa=best_seed;
     selected_we=1;selected_wa=best_seed;selected_wd=1;
   end
   if(state==EDGE_R)begin selected_re=filter_valid;if(neighbor==4)begin raw_re=1;raw_ra=scan;end end
   if(state==EDGE_W)begin view_we=1;if(!accept)view_data={original_bit,2'b0};end
   if(state==NORM_R)begin selected_re=1;selected_ra={norm_source_y,norm_source_x};end
   if(state==NORM_T)norm_we=1;
   if(state==FE_R)norm_re=norm_neighbor_valid;
 end
 always @(posedge clk)begin
 if(!rst_n||reset_scene)begin
   state<=READY;display_bank<=0;write_bank<=1;display_ready<=0;pending<=0;
   result_done<=0;result_valid<=0;result_multi<=0;result_clip<=0;result_x<=0;result_y<=0;result_box<=0;result_area<=0;result_count<=0;
   scan<=0;node<=0;best_seed<=0;head<=0;tail<=0;area<=0;best_area<=0;second_area<=0;
   xmin<=0;xmax<=0;ymin<=0;ymax<=0;bxmin<=0;bxmax<=0;bymin<=0;bymax<=0;
   sum_x<=0;sum_y<=0;best_sumx<=0;best_sumy<=0;neighbor<=0;ones<=0;second_pass<=0;candidates<=0;
   norm_index<=0;gx<=0;gy<=0;center_bit<=0;original_bit<=0;gotx<=0;goty<=0;cx<=0;cy<=0;
   feature_we<=0;feature_addr<=0;feature_data<=0;
 end else begin
   result_done<=0;feature_we<=0;
   if(frame_start&&pending)begin display_bank<=write_bank;display_ready<=1;pending<=0;end
   case(state)
   READY:if(frame_start&&!matcher_busy)begin state<=CAPTURE;write_bank<=!display_bank;end
   CAPTURE:if(sample_done)begin scan<=0;neighbor<=0;ones<=0;state<=F_R;best_area<=0;second_area<=0;candidates<=0;second_pass<=0;end
   F_R:state<=F_T;
   F_T:begin
     if(filter_valid&&raw_q)ones<=ones+1'b1;
     if(neighbor==8)state<=F_W;else begin neighbor<=neighbor+1'b1;state<=F_R;end
   end
   F_W:begin neighbor<=0;ones<=0;if(scan==16383)begin scan<=0;state<=SCAN_R;end else begin scan<=scan+1'b1;state<=F_R;end end
   SCAN_R:state<=SCAN_T;
   SCAN_T:if(work_q)begin head<=0;tail<=1;area<=0;sum_x<=0;sum_y<=0;xmin<=127;xmax<=0;ymin<=127;ymax<=0;state<=Q_R;end else state<=ADV;
   Q_R:if(head<tail)state<=Q_T;else if(second_pass)begin state<=DIV_S;end
     else begin
       if(area>=MIN_AREA&&area<=MAX_AREA&&xmax-xmin>=11&&ymax-ymin>=15)begin
         if(candidates<7)candidates<=candidates+1'b1;
         if(area>best_area)begin second_area<=best_area;best_area<=area;bxmin<=xmin;bxmax<=xmax;bymin<=ymin;bymax<=ymax;best_seed<=scan;best_sumx<=sum_x;best_sumy<=sum_y;end
         else if(area>second_area)second_area<=area;
       end
       state<=ADV;
     end
   Q_T:begin node<=queue_q;head<=head+1'b1;area<=area+1'b1;sum_x<=sum_x+queue_q[6:0];sum_y<=sum_y+queue_q[13:7];
     if(queue_q[6:0]<xmin)xmin<=queue_q[6:0];if(queue_q[6:0]>xmax)xmax<=queue_q[6:0];
     if(queue_q[13:7]<ymin)ymin<=queue_q[13:7];if(queue_q[13:7]>ymax)ymax<=queue_q[13:7];neighbor<=0;state<=N_R;end
   N_R:state<=N_T;
   N_T:begin
     if(neighbor_valid&&work_q&&tail<16384)tail<=tail+1'b1;
     if(neighbor==7)state<=Q_R;else begin neighbor<=neighbor+1'b1;state<=N_R;end
   end
   ADV:if(scan==16383)begin scan<=0;state<=CLEAR_R;end else begin scan<=scan+1'b1;state<=SCAN_R;end
   CLEAR_R:state<=CLEAR_T;
   CLEAR_T:if(scan==16383)begin if(best_area!=0)state<=SEED;else begin scan<=0;neighbor<=0;gx<=0;gy<=0;state<=EDGE_R;end end
     else begin scan<=scan+1'b1;state<=CLEAR_R;end
   SEED:begin second_pass<=1;head<=0;tail<=1;area<=0;state<=Q_R;end
   DIV_S:begin gotx<=0;goty<=0;state<=DIV_W;end
   DIV_W:begin if(vx)begin gotx<=1;cx<=div_x;end if(vy)begin goty<=1;cy<=div_y;end
     if(gotx&&goty)begin scan<=0;neighbor<=0;gx<=0;gy<=0;state<=EDGE_R;end end
   EDGE_R:state<=EDGE_T;
   EDGE_T:begin
     if(filter_valid&&selected_q)begin gx<=gx+weight_x(neighbor);gy<=gy+weight_y(neighbor);end
     if(neighbor==4)begin center_bit<=selected_q;original_bit<=raw_q;end
     if(neighbor==8)state<=EDGE_W;else begin neighbor<=neighbor+1'b1;state<=EDGE_R;end
   end
   EDGE_W:begin neighbor<=0;gx<=0;gy<=0;
     if(scan==16383)begin norm_index<=0;state<=accept?NORM_R:FINISH;end else begin scan<=scan+1'b1;state<=EDGE_R;end end
   NORM_R:state<=NORM_T;
   NORM_T:if(norm_index==1023)begin norm_index<=0;neighbor<=0;gx<=0;gy<=0;state<=FE_R;end
     else begin norm_index<=norm_index+1'b1;state<=NORM_R;end
   FE_R:state<=FE_T;
   FE_T:begin
     if(norm_neighbor_valid&&norm_q)begin gx<=gx+weight_x(neighbor);gy<=gy+weight_y(neighbor);end
     if(neighbor==4)center_bit<=norm_q;
     if(neighbor==8)state<=FE_W;else begin neighbor<=neighbor+1'b1;state<=FE_R;end
   end
   FE_W:begin feature_we<=1;feature_addr<=norm_index;feature_data<={sobel_bit,center_bit};neighbor<=0;gx<=0;gy<=0;
     if(norm_index==1023)state<=FINISH;else begin norm_index<=norm_index+1'b1;state<=FE_R;end end
   FINISH:begin result_done<=1;result_valid<=accept;result_multi<=ambiguous;result_clip<=best_area!=0&&clipped;
     result_x<=best_area!=0?cx:0;result_y<=best_area!=0?cy:0;result_box<=best_area!=0?{bymax,bymin,bxmax,bxmin}:0;
     result_area<=best_area;result_count<=candidates;pending<=1;state<=WAIT_PUBLISH;end
   WAIT_PUBLISH:if(frame_start)state<=READY;
   default:state<=READY;
   endcase
 end
 end
endmodule
