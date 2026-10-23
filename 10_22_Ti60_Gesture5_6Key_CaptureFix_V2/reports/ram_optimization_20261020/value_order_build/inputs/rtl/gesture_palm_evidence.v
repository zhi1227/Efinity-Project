// Independent open-palm evidence from the existing 16x16 clean silhouette.
// Multiple separated fingers in >=2 rows/columns plus a connected palm region.
// Serial processing and an iterative small divider; no new image RAM.
module gesture_palm_evidence(
 input clk,rst_n,enable,sample_done,sample_valid,input[255:0]bitmap,
 output reg done,valid,palm,output reg[7:0]lean);
 reg[255:0]q;reg[2:0]state;reg[3:0]row;
 reg[4:0]row_fingers,col_fingers,solid_rows,solid_cols;
 reg[8:0]total;reg[7:0]top_count;reg[10:0]top_sum;
 reg[15:0]line_r,line_c;reg[4:0]runs_r,runs_c,ones_r,ones_c,length_r,length_c;
 reg[7:0]moment;integer i;
 always @*begin
  line_r=q[{row,4'd0}+:16];line_c=0;
  for(i=0;i<16;i=i+1)line_c[i]=q[i*16+row];
  runs_r=0;runs_c=0;ones_r=0;ones_c=0;length_r=0;length_c=0;moment=0;
  for(i=0;i<16;i=i+1)begin
   if(line_r[i])begin length_r=length_r+1'b1;ones_r=ones_r+1'b1;moment=moment+i;end
   else begin if(length_r>=2)runs_r=runs_r+1'b1;length_r=0;end
   if(line_c[i])begin length_c=length_c+1'b1;ones_c=ones_c+1'b1;end
   else begin if(length_c>=2)runs_c=runs_c+1'b1;length_c=0;end
  end
  if(length_r>=2)runs_r=runs_r+1'b1;
  if(length_c>=2)runs_c=runs_c+1'b1;
 end
 reg[14:0]quotient;reg[8:0]remainder;reg[3:0]div_step;
 wire[9:0]trial={remainder,quotient[14]};
 wire take=trial>={2'd0,top_count};
 wire[14:0]next_q={quotient[13:0],take};
 always @(posedge clk)begin
  done<=0;
  if(!rst_n||!enable)begin
   q<=0;state<=0;row<=0;row_fingers<=0;col_fingers<=0;solid_rows<=0;solid_cols<=0;
   total<=0;top_count<=0;top_sum<=0;done<=0;valid<=0;palm<=0;lean<=120;quotient<=0;remainder<=0;div_step<=0;
  end else case(state)
   0:if(sample_done)begin
    if(sample_valid)begin
     q<=bitmap;state<=1;row<=0;row_fingers<=0;col_fingers<=0;solid_rows<=0;solid_cols<=0;total<=0;top_count<=0;top_sum<=0;
    end else begin valid<=0;palm<=0;done<=1;end
   end
   1:begin
    if(row<10&&runs_r>=3&&runs_r<=5&&ones_r>=6&&ones_r<=13)row_fingers<=row_fingers+1'b1;
    if(runs_c>=3&&runs_c<=5&&ones_c>=6&&ones_c<=13)col_fingers<=col_fingers+1'b1;
    if(row>=6&&runs_r==1&&ones_r>=8)solid_rows<=solid_rows+1'b1;
    if(runs_c==1&&ones_c>=8)solid_cols<=solid_cols+1'b1;
    total<=total+ones_r;
    if(row<8)begin top_count<=top_count+ones_r;top_sum<=top_sum+moment;end
    if(row==15)state<=2;else row<=row+1'b1;
   end
   2:begin
    valid<=top_count>=8&&total>=40&&total<=235;
    palm<=total>=60&&total<=225&&top_count>=12&&
      ((row_fingers>=2&&solid_rows>=3)||(col_fingers>=2&&solid_cols>=3));
    if(top_count==0)begin lean<=120;done<=1;state<=0;end
    else begin quotient<={top_sum,4'd0};remainder<=0;div_step<=0;state<=3;end
   end
   3:begin
    quotient<=next_q;remainder<=take?trial-top_count:trial;
    if(div_step==14)begin lean<=next_q[7:0];done<=1;state<=0;end else div_step<=div_step+1'b1;
   end
   default:state<=0;
  endcase
 end
endmodule
