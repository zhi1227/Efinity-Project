`timescale 1ns/1ps
module tb_overlay6;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg[3:0]mode=15;reg[10:0]x=0;reg[9:0]y=0;reg de=0,pure_en=0,valid=1;reg[2:0]gesture=0;
 wire[23:0]rgb;wire od,ov,oh;
 vision6_overlay dut(.clk(clk),.rst_n(rst),.mode(mode),.rgb(24'h35729A),.de(de),.vs(1'b1),.hs(1'b1),
 .x(x),.y(y),.edge_pixel(1'b1),.raw_edge(1'b1),.compare_edge(1'b1),.raw_strength(8'd180),.gray_pixel(8'd100),
 .frozen(1'b1),.pure_en(pure_en),.detect(1'b1),.count(4'd8),.boxes(336'd0),
 .shape_class(2'd2),.shape_box(42'd0),.hand_valid(valid),.hand_box({10'd700,10'd0,11'd1279,11'd0}),
 .gesture(gesture),.hand_skin(1'b1),.health(8'hFF),.rgb_o(rgb),.de_o(od),.vs_o(ov),.hs_o(oh));
 integer fd=0,g,xx,yy,count=0;reg capture=0;
 always @(negedge clk)if(capture&&od)begin
  if(^rgb===1'bx)$fatal(1,"Unknown overlay pixel");
  $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);count=count+1;
 end
 task sample(input integer px,py,input[23:0]expected);begin
   @(posedge clk);#1;x=px;y=py;de=1;repeat(3)@(posedge clk);#1;
   if(rgb!==expected)$fatal(1,"Overlay pixel %0d,%0d got %h expected %h",px,py,rgb,expected);
 end endtask
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(g=0;g<6;g=g+1)begin
   gesture=g;fd=$fopen($sformatf("reports/avatar_%0d.ppm",g),"wb");$fwrite(fd,"P6\n400 350\n255\n");capture=1;count=0;
   for(yy=50;yy<400;yy=yy+1)for(xx=880;xx<1280;xx=xx+1)begin @(posedge clk);#1;x=xx;y=yy;de=1;end
   @(posedge clk);#1;de=0;repeat(3)@(posedge clk);#1;
   capture=0;$fclose(fd);if(count!=140000)$fatal(1,"Preview raster");
  end
  pure_en=1;
  sample(18,10,24'h35729A);sample(18,70,24'h35729A);sample(1100,100,24'h35729A);sample(1050,340,24'h35729A);
  pure_en=0;valid=0;gesture=1;sample(1225,140,24'h122439); // raised arm absent for unknown target
  valid=1;gesture=1;sample(1225,140,24'h56D8DD);
  valid=0;gesture=3;sample(1080,450,24'h35729A); // invalid box cannot paint hand edges
  $display("PASS: Chinese result/character render, unknown no response, pure clears HUD/status/character/contours");$finish;
 end
endmodule
