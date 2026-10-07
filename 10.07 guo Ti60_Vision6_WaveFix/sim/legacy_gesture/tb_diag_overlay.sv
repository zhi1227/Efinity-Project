`timescale 1ns/1ps
module tb_diag_overlay;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg de=0,pure_en=0,valid=0,enable=1,overflow=0,skin=1;
 reg[1:0]g=0,dc=0;reg[19:0]raw=3600,clean=3580;reg[3:0]rejects=0,fault=0;wire[23:0]rgb;wire od;
 vision6_overlay #(.GESTURE_DEBUG(1))dut(.clk(clk),.rst_n(rst),.mode(4'd15),.rgb(24'h35729A),.de(de),.vs(1'b1),.hs(1'b1),
 .x(x),.y(y),.edge_pixel(1'b0),.raw_edge(1'b0),.compare_edge(1'b0),.raw_strength(8'd0),.gray_pixel(8'd0),
 .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
 .hand_valid(valid),.hand_box({10'd520,10'd200,11'd800,11'd400}),.gesture(g),.hand_skin(skin),.health(8'hFF),
 .hand_enable(enable),.hand_overflow(overflow),.debug_raw(raw),.debug_clean(clean),.debug_fill(10'd994),.debug_ratio(20'd1000),
 .debug_reject(rejects),.debug_fault(fault),.debug_class(dc),.debug_lower(8'd10),.rgb_o(rgb),.de_o(od));
 integer xx,yy,fd=0,pixels=0;reg capture=0;
 always @(negedge clk)if(capture&&od)begin
  if(^rgb===1'bx)$fatal(1,"unknown diagnostic pixel");
  $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);pixels=pixels+1;
 end
 task sample(input integer px,py,input[23:0]expected);begin
  @(posedge clk);#1;x=px;y=py;de=1;repeat(3)@(posedge clk);#1;
  if(rgb!==expected)$fatal(1,"diagnostic pixel %0d,%0d=%h expected=%h",px,py,rgb,expected);
 end endtask
 task reason(input integer wanted);begin
  @(posedge clk);#1;x=900;y=414;de=1;#1;
  if(dut.line_id!=wanted||!dut.text_on)$fatal(1,"reason got=%d expected=%d",dut.line_id,wanted);
 end endtask
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  sample(812,652,24'hFFFFFF); // last hexadecimal digit of LO must not be clipped
  // Invalid candidate still paints raw skin; accepted candidate gets a border.
  sample(500,450,24'h1AB9CD);valid=1;sample(400,450,24'hFFE040);
  valid=0;enable=0;reason(26);enable=1;clean=0;reason(27);clean=3580;reason(28);
  overflow=1;fault=4;reason(29);overflow=0;fault=0;valid=1;dc=0;reason(30);dc=2;reason(31);g=2;reason(12);
  pure_en=1;sample(500,450,24'h35729A);sample(400,450,24'h35729A);sample(20,654,24'h35729A);sample(900,414,24'h35729A);
  pure_en=0;valid=0;g=0;dc=0;rejects=1;de=0;repeat(4)@(posedge clk);#1;
  fd=$fopen("reports/gesture_diag_preview.ppm","wb");$fwrite(fd,"P6\n1280 720\n255\n");capture=1;pixels=0;
  for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin
   @(posedge clk);#1;x=xx;y=yy;de=1;skin=xx>=350&&xx<620&&yy>=180&&yy<590;
  end
  @(posedge clk);#1;de=0;repeat(3)@(posedge clk);#1;capture=0;$fclose(fd);
  if(pixels!=921600)$fatal(1,"preview pixel count %0d",pixels);
  $display("PASS: skin tint without candidate, accepted border, six wait reasons, pure capture clears diagnostics, full 720p preview");$finish;
 end
endmodule
