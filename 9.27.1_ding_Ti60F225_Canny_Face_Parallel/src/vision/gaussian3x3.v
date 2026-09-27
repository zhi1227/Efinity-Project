// [1 2 1; 2 4 2; 1 2 1]/16, round to nearest (sum+8)>>4.
// Same single-register latency and coordinate interface as median3x3.
module gaussian3x3(input clk,rst_n,valid_i,input [10:0] x_i,input [9:0] y_i,
 input [71:0] window_i,output reg [7:0] gray_o,output reg valid_o,
 output reg [10:0] x_o,output reg [9:0] y_o);
 wire [11:0] sum={4'b0,window_i[71:64]}+{3'b0,window_i[63:56],1'b0}
  +{4'b0,window_i[55:48]}+{3'b0,window_i[47:40],1'b0}
  +{2'b0,window_i[39:32],2'b0}+{3'b0,window_i[31:24],1'b0}
  +{4'b0,window_i[23:16]}+{3'b0,window_i[15:8],1'b0}
  +{4'b0,window_i[7:0]}+12'd8;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin gray_o<=0;valid_o<=0;x_o<=0;y_o<=0;end
 else begin gray_o<=sum[11:4];valid_o<=valid_i;x_o<=x_i;y_o<=y_i;end
endmodule
