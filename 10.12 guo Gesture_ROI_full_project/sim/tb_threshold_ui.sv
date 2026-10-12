`timescale 1ns/1ps
module tb_threshold_ui;
 reg clk=0,rst=0,de=0,pure_en=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[2:0]step=0,state=0,trained=7,gesture=0;
 reg[2:0]wave_phase=0;reg[1:0]error=0;reg[255:0]bitmap=0;
 reg[3:0]mode=1;reg[25:0]threshold_state={2'b00,12'd80,12'd40};
 wire[23:0]rgb,lcd_rgb;wire od,lcd_de;
 wire edge_pixel=(x>=240&&x<=640&&(y==160||y==500))||(y>=160&&y<=500&&(x==240||x==640));
 menu_renderer lcd(.clk(clk),.reset(!rst),.x(x),.y(y),.visible(de),.mode(mode),
  .held(1'b0),.ready(1'b1),.health(8'hff),.rgb(lcd_rgb),.de(lcd_de),.threshold_state(threshold_state));
 vision6_overlay dut(.clk(clk),.rst_n(rst),.threshold_state(threshold_state),.mode(mode),.rgb(24'h516878),.de(de),.vs(1'b1),.hs(1'b1),
  .x(x),.y(y),.edge_pixel(edge_pixel),.raw_edge(1'b0),.compare_edge(1'b0),.raw_strength(8'd0),.gray_pixel(8'd0),
  .frozen(1'b0),.pure_en(pure_en),.detect(1'b0),.count(4'd0),.boxes(336'd0),.shape_class(2'd0),.shape_box(42'd0),
  .hand_valid(1'b1),.hand_box({10'd590,10'd200,11'd720,11'd390}),.gesture(gesture),.hand_skin(1'b0),.health(8'hFF),
  .hand_enable(1'b1),.hand_overflow(1'b0),.debug_raw(20'd0),.debug_clean(20'd0),.debug_ratio(20'd0),.debug_fill(10'd0),
  .debug_reject(4'd0),.debug_fault(4'd0),.debug_class(3'd0),.debug_lower(8'd10),.rgb_o(rgb),.de_o(od),
  .learn_step(step),.learn_state(state),.learn_error(error),.trained(trained),.learn_countdown(8'd70),.preview(bitmap),.wave_phase(wave_phase),.preview_valid(1'b1));

 integer fd,xx,yy,n,count,r,c,k;reg capture=0,lcd_capture=0;
 reg[23:0]pixel;integer w,h;
 always @(negedge clk)if(capture&&(lcd_capture?lcd_de:od))begin
  pixel=lcd_capture?lcd_rgb:rgb;
  if(^pixel===1'bx)$fatal(1,"Unknown UI colour");
  $fwrite(fd,"%c%c%c",pixel[23:16],pixel[15:8],pixel[7:0]);count=count+1;
 end
 initial begin
  for(r=0;r<16;r=r+1)for(c=0;c<16;c=c+1)bitmap[r*16+c]=(r>=8&&c>1&&c<14)||(r<8&&c%4<2);
  repeat(3)@(negedge clk);rst=1;
  // Decimal conversion checked across every possible 12-bit value.
  for(k=0;k<4096;k=k+1)begin
   threshold_state={2'b10,12'(4095-k),12'(k)};
   repeat(2)@(negedge clk);
   if(dut.threshold_panel.low_bcd!=={4'(k/1000),4'((k/100)%10),4'((k/10)%10),4'(k%10)})$fatal(1,"Low decimal conversion %0d",k);
   if(dut.threshold_panel.high_bcd!=={4'((4095-k)/1000),4'(((4095-k)/100)%10),4'(((4095-k)/10)%10),4'((4095-k)%10)})$fatal(1,"High decimal conversion %0d",k);
  end
  for(n=0;n<6;n=n+1)begin
   lcd_capture=n<3;w=lcd_capture?1024:1280;h=lcd_capture?600:720;
   threshold_state=n%3==0?{2'b00,12'd80,12'd40}:(n%3==1?{2'b10,12'd80,12'd48}:{2'b11,12'd4095,12'd4087});
   fd=$fopen($sformatf("reports/threshold_ui_%0d.ppm",n),"wb");$fwrite(fd,"P6\n%0d %0d\n255\n",w,h);capture=1;count=0;
   for(yy=0;yy<h;yy=yy+1)for(xx=0;xx<w;xx=xx+1)begin @(posedge clk);#1;x=xx;y=yy;de=1;end
   @(posedge clk);#1;de=0;repeat(3)@(posedge clk);#1;capture=0;$fclose(fd);
   if(count!=w*h)$fatal(1,"UI raster count %0d",count);
  end
  // Pure capture is unchanged outside the editor, with explicit editor access.
  pure_en=1;threshold_state={2'b00,12'd80,12'd40};x=880;y=640;de=1;
  repeat(4)@(negedge clk);if(rgb!=24'h516878)$fatal(1,"Idle hint leaked into pure capture");
  threshold_state[25]=1;repeat(4)@(negedge clk);if(rgb==24'h516878)$fatal(1,"Editor unavailable in pure capture");
  $display("PASS: all 4096 decimal values; six full LCD/HDMI rasters; idle/low/high selection; pure capture editor access; unchanged pixel counts");$finish;
 end
endmodule
