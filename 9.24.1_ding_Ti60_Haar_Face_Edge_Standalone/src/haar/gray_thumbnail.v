`timescale 1ns/1ps
// Anti-aliased 8x8 average. Stores only one partial-sum row, not another frame.
module gray_thumbnail #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,input valid_i,input [10:0] x_i,input [9:0] y_i,input [7:0] gray_i,
 output reg valid_o,output reg [7:0] gray_o
);
 (* ram_style="block" *) reg [13:0] column_sum[0:WIDTH/8-1];
 reg [13:0] column_q;reg [10:0] row_sum;
 wire [13:0] full_sum=((y_i[2:0]==0)?14'd0:column_q)+{3'b0,row_sum}+{6'b0,gray_i};
 wire [13:0] rounded=full_sum+14'd32;
 always @(posedge clk)begin
  if(x_i<WIDTH)column_q<=column_sum[x_i[10:3]];
  if(valid_i&&x_i<WIDTH&&y_i<HEIGHT&&x_i[2:0]==7)column_sum[x_i[10:3]]<=full_sum;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin row_sum<=0;valid_o<=0;gray_o<=0;end
 else begin
  valid_o<=0;
  if(valid_i&&x_i<WIDTH&&y_i<HEIGHT)begin
   if(x_i[2:0]==0)row_sum<=gray_i;else row_sum<=row_sum+gray_i;
   if(x_i[2:0]==7&&y_i[2:0]==7)begin valid_o<=1;gray_o<=rounded[13:6];end
  end
 end
endmodule
