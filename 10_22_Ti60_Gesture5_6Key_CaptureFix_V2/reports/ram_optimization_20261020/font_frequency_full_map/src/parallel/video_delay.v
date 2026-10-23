// Fixed-clock raster delay. Read and write addresses are different.
// LATENCY is measured like LATENCY pipeline registers; includes blanking.
`timescale 1ns/1ps
module video_delay #(parameter BITS=48, parameter LATENCY=6618)(
 input clk, input rst_n, input [BITS-1:0] din,
 output [BITS-1:0] dout
);
 localparam AW=$clog2(LATENCY);
 reg [AW-1:0] ptr;
 reg [AW:0] fill;
 wire [BITS-1:0] q;
 wire [AW-1:0] rd=(ptr==LATENCY-1)?0:ptr+1'b1;
 // Wide deep delays otherwise waste RAM on a rounded 8192-word depth.
 // Narrow masks keep their original packing. Both paths preserve cycle timing.
 generate if(BITS>=8 && LATENCY>1024) begin: banked
   localparam BANKS=(LATENCY+1023)/1024;
   localparam BANK_AW=AW-10;
   wire [BANKS*BITS-1:0] bank_values;
   reg [BANK_AW-1:0] selected_bank;
   genvar bank;
   for(bank=0;bank<BANKS;bank=bank+1) begin: storage
     // A partial final bank needs only its reachable addresses. In particular,
     // the 19-bit raster tail fits one 512x20 block instead of two 1024x10s.
     localparam DEPTH=(LATENCY-bank*1024<1024)?LATENCY-bank*1024:1024;
     (* ram_style="block" *) reg [BITS-1:0] mem[0:DEPTH-1];
     reg [BITS-1:0] read_value;
     always @(posedge clk) begin
       if(ptr[AW-1:10]==bank) mem[ptr[9:0]]<=din;
       read_value<=mem[rd[9:0]];
     end
     assign bank_values[bank*BITS+:BITS]=read_value;
   end
   always @(posedge clk) selected_bank<=rd[AW-1:10];
   assign q=bank_values[selected_bank*BITS+:BITS];
 end else begin: original_packing
   (* ram_style="block" *) reg [BITS-1:0] mem[0:LATENCY-1];
   reg [BITS-1:0] read_value;
   always @(posedge clk) begin
     mem[ptr]<=din;
     read_value<=mem[rd];
   end
   assign q=read_value;
 end endgenerate
 always @(posedge clk or negedge rst_n)
   if (!rst_n) begin ptr<=0; fill<=0; end
   else begin
     ptr <= (ptr==LATENCY-1)?0:ptr+1'b1;
     if(fill<LATENCY) fill<=fill+1'b1;
   end
 assign dout=(fill>=LATENCY)?q:{BITS{1'b0}};
endmodule
