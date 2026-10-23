`timescale 1ns/1ps
module tb_ramopt_shared_font;
 reg hdmi_clk=0, lvds_clk=0;
 always #6.720 hdmi_clk=~hdmi_clk;
 initial begin #1.137; forever #10.417 lvds_clk=~lvds_clk; end
 reg [12:0] hdmi_addr=0, lvds_addr=8191;
 wire [15:0] hdmi_bits,lvds_bits,hdmi_ref,lvds_ref;
 reg [15:0] reference [0:8191];
 integer hchecks=0,lchecks=0,hpixels=0,lpixels=0;
 reg hdmi_done=0,lvds_done=0;
 integer i,j,b;
 shared_glyph_rom dut(hdmi_clk,hdmi_addr,hdmi_bits,lvds_clk,lvds_addr,lvds_bits);
 shared_glyph_rom_reference original(hdmi_clk,hdmi_addr,hdmi_ref,lvds_clk,lvds_addr,lvds_ref);
 initial $readmemh("shared_font_expected_8192.hex",reference);
 always @(posedge hdmi_clk) begin
  #0.001;
  if(hdmi_bits !== hdmi_ref || hdmi_bits !== reference[hdmi_addr])
   $fatal(1,"HDMI row/latency mismatch addr=%0d got=%04x legacy=%04x expected=%04x",hdmi_addr,hdmi_bits,hdmi_ref,reference[hdmi_addr]);
  for(integer x=0;x<16;x=x+1) begin
   if(hdmi_bits[x] !== reference[hdmi_addr][x]) $fatal(1,"HDMI pixel mismatch");
   hpixels=hpixels+1;
  end
  hchecks=hchecks+1;
 end
 always @(posedge lvds_clk) begin
  #0.001;
  if(lvds_bits !== lvds_ref || lvds_bits !== reference[lvds_addr])
   $fatal(1,"LVDS row/latency mismatch addr=%0d got=%04x legacy=%04x expected=%04x",lvds_addr,lvds_bits,lvds_ref,reference[lvds_addr]);
  for(integer x=0;x<16;x=x+1) begin
   if(lvds_bits[x] !== reference[lvds_addr][x]) $fatal(1,"LVDS pixel mismatch");
   lpixels=lpixels+1;
  end
  lchecks=lchecks+1;
 end
 initial begin
  for(i=0;i<8192;i=i+1) begin @(negedge hdmi_clk); hdmi_addr=i; end
  for(i=0;i<4096;i=i+1) begin @(negedge hdmi_clk); hdmi_addr=$urandom_range(8191,0); end
  @(negedge hdmi_clk); hdmi_done=1;
 end
 initial begin
  for(j=8191;j>=0;j=j-1) begin @(negedge lvds_clk); lvds_addr=j; end
  for(j=0;j<4096;j=j+1) begin @(negedge lvds_clk); lvds_addr=$urandom_range(8191,0); end
  @(negedge lvds_clk); lvds_done=1;
 end
 initial begin
  wait(hdmi_done && lvds_done);
  if(hchecks<12288 || lchecks<12288) $fatal(1,"Insufficient coverage");
  $display("PASS: compressed shared font all 8192 addresses, independent 74.4/48 MHz clocks, original one-edge latency, random simultaneous reads and %0d exact pixels (%0d HDMI rows, %0d LVDS rows)",hpixels+lpixels,hchecks,lchecks);
  $finish;
 end
 initial begin #1000000; $fatal(1,"timeout"); end
endmodule
