// 115200 8N1 receiver in pixel domain; two-flop RX synchronization.
// ASCII '0'..'4': mode, 'm': next mode, '+','-': thresholds, 'r': reset.
module uart_params #(parameter CLKS_PER_BIT=645)(input clk,rst_n,rx,
 output reg [2:0] mode,output reg [11:0] low,high);
 reg rx_meta,rx_sync;reg [1:0] state;reg [15:0] timer;reg [2:0] bitno;
 reg [7:0] data;reg valid;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin rx_meta<=1;rx_sync<=1;end
 else begin rx_meta<=rx;rx_sync<=rx_meta;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin state<=0;timer<=0;bitno<=0;data<=0;valid<=0;end
 else begin
 valid<=0;
 case(state)
 0:if(!rx_sync) begin state<=1;timer<=CLKS_PER_BIT/2;end
 1:if(timer!=0) timer<=timer-1'b1;else if(!rx_sync) begin state<=2;timer<=CLKS_PER_BIT-1;bitno<=0;end else state<=0;
 2:if(timer!=0) timer<=timer-1'b1;else begin data[bitno]<=rx_sync;timer<=CLKS_PER_BIT-1;if(bitno==7) state<=3;else bitno<=bitno+1'b1;end
 3:if(timer!=0) timer<=timer-1'b1;else begin valid<=rx_sync;state<=0;end
 endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin mode<=3;low<=40;high<=80;end
 else if(valid) begin
 if(data>=8'h30 && data<=8'h34) mode<=data-8'h30;
 else case(data)
 8'h6d:mode<=(mode==4)?0:mode+1'b1;
 8'h2b:if(low<1000) begin low<=low+8;high<=high+16;end
 8'h2d:if(low>8) begin low<=low-8;high<=high-16;end
 8'h72:begin mode<=3;low<=40;high<=80;end
 endcase
 end
endmodule
