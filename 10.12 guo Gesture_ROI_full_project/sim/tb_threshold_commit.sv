`timescale 1ns/1ps
module tb_threshold_commit;
 reg clk=0,dc=0,rst=0,vs=0,editing=0,sel=0;always #5 clk=~clk;always #7 dc=~dc;
 reg[11:0]low=40,high=80;wire[25:0]state,transported;
 parallel_video #(.WIDTH(64),.HEIGHT(48),.H_TOTAL(80)) dut(
  .clk(clk),.rst_n(rst),.rgb_i(24'd0),.de_i(1'b0),.vs_i(vs),.hs_i(1'b1),
  .mode_i(4'd1),.low_i(low),.high_i(high),.freeze_i(1'b0),.pure_i(1'b0),.detect_i(1'b0),
  .skin_lower_i(8'd10),.health_i(8'hff),.gesture_short_i(1'b0),.gesture_long_i(1'b0),
  .threshold_edit_i(editing),.threshold_select_high_i(sel),.threshold_committed_o(state));
 menu_status_cdc #(.WIDTH(26)) bridge(clk,!rst,state,dc,!rst,transported);
 wire[23:0]rgb;wire de;wire[31:0]prdata;
 menu_lcd_apb lcd(.clk(dc),.reset(!rst),.status_i(13'h1fe1),.threshold_i(transported),
  .paddr(16'd0),.psel(1'b0),.penable(1'b0),.pwrite(1'b0),.pwdata(32'd0),.prdata(prdata),.rgb(rgb),.de(de));
 task tick(input integer n);repeat(n)@(negedge clk);endtask
 reg[25:0]old;reg[11:0]old_low,old_high;reg lcd_frame_q;
 always @(posedge dc)begin
  lcd_frame_q=lcd.frame_start;old=lcd.threshold_active;
  #1;if(rst&&!lcd_frame_q&&lcd.threshold_active!==old)$fatal(1,"LCD changed mid-frame");
 end
 initial begin
  tick(10);rst=1;tick(500);vs=1;tick(500);
  if(state!=={2'b00,12'd80,12'd40})$fatal(1,"Initial commit");
  low=56;high=104;editing=1;sel=1;tick(100);
  if(dut.low_active!=40||dut.high_active!=80||state[25])$fatal(1,"Thresholds changed mid-frame");
  vs=0;tick(500);vs=1;tick(500);
  if(state!=={2'b11,12'd104,12'd56}||transported!==state)$fatal(1,"Atomic UI/CDC commit");
  if(dut.u_canny.u_threshold.th_lo!=56||dut.u_canny.u_threshold.th_hi!=104)$fatal(1,"Values did not reach Canny classifier");
  repeat(860000)@(negedge dc);
  if(lcd.threshold_active!==state)$fatal(1,"LCD did not show latest committed values");
  $display("PASS: frame-atomic thresholds reach Canny; HDMI status, 26-bit CDC and LCD frame snapshot converge without tearing");$finish;
 end
 initial begin #30000000;$fatal(1,"Timeout");end
endmodule
