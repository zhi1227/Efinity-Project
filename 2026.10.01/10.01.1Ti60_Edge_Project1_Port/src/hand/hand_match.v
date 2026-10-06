`include "hand_config.vh"
// Weighted squared L2 on binary vectors: (a-b)^2 == a XOR b.
// 1024 normalized silhouette bits + 1024 actual Sobel edge bits (weight 2).
// Two user-taught exemplars per class. No fabricated universal Hu templates.
module hand_match #(parameter MAX_DISTANCE=`HAND_MAX_DISTANCE,MIN_MARGIN=`HAND_MIN_MARGIN,STABLE=`HAND_STABLE_SAMPLES)(
 input clk,rst_n,frame_start,invalidate,clear_templates,
 input feature_we,input[9:0]feature_addr,input[1:0]feature_data,
 input sample_done,sample_valid,input teach,input[2:0]teach_id,input cancel_teach,
 output busy,output reg teach_pending,output reg learned_pulse,learn_failed,
 output reg[4:0]trained,output reg[2:0]gesture,
 output reg[11:0]best_score,output reg decision_done);
 localparam IDLE=0,READ=1,TAKE=2,NEXT=3,RANK=4,DECIDE=5,COPY_R=6,COPY_W=7;
 reg[3:0]state;reg[9:0]index;reg[3:0]slot;reg[2:0]class_index,request_id,candidate,last_candidate;
 reg[1:0]query[0:1023],templates[0:10239];reg[1:0]q,t;
 reg[9:0]valid_slots;reg[4:0]replacement;
 reg[11:0]score,second_score,class_scores[0:4];reg[3:0]stable_count;
 reg[7:0]teach_age,stale;integer k;
 wire[13:0]template_addr={slot,index};
 wire[2:0]difference={2'b0,q[0]^t[0]}+{1'b0,q[1]^t[1],1'b0};
 assign busy=state!=IDLE;
 always @(posedge clk)begin
   if(feature_we)query[feature_addr]<=feature_data;
   if(state==READ||state==COPY_R)begin q<=query[index];t<=templates[template_addr];end
   if(state==COPY_W)templates[template_addr]<=q;
 end
 always @(posedge clk)begin
 if(!rst_n||clear_templates)begin
   state<=IDLE;index<=0;slot<=0;class_index<=0;request_id<=1;candidate<=0;last_candidate<=0;
   valid_slots<=0;replacement<=0;trained<=0;score<=0;best_score<=4095;second_score<=4095;stable_count<=0;
   gesture<=0;teach_pending<=0;teach_age<=0;learned_pulse<=0;learn_failed<=0;decision_done<=0;stale<=0;
   for(k=0;k<5;k=k+1)class_scores[k]<=4095;
 end else begin
   learned_pulse<=0;learn_failed<=0;decision_done<=0;
   if(frame_start)begin
     if(stale<255)stale<=stale+1'b1;
     if(stale>=8)begin gesture<=0;stable_count<=0;last_candidate<=0;end
     if(teach_pending)begin
       if(teach_age==179)begin teach_pending<=0;learn_failed<=1;end else teach_age<=teach_age+1'b1;
     end
   end
   if(teach&&teach_id>=1&&teach_id<=5)begin teach_pending<=1;request_id<=teach_id;teach_age<=0;end
   if(cancel_teach)teach_pending<=0;
   case(state)
   IDLE:if(sample_done)begin
     stale<=0;
     if(!sample_valid)begin gesture<=0;stable_count<=0;last_candidate<=0;best_score<=4095;decision_done<=1;end
     else if(teach_pending&&!cancel_teach)begin
       class_index<=request_id-1'b1;slot<=((request_id-1'b1)<<1)+
         (valid_slots[(request_id-1'b1)*2]?(valid_slots[(request_id-1'b1)*2+1]?replacement[request_id-1'b1]:1'b1):1'b0);
       index<=0;state<=COPY_R;gesture<=0;stable_count<=0;last_candidate<=0;
     end else begin
       for(k=0;k<5;k=k+1)class_scores[k]<=4095;
       slot<=0;index<=0;score<=0;state<=READ;
     end
   end
   READ:state<=TAKE;
   TAKE:begin
     score<=score+difference;
     if(index==1023)state<=NEXT;else begin index<=index+1'b1;state<=READ;end
   end
   NEXT:begin
     if(valid_slots[slot]&&score<class_scores[slot>>1])class_scores[slot>>1]<=score;
     if(slot==9)begin class_index<=0;best_score<=4095;second_score<=4095;candidate<=0;state<=RANK;end
     else begin slot<=slot+1'b1;index<=0;score<=0;state<=READ;end
   end
   RANK:begin
     if(class_scores[class_index]<best_score)begin
       second_score<=best_score;best_score<=class_scores[class_index];candidate<=class_index+1'b1;
     end else if(class_scores[class_index]<second_score)second_score<=class_scores[class_index];
     if(class_index==4)state<=DECIDE;else class_index<=class_index+1'b1;
   end
   DECIDE:begin
     decision_done<=1;state<=IDLE;
     if(trained==5'b11111&&candidate!=0&&best_score<=MAX_DISTANCE&&second_score>=best_score+MIN_MARGIN)begin
       if(candidate==last_candidate)begin if(stable_count<STABLE)stable_count<=stable_count+1'b1;if(stable_count>=STABLE-1)gesture<=candidate;end
       else begin last_candidate<=candidate;stable_count<=1;gesture<=0;end
     end else begin gesture<=0;stable_count<=0;last_candidate<=0;end
   end
   COPY_R:state<=COPY_W;
   COPY_W:if(index==1023)begin
     valid_slots[slot]<=1;trained[class_index]<=1;replacement[class_index]<=!slot[0];
     teach_pending<=0;learned_pulse<=1;state<=IDLE;best_score<=0;decision_done<=1;
   end else begin index<=index+1'b1;state<=COPY_R;end
   default:state<=IDLE;
   endcase
   if(invalidate)begin state<=IDLE;gesture<=0;last_candidate<=0;stable_count<=0;teach_pending<=0;best_score<=4095;end
 end
 end
endmodule
