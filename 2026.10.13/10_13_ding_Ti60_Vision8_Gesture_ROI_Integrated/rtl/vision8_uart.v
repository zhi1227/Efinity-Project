module vision8_uart #(parameter CLKS_PER_BIT=645)(input clk,rst_n,rx,output reg valid,output reg[7:0]data);
 (* async_reg="true" *)reg meta,sync;reg[1:0]state;reg[15:0]timer;reg[2:0]bitno;
 always @(posedge clk)begin
  if(!rst_n)begin meta<=1;sync<=1;state<=0;timer<=0;bitno<=0;data<=0;valid<=0;end
  else begin
   meta<=rx;sync<=meta;valid<=0;
   case(state)
    0:if(!sync)begin state<=1;timer<=CLKS_PER_BIT/2;end
    1:if(timer!=0)timer<=timer-1'b1;else if(!sync)begin state<=2;timer<=CLKS_PER_BIT-1;bitno<=0;end else state<=0;
    2:if(timer!=0)timer<=timer-1'b1;else begin data[bitno]<=sync;timer<=CLKS_PER_BIT-1;if(bitno==7)state<=3;else bitno<=bitno+1'b1;end
    3:if(timer!=0)timer<=timer-1'b1;else begin valid<=sync;state<=0;end
   endcase
  end
 end
endmodule
