`timescale 1ns/1ps
module tb_controls;
 reg clk=0;always #5 clk=~clk;reg rst=0,rx=1;
 wire[2:0] mode;wire[11:0] low,high;
 uart_params #(.CLKS_PER_BIT(8)) u(clk,rst,rx,mode,low,high);
 reg[2:0] om=0;reg[23:0] rgb=24'h123456;reg de=1,vs=1,hs=1,edgep=1;
 reg[10:0] x=10;reg[9:0] y=10;reg[335:0] boxes=0;reg[3:0] count=1;
 wire[23:0] q;wire od,ov,oh;
 parallel_overlay dut(clk,rst,om,rgb,de,vs,hs,x,y,edgep,count,boxes,q,od,ov,oh);
 integer i,j;
 task send;input[7:0] b;integer k;begin
 rx=0;repeat(8)@(negedge clk);
 for(k=0;k<8;k=k+1)begin rx=b[k];repeat(8)@(negedge clk);end
 rx=1;repeat(12)@(negedge clk);
 end endtask
 task check;input[23:0] exp;begin @(negedge clk);if(q!==exp || {od,ov,oh}!=={de,vs,hs})$fatal(1,"overlay mode %d got %h expected %h",om,q,exp);end endtask
 initial begin
 repeat(4)@(negedge clk);rst=1;@(negedge clk);
 if(mode!=3 || low!=40 || high!=80)$fatal(1,"defaults");
 send("4");if(mode!=4)$fatal(1,"mode");send("m");if(mode!=0)$fatal(1,"mode wrap");
 send("+");if(low!=48 || high!=96)$fatal(1,"increase");
 for(j=0;j<150;j=j+1)send("+");if(low>1000 || high<=low)$fatal(1,"upper clamp");
 for(j=0;j<150;j=j+1)send("-");if(low!=8 || high!=16)$fatal(1,"lower clamp");
 send("r");if(mode!=3 || low!=40 || high!=80)$fatal(1,"reset command");
 boxes[41:0]={10'd30,10'd10,11'd30,11'd10};
 om=0;check(rgb);om=1;check(24'hffffff);om=2;check(24'hff0000);
 x=20;y=20;check(24'hffff00);x=40;check(24'h00ff00);edgep=0;check(rgb);
 om=3;edgep=1;check(24'hffffff);x=10;y=10;check(24'hff0000);
 om=4;x=20;y=20;check(24'hffff00);x=40;check(24'h303030);edgep=0;check(0);
 de=0;check(0);
 $display("PASS UART 0-4/m/+/-/reset/clamps and five-mode colour priority with sync");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
