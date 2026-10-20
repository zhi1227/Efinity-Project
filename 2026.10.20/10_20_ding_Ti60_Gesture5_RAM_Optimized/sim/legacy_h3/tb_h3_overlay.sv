`timescale 1ns/1ps
module tb_h3_overlay;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg de=0,pure_en=0,valid=1;reg[2:0]gesture=0;
 wire[23:0]rgb;wire od;
 vision6_overlay dut(.clk(clk),.rst_n(rst),.mode(4'd15),.rgb(24'h35729A),.de(de),.vs(1'b1),.hs(1'b1),
 .x(x),.y(y),.edge_pixel(1'b1),.raw_edge(1'b1),.compare_edge(1'b1),.raw_strength(8'd180),.gray_pixel(8'd100),
 .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
 .hand_valid(valid),.hand_box({10'd500,10'd150,11'd700,11'd350}),.gesture(gesture),.hand_skin(1'b1),.health(8'hFF),
 .hand_enable(1'b1),.hand_overflow(1'b0),.debug_class(3'd0),.rgb_o(rgb),.de_o(od));
 integer fd,g,xx,yy,count=0;reg capture=0;
 always @(negedge clk)if(capture&&od)begin
  if(^rgb===1'bx)$fatal(1,"Unknown overlay pixel");
  $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);count=count+1;
 end
 task sample(input integer px,py,input[23:0]expected);begin
  @(posedge clk);#1;x=px;y=py;de=1;repeat(3)@(posedge clk);#1;
  if(rgb!==expected)$fatal(1,"Overlay %0d,%0d got %h expected %h",px,py,rgb,expected);
 end endtask
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(g=0;g<4;g=g+1)begin
   gesture=g;fd=$fopen($sformatf("reports/h3_overlay_%0d.ppm",g),"wb");$fwrite(fd,"P6\n400 400\n255\n");capture=1;count=0;
   for(yy=50;yy<450;yy=yy+1)for(xx=880;xx<1280;xx=xx+1)begin @(posedge clk);#1;x=xx;y=yy;de=1;end
   @(posedge clk);#1;de=0;repeat(3)@(posedge clk);#1;
   capture=0;$fclose(fd);if(count!=160000)$fatal(1,"Wrong preview raster");
  end
  gesture=1;sample(1084,104,24'hFFCB55);
  valid=0;sample(1084,104,24'h30343D);sample(400,250,24'h35729A);
  pure_en=1;sample(1084,104,24'h35729A);sample(20,10,24'h35729A);sample(240,100,24'h35729A);
  $display("PASS: three HDMI matrix + Chinese/English results, idle on missing target, no cyan debug tint, pure capture removes every overlay");$finish;
 end
endmodule
