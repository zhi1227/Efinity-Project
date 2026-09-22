`timescale 1ns/1ps
module tb_face_stabilizer;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,update=0;reg[3:0]n=0;reg[335:0]b=0;
 wire[3:0]q;wire[335:0]o;
 face_box_stabilizer dut(clk,rst,update,n,b,q,o);
 task tick_frame;
 begin update=1;@(negedge clk);update=0;repeat(150) @(negedge clk);end
 endtask
 initial begin
 repeat(4) @(negedge clk);rst=1;
 n=2;b[41:0]={10'd219,10'd100,11'd199,11'd100};
 b[83:42]={10'd219,10'd100,11'd499,11'd400};tick_frame;
 if(q!=2 || o!==b) $fatal(1,"initial capture");
 // Reverse detector order and move both rectangles eight pixels right.
 b[41:0]={10'd219,10'd100,11'd507,11'd408};
 b[83:42]={10'd219,10'd100,11'd207,11'd108};tick_frame;
 if(q!=2 || o[10:0]!=102 || o[52:42]!=402) $fatal(1,"association or smoothing");
 n=0;b=0;
 repeat(3) begin tick_frame;if(q!=2) $fatal(1,"short loss should hold");end
 tick_frame;if(q!=0 || o!==0) $fatal(1,"stale boxes must expire");
 n=1;b[41:0]={10'd419,10'd300,11'd899,11'd800};tick_frame;
 if(q!=1 || o[10:0]!=800) $fatal(1,"reacquisition");
 $display("PASS stabilizer: reordered candidates, independent smoothing, 3-frame hold, expiry, reacquisition");
 $finish;
 end
endmodule
