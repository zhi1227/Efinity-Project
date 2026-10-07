// K2 short action fires on release. Long action never also fires short.
// Debounce both edges; a key held at reset must first be released.
module gesture_key #(parameter DEBOUNCE=1488000,LONG_CYCLES=148800000)(
 input clk,rst_n,key_n,output reg short_press,long_press);
 localparam DB=(DEBOUNCE<2)?1:$clog2(DEBOUNCE);
 localparam LB=(LONG_CYCLES<2)?1:$clog2(LONG_CYCLES);
 (* async_reg="true" *) reg meta,sync;
 reg stable,armed,held,fired;reg[DB-1:0]deb;reg[LB-1:0]duration;
 always @(posedge clk)begin
  if(!rst_n)begin meta<=0;sync<=0;stable<=0;armed<=0;held<=0;fired<=0;deb<=0;duration<=0;short_press<=0;long_press<=0;end
  else begin
   meta<=key_n;sync<=meta;short_press<=0;long_press<=0;
   if(sync==stable)deb<=0;
   else if(deb==DEBOUNCE-1)begin
    deb<=0;stable<=sync;
    if(sync)begin armed<=1;if(held&&!fired)short_press<=1;held<=0;duration<=0;end
    else if(armed)begin armed<=0;held<=1;fired<=0;duration<=0;end
   end else deb<=deb+1'b1;
   if(held&&!stable&&!fired)begin
    if(duration==LONG_CYCLES-1)begin fired<=1;long_press<=1;end
    else duration<=duration+1'b1;
   end
  end
 end
endmodule
