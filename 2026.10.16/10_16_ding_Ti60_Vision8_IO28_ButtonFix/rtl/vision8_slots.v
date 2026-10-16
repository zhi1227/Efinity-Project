module vision8_slots(
 input clk,reset,write_done,read_start,freeze_async,
 input aux_protect,input[1:0]aux_slot,
 output reg[1:0]write_slot,read_slot,output reg frozen,have_frame);
 (* async_reg="true" *)reg fm,fs;
 reg[1:0]latest;reg displayed;integer i;reg found;reg[1:0]candidate,next_write;
 always @*begin
  found=0;next_write=write_slot;
  for(i=1;i<4;i=i+1)begin
   candidate=write_slot+i;
   if(!found&&candidate!=read_slot&&(!aux_protect||candidate!=aux_slot))begin next_write=candidate;found=1;end
  end
 end
 always @(posedge clk or posedge reset)begin
  if(reset)begin fm<=0;fs<=0;write_slot<=0;read_slot<=2;latest<=0;displayed<=0;frozen<=0;have_frame<=0;end
  else begin
   fm<=freeze_async;fs<=fm;
   if(write_done)begin write_slot<=next_write;latest<=write_slot;have_frame<=1;end
   if(read_start)begin
    if(fs&&have_frame&&displayed)frozen<=1;
    else begin frozen<=0;if(write_done)read_slot<=write_slot;else if(have_frame)read_slot<=latest;end
    if(write_done||have_frame)displayed<=1;
   end
  end
 end
endmodule
