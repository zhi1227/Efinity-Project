// Bundled-data toggle handshake: source payload stays fixed until acknowledged.
module menu_status_cdc (
 input src_clk, src_reset, input [12:0] src_status,
 input dst_clk, dst_reset, output reg [12:0] dst_status
);
 reg [12:0] payload;
 reg request, acknowledge;
 (* async_reg="true" *) reg ack_meta, ack_sync;
 (* async_reg="true" *) reg req_meta, req_sync;
 always @(posedge src_clk or posedge src_reset)
 if(src_reset) begin payload<=13'd0;request<=0;ack_meta<=0;ack_sync<=0;end
 else begin
   ack_meta<=acknowledge;ack_sync<=ack_meta;
   if(ack_sync==request && payload!=src_status) begin
     payload<=src_status;request<=~request;
   end
 end
 always @(posedge dst_clk or posedge dst_reset)
 if(dst_reset) begin req_meta<=0;req_sync<=0;acknowledge<=0;dst_status<=13'd0;end
 else begin
   req_meta<=request;req_sync<=req_meta;
   if(req_sync!=acknowledge) begin dst_status<=payload;acknowledge<=req_sync;end
 end
endmodule
