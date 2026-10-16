`timescale 1ns/1ps
module tb_controls6;
 reg clk=0,rst_n=0,rx=1,key_n=1;always #5 clk=~clk;
 wire[3:0]mode;wire[11:0]low,high;wire pure_en,detect;wire[7:0]skin;
 uart_params #(.CLKS_PER_BIT(16),.KEY_DEBOUNCE_CYCLES(4))dut(clk,rst_n,rx,mode,low,high,key_n,pure_en,detect,skin);
 task tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task send(input[7:0]b);integer k;begin rx=0;tick(16);for(k=0;k<8;k=k+1)begin rx=b[k];tick(16);end rx=1;tick(32);end endtask
 task key;begin key_n=0;tick(20);key_n=1;tick(20);end endtask
 task check(input integer m);if(mode!==m)$fatal(1,"mode %0d expected %0d",mode,m);endtask
 initial begin
  tick(5);rst_n=1;tick(20);check(0);
  key();check(1);key();check(10);key();check(9);key();check(14);key();check(15);key();check(0);
  send("2");check(10);send("4");check(14);send("5");check(15);
  send("f");if(!detect)$fatal(1,"detect toggle");
  send("p");check(0);if(!pure_en)$fatal(1,"pure_en capture");
  key();check(1);if(pure_en)$fatal(1,"key must leave pure_en capture");
  send("g");check(5);send("c");check(12);send("t");check(8);
  send("]");if(skin!=15)$fatal(1,"skin adjustment");send("r");check(0);
  if(pure_en||detect||skin!=10||low!=40||high!=80)$fatal(1,"defaults not restored");
  $display("PASS: six-mode keys, UART, pure_en capture, optional detection and auxiliary modes");$finish;
 end
endmodule
