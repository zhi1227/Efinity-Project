`timescale 1ns/1ps
module tb_menu_controls;
 reg clk=0,rst_n=0,rx=1,key_n=0;
 always #5 clk=~clk;
 wire [3:0] mode;wire [11:0] low,high;
 uart_params #(.CLKS_PER_BIT(20),.KEY_DEBOUNCE_CYCLES(4)) dut(clk,rst_n,rx,mode,low,high,key_n);
 task cycles(input integer n);repeat(n) @(negedge clk);endtask
 task press;
   key_n=0;cycles(25);key_n=1;cycles(25);
 endtask
 task byte_tx(input [7:0] v);
   rx=0;cycles(20);
   for(integer b=0;b<8;b=b+1) begin rx=v[b];cycles(20);end
   rx=1;cycles(30);
 endtask
 initial begin
   cycles(5);rst_n=1;cycles(30);
   if(mode!=3) $fatal(1,"Boot-held button changed mode");
   key_n=1;cycles(20);
   press();if(mode!=5) $fatal;
   press();if(mode!=10) $fatal;
   press();if(mode!=12) $fatal;
   press();if(mode!=0) $fatal;
   press();if(mode!=1) $fatal;
   press();if(mode!=3) $fatal;
   key_n=0;cycles(100);if(mode!=5) $fatal(1,"Held key repeats");
   key_n=1;cycles(20);
   byte_tx("2");if(mode!=5) $fatal(1,"Hidden UART mode accepted");
   byte_tx("c");if(mode!=12) $fatal;
   byte_tx("m");if(mode!=0) $fatal;
   byte_tx("+");if(low!=48||high!=96) $fatal;
   byte_tx("r");if(mode!=3||low!=40||high!=80) $fatal;
   $display("PASS: six-mode K1 cycle, debounce, held key, UART whitelist, thresholds, reset");$finish;
 end
endmodule
