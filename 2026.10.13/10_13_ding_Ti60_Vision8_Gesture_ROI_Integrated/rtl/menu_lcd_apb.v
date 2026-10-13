module menu_lcd_apb #(parameter V8_ENABLE=0,SHARED_FONT=0) (
 input clk,reset,input [12:0] status_i,
 input [15:0] paddr,input psel,penable,pwrite,input [31:0] pwdata,
 output reg [31:0] prdata,output [23:0] rgb,output de,input[639:0]status8_i
,output[11:0]shared_addr,input[15:0]shared_bits);
 reg [16:0] pending,active_state;
 reg[639:0]snapshot8,shadow8,pending8,active8;
 reg[31:0]sequence8;
 wire[4:0]read_index=(paddr-16'h0040)>>2,write_index=(paddr-16'h00a0)>>2;
 reg [10:0] h;
 reg [9:0] v;
 reg [31:0] frames;
 wire frame_start=(h==0 && v==0);
 always @(posedge clk)begin
  if(reset)begin snapshot8<=0;shadow8<=0;pending8<=0;active8<=0;sequence8<=0;end
  else if(V8_ENABLE)begin
   if(psel&&penable&&pwrite)begin
    if(paddr==16'h0020)begin snapshot8<=status8_i;sequence8<=sequence8+1'b1;end
    if(paddr>=16'h00a0&&paddr<16'h00f0)shadow8[write_index*32+:32]<=pwdata;
    if(paddr==16'h0024)pending8<=shadow8;
   end
   if(frame_start)active8<=pending8;
  end
 end
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
     16'h0020:prdata=sequence8;
     default:begin
      if(V8_ENABLE&&paddr>=16'h0040&&paddr<16'h0090)prdata=snapshot8[read_index*32+:32];
      else prdata=0;
     end
   endcase
 end
 wire visible=(h>=160 && h<1184 && v>=23 && v<623);
 wire [10:0] x=h-11'd160;
 wire [9:0] y=v-10'd23;
 generate if(V8_ENABLE)begin:ui8
 menu8_renderer #(.SHARED_FONT(SHARED_FONT)) renderer(clk,reset,x,y,visible,active8,rgb,de,shared_addr,shared_bits);
 end else begin:ui6
 menu_renderer #(.SHARED_FONT(SHARED_FONT)) renderer(.clk(clk),.reset(reset),.x(x),.y(y),.visible(visible),
   .mode(active_state[3:0]),.held(active_state[4]),.ready(active_state[16]),.health(active_state[12:5]),
   .rgb(rgb),.de(de),.shared_addr(shared_addr),.shared_bits(shared_bits));
 end endgenerate
endmodule
