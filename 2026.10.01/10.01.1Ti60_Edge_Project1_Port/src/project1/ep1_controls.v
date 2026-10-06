// K1 short/long: next/previous mode. K2 short/long: threshold +/-5.
// Boot directly into M3 (Sobel). K3/RESET is hardware reset, not mode 3.
// Commands commit together at the next input frame boundary.
module ep1_button #(parameter DEBOUNCE=1488000, LONG_PRESS=59520000)(
 input clk,rst_n,key_n,output reg short_pulse,long_pulse);
 (* async_reg="true" *) reg meta,sync;
 reg stable,armed,long_sent;
 reg [31:0] debounce_count,held_count;
 always @(posedge clk) begin
  if(!rst_n) begin meta<=0;sync<=0;stable<=0;armed<=0;long_sent<=0;
   debounce_count<=0;held_count<=0;short_pulse<=0;long_pulse<=0;end
  else begin
   meta<=key_n;sync<=meta;short_pulse<=0;long_pulse<=0;
   if(sync==stable)debounce_count<=0;
   else if(debounce_count==DEBOUNCE-1)begin
    debounce_count<=0;stable<=sync;
    if(sync)begin
     if(armed&&!long_sent)short_pulse<=1;
     armed<=1;held_count<=0;long_sent<=0;
    end else begin held_count<=0;long_sent<=0;end
   end else debounce_count<=debounce_count+1'b1;
   if(!stable&&armed&&!long_sent&&sync==stable)begin
    if(held_count==LONG_PRESS-1)begin long_pulse<=1;long_sent<=1;end
    else held_count<=held_count+1'b1;
   end
  end
 end
endmodule

module ep1_controls #(parameter DEBOUNCE=1488000,LONG_PRESS=59520000)(
 input clk,rst_n,frame_start,key_mode_n,key_threshold_n,
 output reg[2:0]mode,output reg[7:0]threshold,output reg[7:0]skin_lower);
 wire ms,ml,ts,tl;reg[2:0]requested_mode;reg[7:0]requested_threshold,requested_skin;
 ep1_button #(.DEBOUNCE(DEBOUNCE),.LONG_PRESS(LONG_PRESS)) bm(clk,rst_n,key_mode_n,ms,ml);
 ep1_button #(.DEBOUNCE(DEBOUNCE),.LONG_PRESS(LONG_PRESS)) bt(clk,rst_n,key_threshold_n,ts,tl);
 always @(posedge clk)begin
  if(!rst_n)begin mode<=3;requested_mode<=3;threshold<=100;requested_threshold<=100;skin_lower<=10;requested_skin<=10;end
  else begin
   if(ms)requested_mode<=requested_mode+3'd1;
   else if(ml)requested_mode<=requested_mode-3'd1;
   if(mode==7)begin
    if(ts)requested_skin<=requested_skin>=80?8'd85:requested_skin+8'd5;
    else if(tl)requested_skin<=requested_skin<5?8'd0:requested_skin-8'd5;
   end else begin
    if(ts)requested_threshold<=requested_threshold>250?8'd255:requested_threshold+8'd5;
    else if(tl)requested_threshold<=requested_threshold<5?8'd0:requested_threshold-8'd5;
   end
   if(frame_start)begin mode<=requested_mode;threshold<=requested_threshold;skin_lower<=requested_skin;end
  end
 end
endmodule
