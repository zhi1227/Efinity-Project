// Stable press AND release; boot-held keys must first be released.
module button_press #(parameter CYCLES=1488000)(
 input clk,rst_n,key_n,output reg pulse);
 localparam BITS=(CYCLES<2)?1:$clog2(CYCLES);
 (* async_reg="true" *) reg meta,sync;
 reg stable,armed;reg [BITS-1:0] counter;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin meta<=0;sync<=0;stable<=0;armed<=0;counter<=0;pulse<=0;end
 else begin
   meta<=key_n;sync<=meta;pulse<=0;
   if(sync==stable) counter<=0;
   else if(counter==CYCLES-1) begin
     counter<=0;stable<=sync;
     if(sync) armed<=1;
     else begin pulse<=armed;armed<=0;end
   end else counter<=counter+1'b1;
 end
endmodule
