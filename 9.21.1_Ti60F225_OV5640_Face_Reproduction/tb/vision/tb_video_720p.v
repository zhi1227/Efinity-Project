`timescale 1ns/1ps
module tb_video_720p;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[23:0]rgb=0;reg de=0,vs=0,hs=1;
 wire[23:0]out;wire od,ov,oh;wire[3:0]count;wire overrun;
 face_canny_video dut(clk,rst,rgb,de,vs,hs,out,od,ov,oh,count,overrun);
 integer xx,yy,f,valids=0,edges=0;
 always @(posedge clk) begin
 #1;
 if(rst && dut.cv) begin
   valids=valids+1;if(dut.ce) edges=edges+1;
   if(!dut.ade || dut.ex!==dut.ax || dut.ey!==dut.ay)
     $fatal(1,"720p alignment mismatch");
 end
 end
 initial begin
 repeat(4) @(negedge clk);rst=1;
 for(f=0;f<3;f=f+1) begin
   de=0;vs=0;repeat(3*1650) @(negedge clk);
   vs=1;repeat(25*1650) @(negedge clk);
   for(yy=0;yy<720;yy=yy+1) begin
     for(xx=0;xx<1650;xx=xx+1) begin
       de=xx<1280;
       rgb=(xx>=160 && xx<320 && yy>=160 && yy<352)?24'he6b496:24'h202020;
       @(negedge clk);
     end
   end
   de=0;rgb=0;repeat(2*1650) @(negedge clk);
 end
 if(valids!=3*1272*712 || edges==0) $fatal(1,"invalid 720p pixel count");
 if(count!=1 || overrun) $fatal(1,"720p face count=%d overrun=%b",count,overrun);
 if(dut.boxes[41:0]!=={10'd351,10'd160,11'd319,11'd160})
   $fatal(1,"720p box geometry");
 $display("PASS 720p: %0d valid pixels; original-color skin rectangle -> candidate box; no processing overrun",valids);
 $finish;
 end
 initial begin #50000000;$fatal(1,"timeout");end
endmodule
