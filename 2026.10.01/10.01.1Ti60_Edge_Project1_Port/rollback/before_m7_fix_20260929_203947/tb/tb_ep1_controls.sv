`timescale 1ns/1ps
module tb_ep1_controls;
 reg clk=0;always #5 clk=~clk;reg rst=0,fs=0,k1=0,k2=0;
 wire[2:0]mode;wire[7:0]threshold;
 ep1_controls #(.DEBOUNCE(3),.LONG_PRESS(12)) dut(clk,rst,fs,k1,k2,mode,threshold);
 task wait_clocks(input integer n);repeat(n)@(negedge clk);endtask
 task commit;begin fs=1;wait_clocks(1);fs=0;wait_clocks(1);end endtask
 task keypress(input integer keynum,input integer duration);
  begin if(keynum==1)k1=0;else k2=0;wait_clocks(duration);
   if(keynum==1)k1=1;else k2=1;wait_clocks(9);end
 endtask
 initial begin
  wait_clocks(5);rst=1;wait_clocks(30);commit;
  if(mode!=3||threshold!=100)$fatal(1,"M3 boot default or boot-held key handling");
  k1=1;k2=1;wait_clocks(10);
  k1=0;wait_clocks(1);k1=1;wait_clocks(8);commit;
  if(mode!=3)$fatal(1,"bounce accepted");
  keypress(1,9);if(mode!=3)$fatal(1,"mode changed mid-frame");commit;
  if(mode!=4)$fatal(1,"short next");
  keypress(1,40);commit;if(mode!=3)$fatal(1,"long previous or extra release");
  repeat(4)begin keypress(1,40);commit;end
  if(mode!=7)$fatal(1,"mode wrap");
  keypress(2,9);if(threshold!=100)$fatal(1,"threshold changed mid-frame");commit;
  if(threshold!=105)$fatal(1,"threshold plus");
  keypress(2,40);commit;if(threshold!=100)$fatal(1,"threshold minus");
  repeat(40)keypress(2,9);commit;if(threshold!=255)$fatal(1,"upper saturation");
  repeat(60)keypress(2,25);commit;if(threshold!=0)$fatal(1,"lower saturation");
  $display("PASS M3 boot default, buttons debounce, boot-held, short/long, no release duplicate, frame commit, wrap, saturation");$finish;
 end
endmodule
