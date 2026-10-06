`timescale 1ns/1ps
module tb_haar_near;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0;reg[23:0]rgb=0;reg de=0,vs=0,hs=0;
 wire[23:0]out;wire od,ov,oh,overflow;
 haar_face_video #(.DIAGNOSTICS(0),.SELF_TEST(0),.HOLD_FRAMES(4)) dut(clk,rst_n,rgb,de,vs,hs,3'd1,12'd40,12'd80,out,od,ov,oh,overflow);
 reg[7:0]im[0:14399];integer row,col,f,idx,i;reg[7:0]v;
 integer saw_face=0,saw_clear=0,saw_early=0,published=0;integer clocks=0,first_raw_clock=0,first_display_clock=0,first_done_clock=0,starts=0;reg[3:0]last_count=0;reg[335:0]last_boxes=0;reg prev_fs=0;
 reg[1:0] next_expected;
 reg[7:0]r8,g8,b8;reg[15:0]lum;
 always @(posedge clk)if(rst_n)begin
  clocks=clocks+1;
  if(dut.dv&&first_raw_clock==0)first_raw_clock=clocks;
  if(dut.hd&&first_done_clock==0)first_done_clock=clocks;
  if(dut.start)begin
   if(dut.capture_phase!==starts%4)$fatal(1,"FAIL phase rotation");
   starts=starts+1;
   for(i=0;i<14400;i=i+1)begin
    v=dut.captured_id==1?im[i]:8'd128;
    r8={v[7:3],v[7:5]};g8={v[7:2],v[7:6]};b8=r8;lum=77*r8+150*g8+29*b8;
    if(dut.core.frame_mem[i]!==lum[15:8])$fatal(1,"FAIL snapshot pixel %0d frame=%0d got=%0d expected=%0d",i,dut.captured_id,dut.core.frame_mem[i],lum[15:8]);
   end
   $display("PASS captured snapshot frame_id=%0d",dut.captured_id);
  end
  prev_fs=dut.display_fs;
  #1;
  if(dut.display_count!=last_count||dut.display_boxes!=last_boxes)begin
    if(!prev_fs)$fatal(1,"FAIL boxes changed mid-frame");
    if(dut.display_count>0)begin
     if(dut.display_boxes[21:11]-dut.display_boxes[10:0]+1<=384)$fatal(1,"FAIL large face was not displayed as a large box");
     saw_face=1;if(dut.hb)saw_early=1;if(first_display_clock==0)first_display_clock=clocks;$display("PASS positive frame published faces=%0d raw=%0d",dut.display_count,dut.last_raw);end
    if(saw_face&&dut.display_count==0)begin saw_clear=1;$display("PASS blank frame clears faces");end
  end
  last_count=dut.display_count;last_boxes=dut.display_boxes;
 end
 initial begin
  $readmemh("sim/near.mem",im);repeat(5)@(negedge clk);rst_n=1;
  for(f=0;f<14;f=f+1)begin
   for(row=0;row<750;row=row+1)for(col=0;col<1650;col=col+1)begin
    @(negedge clk);vs=row>=5;hs=col>=40;de=row>=25&&row<745&&col>=200&&col<1480;
    if(de)begin idx=((row-25)/8)*160+(col-200)/8;rgb=f<1?{im[idx],im[idx],im[idx]}:24'h808080;end
    else rgb=0;
   end
  end
  if(!saw_face||!saw_clear||overflow)$fatal(1,"FAIL integration face=%d clear=%d overflow=%b",saw_face,saw_clear,overflow);
  if(first_display_clock-first_raw_clock>1237600)$fatal(1,"FAIL first box publication latency");
  $display("PASS early publish clocks: raw=%0d display=%0d full_done=%0d",first_raw_clock,first_display_clock,first_done_clock);
  // Explicitly exercise simultaneous completion and next-frame capture.
  @(negedge clk);next_expected=dut.next_phase+2'd1;
  force dut.hb=0;force dut.hd=1;force dut.fs=1;force dut.capturing=0;force dut.start=0;
  @(posedge clk);#1;
  if(dut.capture_phase!==next_expected)$fatal(1,"FAIL repeated phase at completion/capture boundary");
  @(negedge clk);release dut.hb;release dut.hd;release dut.fs;release dut.capturing;release dut.start;
  $display("PASS simultaneous completion/capture preserves phase rotation");
  $display("PASS large face beyond old 384px limit reaches display and clears");$finish;
 end
endmodule
