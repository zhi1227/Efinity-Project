`timescale 1ns/1ps
module tb_720p;
 reg clk=0;always #5 clk=~clk;reg rst=0,de=0,vs=0,hs=1;reg[23:0]rgb=0;
 wire[23:0]q;wire od,ov,oh,overrun;
 integer x,y,f,n,edge_count,valid_count,processing,max_processing=0;
 reg[3:0]mode=5;
 parallel_video #(.CANNY_GAUSSIAN(1)) dut(clk,rst,rgb,de,vs,hs,mode,12'd40,12'd80,q,od,ov,oh,overrun,1'b0);
 localparam D=4*(1650+1)+14;
 reg[26:0] raster_reference[0:D-1];reg[26:0] expected_output;
 reg[23:0] expected_input;integer rp=0,rf=0,ri,display_pixels=0;
 // Circular scoreboard avoids shifting 6618 entries on every simulated clock.
 always @(posedge clk)begin
 if(!rst)begin rp=0;rf=0;for(ri=0;ri<D;ri=ri+1)raster_reference[ri]=0;end
 else begin
 expected_input=0;
 if(de)begin
 if(f==0 && x==640)expected_input=24'h00ffff;
 else if(f==1)expected_input=24'hffffff;
 end
 expected_output=raster_reference[rp];
 raster_reference[rp]={vs,hs,de,expected_input};rp=(rp==D-1)?0:rp+1;
 if(rf<D+1)rf=rf+1;
 #1;
 if(rf>D && {ov,oh,od,q}!==expected_output)$fatal(1,"720p stage1 full-raster display mismatch");
 if(od)display_pixels=display_pixels+1;
 end
 end
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
 mode=5+f;
 vs=0;de=0;repeat(1650*5)@(negedge clk);vs=1;repeat(1650*20)@(negedge clk);
 for(y=0;y<720;y=y+1)for(x=0;x<1650;x=x+1)begin
 de=x<1280;hs=x>=1320;rgb=(f==1)?24'hce9e7b:0;@(negedge clk);
 end
 de=0;rgb=0;repeat(1650*5)@(negedge clk);
 end
 repeat(600000)@(negedge clk);
 if(valid_count!=3*1272*712)$fatal(1,"720p valid count %d",valid_count);
 if(edge_count!=0)$fatal(1,"uniform full frame generated edge %d",edge_count);
 if(display_pixels!=3*1280*720)$fatal(1,"720p display pixel count %d",display_pixels);
 $display("PASS 720p modes 5/6/7 exact RGB/DE/HS/VS: %0d display pixels",display_pixels);
 $display("PASS 720p three frames: valid=%0d, uniform edges=%0d, worst CCL processing=%0d pixel clocks",valid_count,edge_count,max_processing);
 $finish;
 end
 initial begin #60000000;$fatal(1,"timeout");end
endmodule
