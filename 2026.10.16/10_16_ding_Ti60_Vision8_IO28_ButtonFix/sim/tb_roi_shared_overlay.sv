`timescale 1ns/1ps
// Production shared font with both unrelated clocks active, against legacy
// independent font reads; geometry assertions specify the intended new ROI.
module tb_roi_shared_overlay;
 reg clk=0,lclk=0,rst=0;always #5 clk=~clk;always #7 lclk=~lclk;
 reg [10:0]x=0;reg [9:0]y=0;reg de=0,pure_en=0,valid=0;
 reg [2:0]gesture=0,learn_step=0;reg[3:0]mode=15;reg[7:0]health=255;
 wire [23:0]rgb,rgb_legacy;wire od,od_legacy;
 wire [12:0]font_addr;wire [15:0]font_bits,other_bits;
 reg [12:0]other_addr=0;reg [15:0]expected_font[0:8191];
 initial begin for(integer k=0;k<8192;k=k+1)expected_font[k]=0;$readmemh("shared_font.hex",expected_font,0,4607);end
 shared_glyph_rom shared_font(clk,font_addr,font_bits,lclk,other_addr,other_bits);
 integer other_reads=0,compared_pixels=0;
 always @(negedge lclk)other_addr<=other_addr+13;
 reg [12:0]other_sample;
 always @(posedge lclk)begin
  other_sample=other_addr;#1;
  if(other_bits!==expected_font[other_sample])$fatal(1,"independent LCD font port corrupt at %0d",other_sample);
  other_reads=other_reads+1;
 end
 vision6_overlay #(.SHARED_FONT(1)) dut(
  .clk(clk),.rst_n(rst),.mode(mode),.rgb(24'h35729A),.de(de),.vs(1'b1),.hs(1'b1),
  .x(x),.y(y),.edge_pixel(1'b1),.raw_edge(1'b0),.compare_edge(1'b1),.raw_strength(8'd180),.gray_pixel(8'd100),
  .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
  .hand_valid(valid),.hand_box({10'd500,10'd150,11'd700,11'd350}),.gesture(gesture),.hand_skin(1'b1),.health(health),
  .learn_step(learn_step),.learn_state(3'd0),.learn_error(2'd0),.trained(3'd7),.learn_countdown(8'd0),
  .preview(256'd0),.wave_phase(3'd2),.preview_valid(1'b0),.hand_enable(1'b1),.hand_overflow(1'b0),
  .debug_raw(20'd0),.debug_clean(20'd0),.debug_fill(10'd0),.debug_ratio(20'd0),.debug_reject(4'd0),.debug_fault(4'd0),.debug_class(3'd0),.debug_lower(8'd10),
  .rgb_o(rgb),.de_o(od),.shared_addr(font_addr),.shared_bits(font_bits));
 vision6_overlay #(.SHARED_FONT(0)) legacy(
  .clk(clk),.rst_n(rst),.mode(mode),.rgb(24'h35729A),.de(de),.vs(1'b1),.hs(1'b1),
  .x(x),.y(y),.edge_pixel(1'b1),.raw_edge(1'b0),.compare_edge(1'b1),.raw_strength(8'd180),.gray_pixel(8'd100),
  .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
  .hand_valid(valid),.hand_box({10'd500,10'd150,11'd700,11'd350}),.gesture(gesture),.hand_skin(1'b1),.health(~health),
  .learn_step(learn_step),.learn_state(3'd0),.learn_error(2'd0),.trained(3'd7),.learn_countdown(8'd0),
  .preview(256'd0),.wave_phase(3'd2),.preview_valid(1'b0),.hand_enable(1'b1),.hand_overflow(1'b0),
  .debug_raw(20'd0),.debug_clean(20'd0),.debug_fill(10'd0),.debug_ratio(20'd0),.debug_reject(4'd0),.debug_fault(4'd0),.debug_class(3'd0),.debug_lower(8'd10),
  .rgb_o(rgb_legacy),.de_o(od_legacy));
 always @(negedge clk)if(rst)begin
  if(od!==od_legacy||rgb!==rgb_legacy)$fatal(1,"shared and legacy overlay mismatch near %0d,%0d",x,y);
  if(od)begin
   if(^rgb===1'bx)$fatal(1,"unknown shared font pixel");
   compared_pixels=compared_pixels+1;
  end
 end
 task sample(input integer px,py,input [23:0]expected);begin
  @(negedge clk);x=px;y=py;de=1;repeat(3)@(posedge clk);#1;
  if(!od||rgb!==expected)$fatal(1,"Overlay %0d,%0d got %h expected %h",px,py,rgb,expected);
 end endtask
 integer xx,yy,g;
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  // Module health must never paint the camera image, with either bit polarity.
  mode=0;
  for(yy=48;yy<76;yy=yy+1)for(xx=16;xx<528;xx=xx+1)begin
   health=xx[0]?8'hff:8'h00;sample(xx,yy,24'h35729A);
  end
  $display("PASS: HDMI diagnostics removed across entire former label/bar area; health bits have no pixel effect");
  mode=15;
  // Every new side is two pixels, with outside and third inside pixel untouched.
  sample(39,300,24'h35729A);sample(40,300,24'hA4B6C8);sample(41,300,24'hA4B6C8);sample(42,300,24'h35729A);
  sample(998,300,24'h35729A);sample(999,300,24'hA4B6C8);sample(1000,300,24'hA4B6C8);sample(1001,300,24'h35729A);
  sample(600,39,24'h35729A);sample(600,40,24'hA4B6C8);sample(600,41,24'hA4B6C8);sample(600,42,24'h35729A);
  sample(900,678,24'h35729A);sample(900,679,24'hA4B6C8);sample(900,680,24'hA4B6C8);sample(900,681,24'h35729A);
  sample(160,300,24'h35729A);sample(960,300,24'h35729A);sample(600,60,24'h35729A);sample(900,660,24'h35729A);
  valid=1;sample(40,300,24'h35D499);sample(1000,300,24'h35D499);valid=0;
  // Existing palm instruction square, thumbnail and matrix locations remain.
  learn_step=1;sample(560,342,24'hFF40E0);sample(542,360,24'hFF40E0);sample(578,360,24'hFF40E0);sample(560,378,24'hFF40E0);
  sample(541,360,24'h35729A);learn_step=0;
  sample(1099,500,24'h35729A);sample(1100,500,24'h493522);sample(1227,500,24'h493522);sample(1228,500,24'h35729A);
  valid=1;gesture=1;sample(1084,104,24'hFFCB55);valid=0;sample(1084,104,24'h30343D);
  // Scan the complete right-side HUD for all result classes using the shared
  // font port, while the unrelated LCD port continuously cycles all addresses.
  for(g=0;g<4;g=g+1)begin
   valid=(g!=0);gesture=g;
   for(yy=64;yy<607;yy=yy+1)for(xx=1024;xx<1264;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;de=1;
   end
  end
  pure_en=1;learn_step=1;sample(40,300,24'h35729A);sample(560,342,24'h35729A);sample(1084,104,24'h35729A);sample(1100,500,24'h35729A);
  if(compared_pixels<500000||other_reads<1000)$fatal(1,"insufficient shared font coverage");
  $display("PASS: SHARED_FONT=1 new two-pixel ROI sides and old edges removed; palm square/right HUD unchanged; %0d pixels equal legacy font with %0d concurrent LCD reads; pure capture strips overlays",compared_pixels,other_reads);
  $finish;
 end
 initial begin #10000000;$fatal(1,"ROI shared overlay timeout");end
endmodule
