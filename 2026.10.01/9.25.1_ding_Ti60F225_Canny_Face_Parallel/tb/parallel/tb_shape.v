`timescale 1ns/1ps
module tb_shape;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,de=0,ep=0;reg [10:0] x=0;reg [9:0] y=0;
 wire [1:0] cls;wire [41:0] box;
 edge_shape_roi #(.WIDTH(256),.HEIGHT(256),.BAND(3),.MIN_SIZE(20),.MIN_EDGES(40)) dut(clk,rst,fs,de,ep,x,y,cls,box);
 integer xx,yy,d,k;
 task tick;begin @(negedge clk);end endtask
 task frame;input integer kind;begin
 for(yy=0;yy<256;yy=yy+1)begin
 for(xx=0;xx<256;xx=xx+1)begin
 x=xx;y=yy;de=1;d=(xx-128)*(xx-128)+(yy-128)*(yy-128);
 case(kind)
 1:ep=xx>=85 && xx<=171 && yy>=94 && yy<=162 && (xx==85 || xx==171 || yy==94 || yy==162);
 2:ep=d>=39*39 && d<=40*40;
 3:ep=xx>64 && xx<192 && yy>64 && yy<192 && ((xx*17+yy*11)%7)==0;
 4:ep=xx==yy && xx>=80 && xx<=175;
 5:ep=xx>=85 && xx<=171 && yy>=94 && yy<=162 && (xx==85 || xx==171 || yy==94); // missing bottom
 default:ep=0;
 endcase
 tick;end
 de=0;ep=0;repeat(8)tick;
 end
 repeat(8)tick;fs=1;tick;fs=0;repeat(8)tick;
 end endtask
 initial begin
 repeat(5)tick;rst=1;
 frame(1);if(cls!=0)$fatal(1,"first frame classified before reference");
 frame(1);if(cls!=1)$fatal(1,"rectangle missed class=%d",cls);
 if(box!={10'd162,10'd94,11'd171,11'd85})$fatal(1,"rectangle bbox");
 frame(0);if(cls!=0 || box!=0)$fatal(1,"stale result on empty");
 frame(2);frame(2);if(cls!=2)$fatal(1,"circle missed class=%d radial=%d total=%d",cls,dut.radial,dut.total);
 frame(3);frame(3);if(cls!=0)$fatal(1,"noise classified");
 frame(4);frame(4);if(cls!=0)$fatal(1,"line classified");
 frame(5);frame(5);if(cls!=0)$fatal(1,"open rectangle classified");
 rst=0;repeat(4)tick;if(cls!=0 || box!=0)$fatal(1,"reset");
 $display("PASS ROI shape: measured rectangle/circle, startup, empty stale clear, noise/diagonal/open-rectangle rejection");$finish;
 end
 initial begin #12000000;$fatal(1,"shape timeout");end
endmodule
