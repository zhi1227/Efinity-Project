`timescale 1ns/1ps
module tb_haar_selftest;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0;reg[23:0]rgb=0;reg de=0,vs=0,hs=0;
 wire[23:0]out;wire od,ov,oh,overflow;
 haar_face_video dut(clk,rst_n,rgb,de,vs,hs,3'd1,12'd40,12'd80,out,od,ov,oh,overflow);
 integer row,col,f;
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  for(f=0;f<15;f=f+1)for(row=0;row<750;row=row+1)for(col=0;col<1650;col=col+1)begin
   @(negedge clk);vs=row>=5;hs=col>=40;de=row>=25&&row<745&&col>=200&&col<1480;rgb=de?24'h808080:24'd0;
  end
  if(!dut.self_ok||dut.self_raw!=dut.SELF_EXPECTED||!dut.test_done||dut.completed==0||dut.display_count!=0)$fatal(1,"FAIL startup self=%b raw=%d done=%b live_completed=%d boxes=%d",dut.self_ok,dut.self_raw,dut.test_done,dut.completed,dut.display_count);
  $display("PASS startup self-test expected raw boxes, test results suppressed, switches to live blank camera");$finish;
 end
endmodule
