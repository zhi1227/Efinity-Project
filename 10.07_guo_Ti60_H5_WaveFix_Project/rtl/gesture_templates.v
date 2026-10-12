// Three user-recorded silhouettes. Upper fingers have double weight.
// Serial 16-bit comparisons, five one-cell translations, no model framebuffer.
module gesture_templates #(parameter MAX_DISTANCE=66,MIN_MARGIN=12,MIN_SEPARATION=28)(
 input clk,rst_n,enable,clear,input[2:0]learn,
 input sample_done,sample_valid,input[255:0]bitmap,input[19:0]ratio,
 output reg result_done,output reg[2:0]raw_class,output reg[2:0]trained,
 output reg capture_done,capture_ok,output reg[1:0]capture_error,
 output reg[1:0]capture_count,output reg[9:0]best_distance);
 reg[255:0]model1,model2,model3,first,second,query;
 reg[7:0]aspect1,aspect2,aspect3,aspect_q;
 reg[2:0]learning;reg[2:0]state,variant;reg[1:0]which;reg[3:0]row;
 reg[9:0]sum,minimum,d1,d2,d3,previous_distance;
 reg[8:0]ones;
 wire[7:0]aspect=ratio>8159?8'd255:ratio[12:5];
 reg[15:0]qr,mr,pr;reg[255:0]selected;reg[7:0]selected_aspect,delta;
 reg[4:0]diff_count,prev_count,on_count;integer i;
 always @*begin
  selected=which==0?model1:(which==1?model2:model3);
  selected_aspect=which==0?aspect1:(which==1?aspect2:aspect3);
  delta=aspect_q>selected_aspect?aspect_q-selected_aspect:selected_aspect-aspect_q;
  qr=query[{row,4'b0}+:16];mr=selected[{row,4'b0}+:16];pr=first[{row,4'b0}+:16];
  case(variant)
   1:qr=qr<<1;2:qr=qr>>1;
   3:qr=row==0?16'd0:query[((row-1)*16)+:16];
   4:qr=row==15?16'd0:query[((row+1)*16)+:16];
  endcase
  diff_count=0;prev_count=0;on_count=0;
  for(i=0;i<16;i=i+1)begin
   diff_count=diff_count+(qr[i]^mr[i]);prev_count=prev_count+(qr[i]^pr[i]);on_count=on_count+qr[i];
  end
 end
 wire[9:0]add_distance=row<8?{4'd0,diff_count,1'b0}:{5'd0,diff_count};
 wire[9:0]finished=sum+add_distance;
 wire[9:0]penalty={3'd0,delta,1'b0};
 wire[9:0]final_distance=(finished<minimum?finished:minimum)+penalty;
 reg[9:0]best,next_best;reg[2:0]best_id;
 always @*begin
  best=1023;next_best=1023;best_id=0;
  if(trained[0])begin best=d1;best_id=1;end
  if(trained[1])begin if(d2<best)begin next_best=best;best=d2;best_id=2;end else next_best=d2;end
  if(trained[2])begin if(d3<best)begin next_best=best;best=d3;best_id=3;end else if(d3<next_best)next_best=d3;end
 end
 wire distinct=(learning==1||!trained[0]||d1>=MIN_SEPARATION)&&
  (learning==2||!trained[1]||d2>=MIN_SEPARATION)&&
  (learning==3||!trained[2]||d3>=MIN_SEPARATION);
 wire reasonable=ones>=40&&ones<=235&&aspect_q>=12&&aspect_q<=110;
 always @(posedge clk)begin
  result_done<=0;capture_done<=0;
  if(!rst_n||clear)begin
   model1<=0;model2<=0;model3<=0;aspect1<=0;aspect2<=0;aspect3<=0;trained<=0;
   first<=0;second<=0;query<=0;aspect_q<=0;learning<=0;capture_count<=0;capture_ok<=0;capture_error<=0;
   state<=0;variant<=0;which<=0;row<=0;sum<=0;minimum<=1023;d1<=1023;d2<=1023;d3<=1023;
   previous_distance<=0;ones<=0;raw_class<=0;best_distance<=1023;
  end else if(!enable)begin state<=0;learning<=0;capture_count<=0;raw_class<=0;end
  else if(learn>=1&&learn<=3)begin learning<=learn;capture_count<=0;capture_ok<=0;capture_error<=0;state<=0;raw_class<=0;end
  else case(state)
   0:if(sample_done)begin
    raw_class<=0;
    if(sample_valid)begin query<=bitmap;aspect_q<=aspect;state<=1;variant<=0;which<=0;row<=0;sum<=0;minimum<=1023;previous_distance<=0;ones<=0;end
    else begin result_done<=1;if(learning!=0)capture_count<=0;end
   end
   1:begin
    if(which==0&&variant==0)begin
     previous_distance<=previous_distance+(row<8?{4'd0,prev_count,1'b0}:{5'd0,prev_count});
     ones<=ones+on_count;
    end
    if(row!=15)begin row<=row+1'b1;sum<=finished;end
    else begin
     row<=0;sum<=0;
     if(variant!=4)begin variant<=variant+1'b1;if(finished<minimum)minimum<=finished;end
     else begin
      case(which)0:d1<=final_distance;1:d2<=final_distance;2:d3<=final_distance;endcase
      variant<=0;minimum<=1023;
      if(which==2)state<=2;else which<=which+1'b1;
     end
    end
   end
   2:begin
    state<=0;result_done<=1;best_distance<=best;
    if(learning!=0)begin
     if(!reasonable)begin capture_count<=0;capture_error<=1;end
     else if(capture_count==0||previous_distance>32)begin first<=query;capture_count<=1;capture_error<=0;end
     else if(capture_count==1)begin second<=query;capture_count<=2;end
     else begin
      capture_done<=1;capture_ok<=distinct;capture_error<=distinct?0:2;learning<=0;capture_count<=0;
      if(distinct)begin
       case(learning)
        1:begin model1<=(first&second)|(first&query)|(second&query);aspect1<=aspect_q;trained[0]<=1;end
        2:begin model2<=(first&second)|(first&query)|(second&query);aspect2<=aspect_q;trained[1]<=1;end
        3:begin model3<=(first&second)|(first&query)|(second&query);aspect3<=aspect_q;trained[2]<=1;end
       endcase
      end
     end
    end else if(trained==7&&reasonable&&best<=MAX_DISTANCE&&next_best>=best+MIN_MARGIN)raw_class<=best_id;
   end
   default:state<=0;
  endcase
 end
endmodule
