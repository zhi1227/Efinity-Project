`timescale 1ns/1ps
module tb_canny_controls;
 reg clk=0,rst_n=0,fs=0,io34=1,rx=1,io28=1,io29=1,io35=0,k1=1,k2=1;
 always #5 clk=~clk;
 wire requested,settings,pip,freeze;wire[2:0]mode;wire[11:0]low,high;
 vision8_controls #(.DEBOUNCE(3),.LONG_CYCLES(24),.CANNY_DYNAMIC_ENABLE(1),.UART_CLKS_PER_BIT(8)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.io28(io28),.io29(io29),.io34(io34),.io35(io35),.k1_n(k1),.k2_n(k2),
 .capture_busy(1'b0),.learning(1'b0),.rx(rx),.canny_mode_request(requested),.settings_open(settings),.user_mode(mode),
 .pip_enable(pip),.freeze_request(freeze),.low(low),.high(high));
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task short34;begin io34=0;cycles(10);io34=1;cycles(12);end endtask
 task uart(input[7:0]v);integer b;begin
  rx=0;cycles(8);for(b=0;b<8;b=b+1)begin rx=v[b];cycles(8);end rx=1;cycles(24);
 end endtask
 initial begin
  cycles(5);rst_n=1;cycles(15);
  if(requested!==0)$fatal(1,"boot must be BASELINE");
  repeat(6)begin io34=0;cycles(1);io34=1;cycles(1);end cycles(12);
  if(requested!==0)$fatal(1,"IO34 bounce changed Canny");
  short34();if(requested!==1||mode!==0||pip||freeze)$fatal(1,"IO34 short must toggle Canny only");
  io34=0;cycles(70);io34=1;cycles(12);if(requested!==1)$fatal(1,"IO34 long/release must have no assigned action");
  short34();if(requested!==0)$fatal(1,"second IO34 short must select BASELINE");
  uart("A");if(requested!==1)$fatal(1,"UART A");
  uart("B");if(requested!==0)$fatal(1,"UART B");
  uart("A");uart("+");if(requested!==0||low!==48||high!==88)$fatal(1,"manual UART thresholds must return BASELINE");
  uart("A");io35=1;cycles(10);io35=0;cycles(12);
  if(!settings||requested!==1)$fatal(1,"opening IO35 settings must keep adaptive selection");
  k2=0;cycles(10);k2=1;cycles(12);
  if(requested!==0||low!==49||high!==88)$fatal(1,"manual IO35-page change must return BASELINE");
  uart("A");uart("r");if(requested!==0||low!==40||high!==80)$fatal(1,"r must restore original manual defaults");
  rst_n=0;io34=0;cycles(5);rst_n=1;cycles(70);if(requested!==0)$fatal(1,"boot-held IO34");
  io34=1;cycles(12);if(requested!==0)$fatal(1,"boot-held release");
  short34();if(requested!==1)$fatal(1,"IO34 must rearm after boot-held release");
  // The new button shares the existing context cancellation rule.
  io34=0;cycles(10);io28=0;cycles(10);io28=1;cycles(12);io34=1;cycles(12);
  if(requested!==1||mode!==1)$fatal(1,"mode change during held IO34 must cancel old event");
  $display("PASS: IO34 low-active debounce/short/long/boot/context, UART A/B/r, manual override, existing mode isolation");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
