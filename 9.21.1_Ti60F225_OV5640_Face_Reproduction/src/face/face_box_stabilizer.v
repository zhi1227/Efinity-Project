`timescale 1ns/1ps
// 多目标显示稳定器：按中心距离关联，坐标 3/4 旧值 + 1/4 新值。
// 暂时漏检保留 HOLD_FRAMES 帧；它只减少闪烁，不提高检测真实性。
module face_box_stabilizer #(parameter MAX_FACES=8,HOLD_FRAMES=3,MAX_SHIFT=96)(
 input clk,input rst_n,input update,
 input [3:0] count_i,input [MAX_FACES*42-1:0] boxes_i,
 output reg[3:0] count_o,output reg[MAX_FACES*42-1:0] boxes_o
);
 localparam IDLE=0,SEARCH=1,COMMIT=2,AGE=3,PACK=4,PUBLISH=5;
 reg[2:0] state;
 reg[41:0] track[0:MAX_FACES-1];
 reg[MAX_FACES-1:0] alive,used;
 reg[7:0] missed[0:MAX_FACES-1];
 reg[MAX_FACES*42-1:0] incoming,packed_boxes;
 reg[3:0] n,ci,ti,best,free_slot,packed_count;
 reg found,have_free;
 reg[12:0] best_distance;
 wire[41:0] candidate=incoming[ci*42+:42];
 wire[41:0] previous=track[ti];
 wire[11:0] cx={1'b0,candidate[10:0]}+{1'b0,candidate[21:11]};
 wire[11:0] px={1'b0,previous[10:0]}+{1'b0,previous[21:11]};
 wire[10:0] cy={1'b0,candidate[31:22]}+{1'b0,candidate[41:32]};
 wire[10:0] py={1'b0,previous[31:22]}+{1'b0,previous[41:32]};
 wire[11:0] dx=cx>px?cx-px:px-cx;
 wire[10:0] dy=cy>py?cy-py:py-cy;
 wire[12:0] distance={1'b0,dx}+{2'b0,dy};
 function[41:0] smooth;
 input[41:0] old_box,new_box;
 reg[12:0] x0,x1;reg[11:0] y0,y1;
 begin
 x0=old_box[10:0]*3+new_box[10:0]+2;
 x1=old_box[21:11]*3+new_box[21:11]+2;
 y0=old_box[31:22]*3+new_box[31:22]+2;
 y1=old_box[41:32]*3+new_box[41:32]+2;
 smooth={y1[11:2],y0[11:2],x1[12:2],x0[12:2]};
 end endfunction
 integer i;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
 state<=IDLE;alive<=0;used<=0;incoming<=0;packed_boxes<=0;
 n<=0;ci<=0;ti<=0;best<=0;free_slot<=0;packed_count<=0;
 found<=0;have_free<=0;best_distance<=8191;count_o<=0;boxes_o<=0;
 for(i=0;i<MAX_FACES;i=i+1) begin track[i]<=0;missed[i]<=0;end
 end else case(state)
 IDLE:if(update) begin
 incoming<=boxes_i;n<=count_i>MAX_FACES?MAX_FACES:count_i;
 ci<=0;ti<=0;used<=0;found<=0;have_free<=0;best_distance<=8191;
 state<=count_i==0?AGE:SEARCH;
 end
 SEARCH:begin
 if(!alive[ti] && !have_free) begin have_free<=1;free_slot<=ti;end
 if(alive[ti] && !used[ti] && dx<=MAX_SHIFT*2 && dy<=MAX_SHIFT*2 &&
    distance<best_distance) begin found<=1;best<=ti;best_distance<=distance;end
 if(ti==MAX_FACES-1) state<=COMMIT;else ti<=ti+1'b1;
 end
 COMMIT:begin
 if(found) begin track[best]<=smooth(track[best],candidate);used[best]<=1;missed[best]<=0;end
 else if(have_free) begin track[free_slot]<=candidate;alive[free_slot]<=1;used[free_slot]<=1;missed[free_slot]<=0;end
 ti<=0;found<=0;have_free<=0;best_distance<=8191;
 if(ci+1>=n) state<=AGE;else begin ci<=ci+1'b1;state<=SEARCH;end
 end
 AGE:begin
 if(alive[ti] && !used[ti]) begin
 if(missed[ti]>=HOLD_FRAMES) begin alive[ti]<=0;missed[ti]<=0;end
 else missed[ti]<=missed[ti]+1'b1;
 end
 if(ti==MAX_FACES-1) begin ti<=0;packed_boxes<=0;packed_count<=0;state<=PACK;end
 else ti<=ti+1'b1;
 end
 PACK:begin
 if(alive[ti]) begin packed_boxes[packed_count*42+:42]<=track[ti];packed_count<=packed_count+1'b1;end
 if(ti==MAX_FACES-1) state<=PUBLISH;else ti<=ti+1'b1;
 end
 PUBLISH:begin boxes_o<=packed_boxes;count_o<=packed_count;state<=IDLE;end
 default:state<=IDLE;
 endcase
 end
endmodule
