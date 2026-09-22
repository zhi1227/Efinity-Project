`timescale 1ns/1ps
module tb_face_grid_regions;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,dv=0,skin=0;reg[10:0]x=0;reg[9:0]y=0;
 wire[3:0]count;wire[335:0]boxes;wire busy,overrun;
 face_grid_regions #(.WIDTH(64),.HEIGHT(48),.CELL_SHIFT(2),.CELL_MIN(8),
 .MIN_W(8),.MIN_H(8),.MAX_W(64),.MAX_H(48),.MIN_AREA(64)) dut
 (clk,rst,fs,dv,skin,x,y,count,boxes,busy,overrun);
 integer xx,yy,mode,ticks;reg[335:0]old_boxes;
 task pulse_frame;
 begin fs=1;@(negedge clk);fs=0;end
 endtask
 task send_frame;
 input integer m;
 begin
 pulse_frame;
 old_boxes=boxes;
 for(yy=0;yy<48;yy=yy+1) begin
   for(xx=0;xx<64;xx=xx+1) begin
     x=xx;y=yy;dv=1;
     case(m)
       0:skin=(xx>=8 && xx<20 && yy>=8 && yy<24) || (xx>=36 && xx<52 && yy>=20 && yy<40);
       1:skin=0;
       2:skin=1;
       3:skin=(xx>=0 && xx<8 && yy>=0 && yy<8) || (xx>=8 && xx<16 && yy>=8 && yy<16);
     endcase
     @(negedge clk);
     if(boxes!==old_boxes) $fatal(1,"box tearing inside frame");
   end
   dv=0;repeat(4) @(negedge clk);
 end
 dv=0;ticks=0;
 while(!dut.result_ready && ticks<10000) begin ticks=ticks+1;@(negedge clk);end
 if(!dut.result_ready) $fatal(1,"BFS timeout");
 $display("grid mode %0d processing wait %0d cycles",m,ticks);
 pulse_frame;
 @(negedge clk);
 if(overrun) $fatal(1,"unexpected overrun");
 end
 endtask
 task boxcheck;
 input integer idx,x0,x1,y0,y1;
 begin
 if(boxes[idx*42+:11]!==x0[10:0] || boxes[idx*42+11+:11]!==x1[10:0] ||
    boxes[idx*42+22+:10]!==y0[9:0] || boxes[idx*42+32+:10]!==y1[9:0])
 $fatal(1,"box %0d mismatch: %d,%d-%d,%d",idx,boxes[idx*42+:11],boxes[idx*42+22+:10],boxes[idx*42+11+:11],boxes[idx*42+32+:10]);
 end
 endtask
 initial begin
 repeat(4) @(negedge clk);rst=1;
 send_frame(0);if(count!=2) $fatal(1,"expected 2 got %d",count);
 boxcheck(0,8,19,8,23);boxcheck(1,36,51,20,39);
 send_frame(1);if(count!=0 || boxes!==0) $fatal(1,"stale face in empty frame");
 send_frame(2);if(count!=1) $fatal(1,"full grid count %d",count);boxcheck(0,0,63,0,47);
 send_frame(3);if(count!=1) $fatal(1,"diagonal must be 8-connected");boxcheck(0,0,15,0,15);
 $display("PASS grid: two faces, empty-frame clear, full-bank BFS, border and diagonal connectivity");
 $finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
