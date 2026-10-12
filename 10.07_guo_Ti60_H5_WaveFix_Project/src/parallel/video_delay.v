// Fixed-clock raster delay. Read and write addresses are different.
// LATENCY is measured like LATENCY pipeline registers; includes blanking.
`timescale 1ns/1ps
module video_delay #(parameter BITS=48, parameter LATENCY=6618)(
 input clk, input rst_n, input [BITS-1:0] din,
 output [BITS-1:0] dout
);
 localparam AW=$clog2(LATENCY);
 (* ram_style="block" *) reg [BITS-1:0] mem[0:LATENCY-1];
 reg [AW-1:0] ptr;
 reg [AW:0] fill;
 reg [BITS-1:0] q;
 wire [AW-1:0] rd=(ptr==LATENCY-1)?0:ptr+1'b1;
 always @(posedge clk) begin
   mem[ptr] <= din;
   q <= mem[rd];
 end
 always @(posedge clk or negedge rst_n)
   if (!rst_n) begin ptr<=0; fill<=0; end
   else begin
     ptr <= (ptr==LATENCY-1)?0:ptr+1'b1;
     if(fill<LATENCY) fill<=fill+1'b1;
   end
 assign dout=(fill>=LATENCY)?q:{BITS{1'b0}};
endmodule
