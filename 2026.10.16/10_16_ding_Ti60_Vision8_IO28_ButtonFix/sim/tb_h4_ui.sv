`timescale 1ns/1ps
module tb_h4_ui;
 reg clk=0,rst=0,de=0,pure_en=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[2:0]step=0,state=0,trained=0,gesture=0;
 reg[1:0]error=0;reg[255:0]bitmap=0;wire[23:0]rgb;wire od;
 vision6_overlay dut(.clk(clk),.rst_n(rst),.mode(4'd15),.rgb(24'h516878),.de(de),.vs(1'b1),.hs(1'b1),
  .x(x),.y(y),.edge_pixel(1'b0),.raw_edge(1'b0),.compare_edge(1'b0),.raw_strength(8'd0),.gray_pixel(8'd0),
  .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
  .hand_valid(1'b1),.hand_box({10'd590,10'd200,11'd720,11'd390}),.gesture(gesture),.hand_skin(1'b0),.health(8'hFF),
  .hand_enable(1'b1),.hand_overflow(1'b0),.debug_raw(20'd0),.debug_clean(20'd0),.debug_ratio(20'd0),.debug_fill(10'd0),
  .debug_reject(4'd0),.debug_fault(4'd0),.debug_class(3'd0),.debug_lower(8'd10),.rgb_o(rgb),.de_o(od),
  .learn_step(step),.learn_state(state),.learn_error(error),.trained(trained),.learn_countdown(8'd70),.preview(bitmap),.wave_phase(3'd2),.preview_valid(1'b1));
 integer fd,xx,yy,n,count,r,c;reg capture=0;
 always @(negedge clk)if(capture&&od)begin
  if(^rgb===1'bx)$fatal(1,"Unknown UI colour");
  $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);count=count+1;
 end
 initial begin
  for(r=0;r<16;r=r+1)for(c=0;c<16;c=c+1)bitmap[r*16+c]=(r>=8&&c>1&&c<14)||(r<8&&c%4<2);
  repeat(3)@(negedge clk);rst=1;
  for(n=0;n<6;n=n+1)begin
   case(n)
    0:begin state=0;step=0;trained=0;end
    1:begin state=1;step=1;end
    2:begin state=2;step=2;end
    3:begin state=6;step=3;error=2;end
    4:begin state=0;step=0;trained=7;gesture=3;end
    5:pure_en=1;
   endcase
   fd=$fopen($sformatf("reports/h4_ui_%0d.ppm",n),"wb");$fwrite(fd,"P6\n1280 720\n255\n");capture=1;count=0;
   for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin @(posedge clk);#1;x=xx;y=yy;de=1;end
   @(posedge clk);#1;de=0;repeat(3)@(posedge clk);#1;capture=0;$fclose(fd);
   if(count!=921600)$fatal(1,"UI raster count");
  end
  $display("PASS: full 720p H4 untrained, palm guide, countdown, ambiguity/retry, result and pure-capture UI rasters");$finish;
 end
endmodule
