`timescale 1ns/1ps
// Display-only association and dropout buffering. Input boxes must already pass Haar.
// Ages use display frames, so timeout remains bounded even if the detector stops.
module haar_box_tracker #(parameter MAX_FACES=8,HOLD_FRAMES=36)(
 input clk,rst_n,frame_start,result_valid,
 input [3:0] result_count,input [MAX_FACES*42-1:0] result_boxes,
 output reg [3:0] display_count,output reg [MAX_FACES*42-1:0] display_boxes,
 output reg [MAX_FACES-1:0] display_mask,output busy,output reg overrun
);
 localparam AGE_BITS=$clog2(HOLD_FRAMES+1),INDEX_BITS=(MAX_FACES>1)?$clog2(MAX_FACES):1;
 localparam IDLE=0,SEARCH=1,APPLY=2,COMMIT=3,PREPARE=4;
 reg [2:0] state;
 assign busy=state!=IDLE;
 reg [AGE_BITS-1:0] ttl[0:MAX_FACES-1];
 reg [MAX_FACES*42-1:0] candidates,updates;
 reg [MAX_FACES-1:0] claimed,update_mask;
 reg [3:0] count,candidate_index;
 reg [INDEX_BITS-1:0] scan_index,best_index,free_index;
 reg best_found,free_found;reg [12:0] best_score;reg [41:0] best_box;
 wire [41:0] candidate=candidates[candidate_index*42+:42];
 wire [41:0] current=display_boxes[scan_index*42+:42];
 wire [11:0] ccx={1'b0,candidate[10:0]}+{1'b0,candidate[21:11]};
 wire [11:0] ocx={1'b0,current[10:0]}+{1'b0,current[21:11]};
 wire [10:0] ccy={1'b0,candidate[31:22]}+{1'b0,candidate[41:32]};
 wire [10:0] ocy={1'b0,current[31:22]}+{1'b0,current[41:32]};
 wire [11:0] delta_x=(ccx>ocx)?ccx-ocx:ocx-ccx;
 wire [10:0] delta_y=(ccy>ocy)?ccy-ocy:ocy-ccy;
 wire [11:0] cw={1'b0,candidate[21:11]}-{1'b0,candidate[10:0]}+1'b1;
 wire [11:0] ow={1'b0,current[21:11]}-{1'b0,current[10:0]}+1'b1;
 wire [10:0] ch={1'b0,candidate[41:32]}-{1'b0,candidate[31:22]}+1'b1;
 wire [10:0] oh={1'b0,current[41:32]}-{1'b0,current[31:22]}+1'b1;
 wire [12:0] distance={1'b0,delta_x}+{2'b0,delta_y};
 wire near=(delta_x<=((cw<ow)?cw:ow))&&(delta_y<=((ch<oh)?ch:oh));
 function [41:0] smooth;input [41:0] a,b;
 reg [11:0] x0,x1;reg [10:0] y0,y1;
 begin
  x0={1'b0,a[10:0]}+{1'b0,b[10:0]}+1'b1;
  x1={1'b0,a[21:11]}+{1'b0,b[21:11]}+1'b1;
  y0={1'b0,a[31:22]}+{1'b0,b[31:22]}+1'b1;
  y1={1'b0,a[41:32]}+{1'b0,b[41:32]}+1'b1;
  smooth={y1[10:1],y0[10:1],x1[11:1],x0[11:1]};
 end endfunction
 integer n;reg [3:0] next_count;
 always @*begin
  next_count=0;
  for(n=0;n<MAX_FACES;n=n+1)
   if(ttl[n]>1||(state==COMMIT&&update_mask[n]))next_count=next_count+1'b1;
 end
 integer k;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=IDLE;display_count<=0;display_boxes<=0;display_mask<=0;overrun<=0;
  candidates<=0;updates<=0;claimed<=0;update_mask<=0;count<=0;candidate_index<=0;
  scan_index<=0;best_index<=0;free_index<=0;best_found<=0;free_found<=0;best_score<=0;best_box<=0;
  for(k=0;k<MAX_FACES;k=k+1)ttl[k]<=0;
 end else begin
  if(result_valid&&busy)overrun<=1;
  // Only this block changes displayed coordinates and validity, at frame boundaries.
  if(frame_start)begin
   display_count<=next_count;
   for(k=0;k<MAX_FACES;k=k+1)begin
    if(state==COMMIT&&update_mask[k])begin
     display_boxes[k*42+:42]<=updates[k*42+:42];display_mask[k]<=1;ttl[k]<=HOLD_FRAMES;
    end else if(ttl[k]>1)ttl[k]<=ttl[k]-1'b1;
    else begin ttl[k]<=0;display_mask[k]<=0;display_boxes[k*42+:42]<=0;end
   end
  end
  case(state)
   IDLE:if(result_valid&&result_count!=0)begin
    candidates<=result_boxes;count<=(result_count>MAX_FACES)?MAX_FACES:result_count;
    if(result_count>MAX_FACES)overrun<=1;
    claimed<=0;update_mask<=0;candidate_index<=0;state<=PREPARE;
   end
   PREPARE:begin scan_index<=0;best_found<=0;free_found<=0;best_score<=13'h1fff;state<=SEARCH;end
   SEARCH:begin
    if(!claimed[scan_index])begin
     if(ttl[scan_index]!=0&&near&&(!best_found||distance<best_score))begin
      best_found<=1;best_index<=scan_index;best_score<=distance;best_box<=current;
     end
     if(ttl[scan_index]==0&&!free_found)begin free_found<=1;free_index<=scan_index;end
    end
    if(scan_index==MAX_FACES-1)state<=APPLY;else scan_index<=scan_index+1'b1;
   end
   APPLY:begin
    if(best_found)begin
     updates[best_index*42+:42]<=smooth(best_box,candidate);
     claimed[best_index]<=1;update_mask[best_index]<=1;
    end else if(free_found)begin
     updates[free_index*42+:42]<=candidate;claimed[free_index]<=1;update_mask[free_index]<=1;
    end else overrun<=1;
    if(candidate_index+1>=count)state<=COMMIT;
    else begin candidate_index<=candidate_index+1'b1;state<=PREPARE;end
   end
   COMMIT:if(frame_start)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
