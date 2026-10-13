`timescale 1ns/1ps
module tb_vision8_fifo;
 reg wc=0,rc=0,reset=1,we=0,re=0;always #5 wc=~wc;always #7 rc=~rc;
 reg[31:0]wd=0;wire[31:0]rd;wire full,empty;wire[4:0]wl,rl;
 vision8_fifo #(.AB(4))dut(wc,rc,reset,we,wd,re,rd,full,empty,wl,rl);
 integer pushed=0,popped=0;reg[31:0]rng=32'h5319bc84;
 always @(negedge wc)begin
  if(!reset)begin rng=rng*1664525+1013904223;we=pushed<1200&&!full&&(rng[2:0]!=0);wd=32'hc0010000+pushed;end
 end
 always @(posedge wc)if(!reset&&we&&!full)pushed=pushed+1;
 always @(negedge rc)if(!reset)re=!empty&&($time>2000?($time%5!=0):0);
 always @(posedge rc)if(!reset&&re&&!empty)begin
  if(rd!==32'hc0010000+popped)$fatal(1,"FIFO order %d expected %h got %h",popped,32'hc0010000+popped,rd);
  popped=popped+1;if(popped==1200)begin $display("PASS: asynchronous FIFO registered RAM prefetch, full/empty wrap and random stalls");$finish;end
 end
 initial begin #60;reset=0;#300000;$fatal(1,"FIFO timeout pushed=%d popped=%d",pushed,popped);end
endmodule

