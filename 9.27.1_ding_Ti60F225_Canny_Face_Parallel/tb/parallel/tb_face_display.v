`timescale 1ns/1ps
// Mode 3 must still detect a skin candidate and draw/clear its red border
// after removing mask display modes. Expected pixels/box are geometric constants.
module tb_face_display;
 // Square candidate satisfies the production width/height and aspect-ratio limits.
 localparam W=64,H=64,HT=96,D=4*(HT+1)+14;
 localparam [41:0] FULL_BOX={10'd63,10'd0,11'd63,11'd0};
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0,vs=0,hs=1;reg [23:0] rgb=0;
 wire [23:0] q;wire od,ov,oh,overrun;
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT),.CANNY_GAUSSIAN(1)) dut(
  .clk(clk),.rst_n(rst),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),
  .mode_i(4'd3),.low_i(12'd40),.high_i(12'd80),.freeze_i(1'b0),
  .rgb_o(q),.de_o(od),.vs_o(ov),.hs_o(oh),.overrun(overrun));
 reg [26:0] pipe[0:D];reg [23:0] expected=0;
 integer f,x,y,k,pixels=0,red_pixels=0;reg checking=0;
 always @(posedge clk)begin
  if(!rst)begin for(k=0;k<=D;k=k+1)pipe[k]=0;end
  else begin
   for(k=D;k>0;k=k-1)pipe[k]=pipe[k-1];pipe[0]={vs,hs,de,expected};
   #1;
   if(checking && {ov,oh,od,q}!==pipe[D])
     $fatal(1,"mode3 face display mismatch frame=%0d got=%h expected=%h",f,{ov,oh,od,q},pipe[D]);
   if(checking && od)begin pixels=pixels+1;if(q==24'hff0000)red_pixels=red_pixels+1;end
   if(overrun)$fatal(1,"mode3 detection overrun");
  end
 end
 task tick;begin @(negedge clk);end endtask
 initial begin
  repeat(5)tick;rst=1;repeat(D+8)tick;checking=1;
  for(f=0;f<4;f=f+1)begin
   vs=0;de=0;rgb=0;expected=0;repeat(HT*8)tick;
   vs=1;repeat(HT*8)tick;
   for(y=0;y<H;y=y+1)for(x=0;x<HT;x=x+1)begin
    de=x<W;hs=x>=W+4;rgb=(de && f<2)?24'hce9e7b:0;expected=0;
    // Whole-frame uniform skin activates every 8x8 cell, including 6x6 corners.
    // Results from frames 0/1 are published for frames 1/2; empty frame 2 clears frame 3.
    if(de && (f==1 || f==2) && (x<2 || x>=W-2 || y<2 || y>=H-2))expected=24'hff0000;
    tick;
   end
   de=0;rgb=0;expected=0;repeat(HT*40)tick;
   if(f==1 || f==2)begin
    if(dut.count!==1 || dut.boxes[41:0]!==FULL_BOX)$fatal(1,"candidate box missing or changed");
   end else if(dut.count!==0)$fatal(1,"startup/stale candidate not cleared");
  end
  if(pixels!=4*W*H || red_pixels!=2*(W*H-(W-4)*(H-4)))$fatal(1,"mode3 coverage mismatch");
  $display("PASS mode3 skin -> morphology -> CCL -> red box, next-frame publication and empty-frame clearing; %0d pixels, %0d red pixels",pixels,red_pixels);
  $finish;
 end
 initial begin #3000000;$fatal(1,"mode3 timeout");end
endmodule
