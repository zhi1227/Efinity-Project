// Spatial mean, not point sampling. 128 columns; synchronous reset for Ti60.
module bg_thumbnail #(parameter BLOCK=10,ROWS=72)(
 input clk,rst_n,frame_start,enable,de,input[7:0]gray,
 output reg we,output reg[13:0]addr,output reg[7:0]value,output reg done);
 reg[3:0]sx,sy;reg[6:0]cx,cy;reg active,pending;
 reg[11:0]horizontal;
 reg[14:0]sums[0:127];
 wire[12:0]line_sum={1'b0,horizontal}+gray;
 wire[15:0]total=(sy==0)?{3'b0,line_sum}:({1'b0,sums[cx]}+line_sum);
 always @(posedge clk)begin
 if(!rst_n)begin sx<=0;sy<=0;cx<=0;cy<=0;active<=0;pending<=0;horizontal<=0;we<=0;done<=0;addr<=0;value<=0;end
 else begin
   we<=0;done<=pending;pending<=0;
   if(frame_start)begin
     sx<=0;sy<=0;cx<=0;cy<=0;horizontal<=0;active<=enable;
   end else if(de&&active)begin
     if(sx==BLOCK-1)begin
       sx<=0;horizontal<=0;sums[cx]<=total[14:0];
       if(sy==BLOCK-1)begin we<=1;addr<={cy,cx};value<=total/(BLOCK*BLOCK);end
       if(cx==127)begin
         cx<=0;
         if(sy==BLOCK-1)begin sy<=0;if(cy==ROWS-1)begin active<=0;pending<=1;end else cy<=cy+1'b1;end
         else sy<=sy+1'b1;
       end else cx<=cx+1'b1;
     end else begin sx<=sx+1'b1;horizontal<=line_sum[11:0];end
   end
 end
 end
endmodule

