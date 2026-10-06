// Class labels and strict thresholds from original recognize.v.
module ep1_classify(input valid,input[19:0]feature,output[1:0]gesture);
 assign gesture=!valid?2'd0:feature>300?2'd1:
   (feature>220&&feature<280)?2'd2:feature<200?2'd3:2'd0;
endmodule

// Preserves original feature: bbox area / number of updates to four extrema.
// That denominator is NOT a geometric perimeter. No gesture model is implied.
// End-of-frame division is iterative, never in the 74.4 MHz pixel datapath.
module ep1_gesture(input clk,rst_n,frame_start,enable,de,bit_i,
 input[10:0]x,input[9:0]y,output reg box_valid,output reg[10:0]xmin,xmax,
 output reg[9:0]ymin,ymax,output reg[19:0]feature,output[1:0]gesture,
 output reg result_done);
 reg seen;reg[10:0]lx,hx;reg[9:0]ly,hy;reg[21:0]updates;
 wire inc_lx=bit_i&&(!seen||x<lx),inc_hx=bit_i&&x>hx;
 wire inc_ly=bit_i&&(!seen||y<ly),inc_hy=bit_i&&y>hy;
 wire[2:0]inc={2'b0,inc_lx}+{2'b0,inc_hx}+{2'b0,inc_ly}+{2'b0,inc_hy};
 reg[10:0]pending_lx,pending_hx;reg[9:0]pending_ly,pending_hy;
 reg[23:0]quotient,denominator;reg[24:0]remainder;reg[4:0]count;
 reg busy,prepare;reg[10:0]bw;reg[9:0]bh;
 wire[24:0]trial={remainder[23:0],quotient[23]};
 wire take=trial>={1'b0,denominator};
 wire[23:0]next_q={quotient[22:0],take};
 ep1_classify classify(box_valid,feature,gesture);
 always @(posedge clk)begin
  if(!rst_n||!enable)begin
   seen<=0;lx<=2047;hx<=0;ly<=1023;hy<=0;updates<=0;
   xmin<=0;xmax<=0;ymin<=0;ymax<=0;box_valid<=0;feature<=0;result_done<=0;
   pending_lx<=0;pending_hx<=0;pending_ly<=0;pending_hy<=0;
   quotient<=0;denominator<=0;remainder<=0;count<=0;busy<=0;prepare<=0;bw<=0;bh<=0;
  end else begin
   result_done<=0;
   if(frame_start)begin
    seen<=0;lx<=2047;hx<=0;ly<=1023;hy<=0;updates<=0;
    if(seen&&hx>lx&&hy>ly&&updates!=0)begin
     pending_lx<=lx;pending_hx<=hx;pending_ly<=ly;pending_hy<=hy;
     bw<=hx-lx;bh<=hy-ly;denominator<={2'b0,updates};prepare<=1;
    end else begin box_valid<=0;feature<=0;result_done<=1;end
   end else if(de&&bit_i)begin
    seen<=1;
    if(inc_lx)lx<=x;if(inc_hx)hx<=x;
    if(inc_ly)ly<=y;if(inc_hy)hy<=y;
    updates<=updates+inc;
   end
   if(prepare)begin quotient<=bw*bh;remainder<=0;count<=0;busy<=1;prepare<=0;end
   else if(busy)begin
    remainder<=take?trial-{1'b0,denominator}:trial;quotient<=next_q;
    if(count==23)begin
     busy<=0;feature<=next_q[19:0];box_valid<=1;result_done<=1;
     xmin<=pending_lx;xmax<=pending_hx;ymin<=pending_ly;ymax<=pending_hy;
    end else count<=count+1'b1;
   end
  end
 end
endmodule
