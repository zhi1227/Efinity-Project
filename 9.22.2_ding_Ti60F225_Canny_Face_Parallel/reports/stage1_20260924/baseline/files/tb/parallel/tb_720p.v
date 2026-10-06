`timescale 1ns/1ps
module tb_720p;
 reg clk=0;always #5 clk=~clk;reg rst=0,de=0,vs=0,hs=1;reg[23:0]rgb=0;
 wire[23:0]q;wire od,ov,oh,overrun;
 parallel_video dut(clk,rst,rgb,de,vs,hs,3'd2,12'd40,12'd80,q,od,ov,oh,overrun);
 integer x,y,f,n,edge_count,valid_count,processing,max_processing=0;
 always @(posedge clk)if(rst)begin
 #1;
 if(dut.cv)begin
 valid_count=valid_count+1;
 if(!dut.ade || dut.ex!==dut.ax || dut.ey!==dut.ay)$fatal(1,"720p Canny coord");
 end
 if(dut.mv && (!dut.md || dut.mx!==dut.mxa || dut.my!==dut.mya))$fatal(1,"720p morph coord");
 if(dut.aligned_edge)edge_count=edge_count+1;
 if(dut.busy)processing=processing+1;
 else if(processing>0)begin if(processing>max_processing)max_processing=processing;processing=0;end
 if(overrun)$fatal(1,"CCL deadline exceeded");
 end
 initial begin
 edge_count=0;valid_count=0;processing=0;
 repeat(4)@(negedge clk);rst=1;
 for(f=0;f<3;f=f+1)begin
 vs=0;de=0;repeat(1650*5)@(negedge clk);vs=1;repeat(1650*20)@(negedge clk);
 for(y=0;y<720;y=y+1)for(x=0;x<1650;x=x+1)begin
 de=x<1280;hs=x>=1320;rgb=(f==1)?24'hce9e7b:0;@(negedge clk);
 end
 de=0;rgb=0;repeat(1650*5)@(negedge clk);
 end
 repeat(600000)@(negedge clk);
 if(valid_count!=3*1272*712)$fatal(1,"720p valid count %d",valid_count);
 if(edge_count!=0)$fatal(1,"uniform full frame generated edge %d",edge_count);
 $display("PASS 720p three frames: valid=%0d, uniform edges=%0d, worst CCL processing=%0d pixel clocks",valid_count,edge_count,max_processing);
 $finish;
 end
 initial begin #60000000;$fatal(1,"timeout");end
endmodule
