`include "demo_model.vh"
// Immutable 3 classes x 8 exemplars x 1024 two-bit mask/Sobel features.
// CRC32 is checked on every reset. No on-board training or template writes.
module demo_match #(
 parameter MODEL_ENABLE=`DEMO_MODEL_VALID,MODEL_FILE="model/templates.mem",
 parameter [31:0] EXPECTED_CRC=`DEMO_MODEL_CRC,
 parameter MAX_DISTANCE=`DEMO_MAX_DISTANCE,MIN_MARGIN=`DEMO_MIN_MARGIN,STABLE=3)(
 input clk,rst_n,frame_start,invalidate,
 input feature_we,input[9:0]feature_addr,input[1:0]feature_data,
 input sample_done,sample_valid,
 output busy,output reg model_ready,model_error,
 output reg[2:0]gesture_id,output gesture_valid,
 output reg[11:0]best_score,output reg decision_done);
 localparam IDLE=0,READ=1,TAKE=2,NEXT=3,RANK=4,DECIDE=5,BOOT_R=6,BOOT_C=7,ERROR=8;
 reg[3:0]state;reg[9:0]index;reg[4:0]slot;reg[1:0]class_index,candidate,last_candidate;
 reg[1:0]query[0:1023],templates[0:24575];reg[1:0]q,t;
 initial $readmemh(MODEL_FILE,templates);
 reg[14:0]boot_addr;reg[2:0]crc_bit;reg[31:0]crc;
 wire incoming=crc_bit<2?t[crc_bit]:1'b0;
 wire[31:0]crc_next=(crc>>1)^((crc[0]^incoming)?32'hedb88320:32'b0);
 wire[14:0]rom_addr=state==BOOT_R?boot_addr:{slot,index};
 reg[11:0]score,second_score,class_scores[0:2];reg[3:0]stable_count;reg[7:0]stale;integer k;
 wire[2:0]difference={2'b0,q[0]^t[0]}+{1'b0,q[1]^t[1],1'b0};
 assign busy=MODEL_ENABLE&&state!=IDLE&&state!=ERROR;
 assign gesture_valid=model_ready&&gesture_id!=0;
 always @(posedge clk)begin
   if(feature_we)query[feature_addr]<=feature_data;
   if(state==READ)q<=query[index];
   if(state==READ||state==BOOT_R)t<=templates[rom_addr];
 end
 always @(posedge clk)begin
 if(!rst_n)begin
   state<=MODEL_ENABLE?BOOT_R:IDLE;model_ready<=0;model_error<=0;
   boot_addr<=0;crc_bit<=0;crc<=32'hffffffff;
   index<=0;slot<=0;class_index<=0;candidate<=0;last_candidate<=0;
   score<=0;best_score<=4095;second_score<=4095;stable_count<=0;gesture_id<=0;decision_done<=0;stale<=0;
   for(k=0;k<3;k=k+1)class_scores[k]<=4095;
 end else begin
   decision_done<=0;
   if(frame_start)begin
     if(stale<255)stale<=stale+1'b1;
     if(stale>=8)begin gesture_id<=0;stable_count<=0;last_candidate<=0;end
   end
   case(state)
   BOOT_R:begin crc_bit<=0;state<=BOOT_C;end
   BOOT_C:begin
     crc<=crc_next;
     if(crc_bit==7)begin
       if(boot_addr==24575)begin
         if((~crc_next)==EXPECTED_CRC)begin model_ready<=1;state<=IDLE;end
         else begin model_error<=1;state<=ERROR;end
       end else begin boot_addr<=boot_addr+1'b1;state<=BOOT_R;end
     end else crc_bit<=crc_bit+1'b1;
   end
   IDLE:if(sample_done)begin
     stale<=0;
     if(!sample_valid||!model_ready)begin gesture_id<=0;stable_count<=0;last_candidate<=0;best_score<=4095;decision_done<=1;end
     else begin
       for(k=0;k<3;k=k+1)class_scores[k]<=4095;
       slot<=0;index<=0;score<=0;state<=READ;
     end
   end
   READ:state<=TAKE;
   TAKE:begin
     score<=score+difference;
     if(index==1023)state<=NEXT;else begin index<=index+1'b1;state<=READ;end
   end
   NEXT:begin
     if(score<class_scores[slot>>3])class_scores[slot>>3]<=score;
     if(slot==23)begin class_index<=0;best_score<=4095;second_score<=4095;candidate<=0;state<=RANK;end
     else begin slot<=slot+1'b1;index<=0;score<=0;state<=READ;end
   end
   RANK:begin
     if(class_scores[class_index]<best_score)begin
       second_score<=best_score;best_score<=class_scores[class_index];candidate<=class_index+1'b1;
     end else if(class_scores[class_index]<second_score)second_score<=class_scores[class_index];
     if(class_index==2)state<=DECIDE;else class_index<=class_index+1'b1;
   end
   DECIDE:begin
     decision_done<=1;state<=IDLE;
     if(candidate!=0&&best_score<=MAX_DISTANCE&&second_score>=best_score+MIN_MARGIN)begin
       if(candidate==last_candidate)begin
         if(stable_count<STABLE)stable_count<=stable_count+1'b1;
         if(stable_count>=STABLE-1)gesture_id<=candidate==3?3'd5:{1'b0,candidate};
       end else begin last_candidate<=candidate;stable_count<=1;gesture_id<=0;end
     end else begin gesture_id<=0;stable_count<=0;last_candidate<=0;end
   end
   ERROR:begin gesture_id<=0;end
   default:state<=IDLE;
   endcase
   if(invalidate)begin
     gesture_id<=0;last_candidate<=0;stable_count<=0;best_score<=4095;
     if(model_ready)state<=IDLE;
   end
 end end
endmodule
