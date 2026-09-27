// Four DDR slots. Events are in the AXI domain, after writer drain / reader reset.
// Freeze pins the DISPLAYED slot, not a partly written camera frame. Writer
// always skips that slot and keeps acquiring. Reader still replays it at 60 Hz.
module frame_buffer_select(
 input clk,reset,write_done,read_start,freeze_async,
 output reg [1:0] write_slot,read_slot,
 output reg frozen,output reg have_frame);
 (* async_reg="true" *) reg freeze_meta,freeze_sync;
 reg [1:0] latest;
 reg displayed_valid;
 wire [1:0] next_slot=write_slot+2'd1;
 always @(posedge clk or posedge reset)
 if(reset) begin
   freeze_meta<=0;freeze_sync<=0;write_slot<=0;read_slot<=2;
   latest<=0;frozen<=0;have_frame<=0;
 end else begin
   freeze_meta<=freeze_async;freeze_sync<=freeze_meta;
   if(write_done) begin
     // A simultaneous live read selects old write_slot. next_slot cannot equal it.
     write_slot<=(next_slot==read_slot)?write_slot+2'd2:next_slot;
     latest<=write_slot;have_frame<=1;
   end
   if(read_start) begin
     // Do not freeze an uninitialised slot at startup. First publish a full frame.
     if(freeze_sync && have_frame && displayed_valid) frozen<=1;
     else begin
       frozen<=0;
       if(write_done) read_slot<=write_slot;
       else if(have_frame) read_slot<=latest;
     end
   end
 end
 always @(posedge clk or posedge reset)
 if(reset) displayed_valid<=0;
 else if(read_start && (write_done || have_frame)) displayed_valid<=1;
endmodule
