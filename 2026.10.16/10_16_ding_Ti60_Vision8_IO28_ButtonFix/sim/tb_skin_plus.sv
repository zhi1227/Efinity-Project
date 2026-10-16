`timescale 1ns/1ps
module tb_skin_plus;
 reg clk=0,rst=0;always #5 clk=~clk;reg[23:0]rgb=0;reg[7:0]lo=10;wire mask;
 ep1_skin dut(.clk(clk),.rst_n(rst),.de(1'b1),.fs(1'b0),.x(11'd100),.y(10'd100),.rgb(rgb),.lower(lo),.mask(mask));
 task check(input[23:0]p,input expected);begin
  @(negedge clk);rgb=p;repeat(3)@(negedge clk);if(mask!==expected)$fatal(1,"Skin %h got %b expected %b",p,mask,expected);
 end endtask
 initial begin repeat(3)@(negedge clk);rst=1;
  check(24'hC88C6E,1);check(24'hA56F55,1);check(24'hFF0000,0);check(24'hFFFFFF,0);check(24'hDCD1C8,0);check(24'h204080,0);check(24'h100805,0);
  lo=85;check(24'hC88C6E,0);
  $display("PASS: representative skin, warm near-white cloth, saturated red, blue, darkness, UART threshold guard");$finish;end
endmodule
