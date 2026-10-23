// Three distinct, valid camera observations confirm a count. Replayed frames
// and a frozen display never manufacture additional observations.
module vision8_count_filter #(parameter SOURCE_TAGGED=1)(
 input clk,rst_n,source_ok,frozen,published,input[31:0]source_id,
 input[3:0]count_i,input saturated_i,
 output reg[3:0]count_o,output reg valid_o,saturated_o);
 reg[3:0]candidate;reg candidate_saturated,id_valid;reg[1:0]repeats;reg[31:0]last_id;
 always @(posedge clk)begin
  if(!rst_n)begin candidate<=0;candidate_saturated<=0;id_valid<=0;repeats<=0;last_id<=0;count_o<=0;valid_o<=0;saturated_o<=0;end
  else if(!frozen)begin
   if(!source_ok)begin valid_o<=0;repeats<=0;id_valid<=0;end
   else if(published&&(!SOURCE_TAGGED||!id_valid||source_id!=last_id))begin
    last_id<=source_id;id_valid<=1;
    if(count_i!=candidate||saturated_i!=candidate_saturated)begin candidate<=count_i;candidate_saturated<=saturated_i;repeats<=1;end
    else if(repeats==2)begin count_o<=count_i;saturated_o<=saturated_i;valid_o<=1;end
    else repeats<=repeats+1'b1;
   end
  end
 end
endmodule
