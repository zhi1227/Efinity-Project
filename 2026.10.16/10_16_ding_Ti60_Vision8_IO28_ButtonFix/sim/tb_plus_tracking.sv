`timescale 1ns/1ps
module tb_plus_tracking;
 reg clk=0,rst=0,fs=0,fe=0,de=0,p=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;wire bv,ov;wire[10:0]x0,x1;wire[9:0]y0,y1;
 ep1_gesture #(.WIDTH(320),.HEIGHT(240),.TRACK(1),.BORDER(2),.ROI_X0(40),.ROI_X1(280),.ROI_Y0(20),.ROI_Y1(220)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.frame_end(fe),.enable(1'b1),.de(de),.bit_i(p),.x(x),.y(y),
 .box_valid(bv),.xmin(x0),.xmax(x1),.ymin(y0),.ymax(y1),.overflow(ov));
 integer scene=0,xx,yy;
 task start;begin @(negedge clk);fs=1;@(negedge clk);fs=0;end endtask
 task frame;begin
  for(yy=0;yy<240;yy=yy+1)begin
   for(xx=0;xx<320;xx=xx+1)begin
    @(negedge clk);de=1;x=xx;y=yy;
    p=(scene<2&&xx>=180&&xx<240&&yy>=100&&yy<160)||
      (scene==1&&xx>=60&&xx<140&&yy>=70&&yy<160)||
      (scene==2&&xx>=40&&xx<180&&yy>=50&&yy<200);
   end
   @(negedge clk);de=0;repeat(100)@(negedge clk);
  end
  @(negedge clk);fe=1;@(negedge clk);fe=0;repeat(3000)@(negedge clk);start();
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;start();frame();
  if(!bv||ov||x0!=180||x1!=239)$fatal(1,"Initial target");
  scene=1;frame();if(!bv||ov||x0!=180||x1!=239)$fatal(1,"Larger background stole tracked target");
  scene=2;frame();if(bv||ov)$fatal(1,"Clipped ROI candidate accepted");
  $display("PASS: CCL retains target against larger new region, rejects components touching detection boundary");$finish;
 end
endmodule
