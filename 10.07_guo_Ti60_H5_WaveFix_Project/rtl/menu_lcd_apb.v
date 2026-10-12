module menu_lcd_apb (
 input clk,reset,input [12:0] status_i,
 input [15:0] paddr,input psel,penable,pwrite,input [31:0] pwdata,
 output reg [31:0] prdata,output [23:0] rgb,output de
);
 reg [16:0] pending,active_state;
 reg [10:0] h;
 reg [9:0] v;
 reg [31:0] frames;
 wire frame_start=(h==0 && v==0);
 always @(posedge clk) begin
   if(reset) begin pending<=17'd0;active_state<=17'd0;h<=0;v<=0;frames<=0;end
   else begin
     if(psel && penable && pwrite && paddr==16'h0004) pending<=pwdata[16:0];
     if(frame_start) active_state<=pending;
     if(h==1343) begin
       h<=0;
       if(v==634) begin v<=0;frames<=frames+1'b1;end else v<=v+1'b1;
     end else h<=h+1'b1;
   end
 end
 always @* begin
   case(paddr)
     16'h0000:prdata={19'd0,status_i};
     16'h0004:prdata={15'd0,pending};
     16'h0008:prdata={15'd0,active_state};
     16'h000c:prdata=frames;
     default:prdata=0;
   endcase
 end
 wire visible=(h>=160 && h<1184 && v>=23 && v<623);
 wire [10:0] x=h-11'd160;
 wire [9:0] y=v-10'd23;
 menu_renderer renderer(.clk(clk),.reset(reset),.x(x),.y(y),.visible(visible),
   .mode(active_state[3:0]),.held(active_state[4]),.ready(active_state[16]),.health(active_state[12:5]),
   .rgb(rgb),.de(de));
endmodule
