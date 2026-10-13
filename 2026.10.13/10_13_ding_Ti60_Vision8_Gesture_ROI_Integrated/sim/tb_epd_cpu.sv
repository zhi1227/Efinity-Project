`timescale 1ns/1ps
module tb_epd_cpu;
 reg clk=0, locked=0, busy=0;
 reg [12:0] status=13'h123;
 always #10.416667 clk=~clk;
 wire reset,sclk,mosi,cs,dc,rst;
 wire[11:0]font_addr;wire[15:0]font_bits;reg[11:0]other_addr=0;
reg font_clk=0;always #6.72043 font_clk=~font_clk;
always @(negedge font_clk)other_addr<=other_addr+1'b1;
shared_glyph_rom font_shared(font_clk,other_addr,,clk,font_addr,font_bits);
 riscv_menu_top #(.SHARED_FONT(1),.EPD_CLK_HZ(100000),.EPD_SPI_HALF_PERIOD(2)) dut(.shared_addr(font_addr),.shared_bits(font_bits),
  .status_i(status),.tx_slowclk(clk),.txpll_locked(locked),.lcd_reset(reset),
  .epd_busy(busy),.epd_clk(sclk),.epd_din(mosi),.epd_cs_n(cs),.epd_dc(dc),.epd_rst_n(rst));
 reg [7:0] pixels[0:14999];
 reg [8:0] expected[0:30032];
 integer n=0, received=0,bits=0,i;
 reg [7:0] word;
 reg byte_dc;
 task cmd(input [7:0] b); begin expected[n]={1'b0,b}; n=n+1; end endtask
 task data(input [7:0] b); begin expected[n]={1'b1,b}; n=n+1; end endtask
 initial begin
  $readmemh("epaper.hex",pixels);
  cmd('h12); cmd('h21);data('h40);data(0);cmd('h3c);data(5);cmd('h11);data(3);
  cmd('h44);data(0);data(49);cmd('h45);data(0);data(0);data('h2b);data(1);
  cmd('h4e);data(0);cmd('h4f);data(0);data(0);cmd('h24);
  for(i=0;i<15000;i=i+1) data(pixels[i]);
  cmd('h4e);data(0);cmd('h4f);data(0);data(0);cmd('h26);
  for(i=0;i<15000;i=i+1) data(pixels[i]);
  cmd('h22);data('hf7);cmd('h20);cmd('h10);data(1);
  if(n!=30033) $fatal(1,"expected count %d",n);
  #1000;locked=1;
 end
 always @(negedge cs) begin
  if(sclk!==0) $fatal(1,"SPI idle clock");
  bits=0;word=0;byte_dc=dc;
 end
 always @(posedge sclk) if(!cs) begin
  word={word[6:0],mosi};bits=bits+1;
  if(dc!==byte_dc) $fatal(1,"DC changed during byte");
 end
 always @(posedge cs) if(locked && !reset && bits!=0) begin
  if(bits!=8 || received>=n || {byte_dc,word}!==expected[received])
   $fatal(1,"SPI byte %d: got %h expected %h bits %d",received,{byte_dc,word},expected[received],bits);
  received=received+1;bits=0;
 end
 // Emulated screen: delayed BUSY assertion and long refresh. Menu must remain live.
 initial begin
  wait(received==30031);
  repeat(20) @(posedge clk);
  busy=1;status=13'h1ac9;
  repeat(1200000) @(posedge clk);
  if(dut.display.pending!==17'h11ac9 || dut.display.active_state!==17'h11ac9)
   $fatal(1,"menu blocked during e-paper refresh");
  busy=0;
 end
 initial begin
  wait(locked);wait(!rst);
  repeat(180) @(posedge clk);
  if(rst!==0) $fatal(1,"reset low pulse too short");
  wait(rst);
  wait(dut.epaper.app_status==3 || dut.epaper.app_status[7]);
  if(dut.epaper.app_status!=3 || received!=30033)
   $fatal(1,"firmware status %h bytes %d",dut.epaper.app_status,received);
  repeat(10000) @(posedge clk);
  if(received!=30033 || cs!==1 || rst!==1) $fatal(1,"unexpected restart");
  $display("PASS: real RISC-V firmware, 30033 SPI bytes, both image planes, reset, BUSY and live LVDS menu");
  $finish;
 end
 initial begin #2000000000; $fatal(1,"CPU e-paper simulation timeout bytes=%d status=%h",received,dut.epaper.app_status); end
endmodule
