// Colour analysis always runs on the original RGB565 stream.
`timescale 1ns/1ps
module face_candidate_pipeline #(
 parameter WIDTH=1280,HEIGHT=720,MAX_FACES=8,CELL_SHIFT=3,
 parameter CELL_MIN=24,MIN_W=40,MIN_H=48,MAX_W=640,MAX_H=640,
 parameter MIN_AREA=1800
)(
 input clk,input rst_n,input frame_start,input de,
 input [10:0] x,input [9:0] y,input [15:0] rgb565,
 output [3:0] face_count,output [MAX_FACES*42-1:0] boxes,
 output busy,output overrun
);
 wire skin,sv;wire [10:0] sx;wire [9:0] sy;
 rgb565_to_ycbcr_skin u_skin(
 .clk(clk),.rst_n(rst_n),.de_i(de),.x_i(x),.y_i(y),.rgb565_i(rgb565),
 .cb_min_i(8'd77),.cb_max_i(8'd127),.cr_min_i(8'd133),.cr_max_i(8'd173),
 .y_min_i(8'd40),.y_max_i(8'd235),.skin_o(skin),.de_o(sv),.x_o(sx),.y_o(sy));
 face_grid_regions #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES),
 .CELL_SHIFT(CELL_SHIFT),.CELL_MIN(CELL_MIN),.MIN_W(MIN_W),.MIN_H(MIN_H),
 .MAX_W(MAX_W),.MAX_H(MAX_H),.MIN_AREA(MIN_AREA)) u_regions(
 .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.skin_valid(sv),.skin(skin),
 .x(sx),.y(sy),.face_count(face_count),.boxes(boxes),.busy(busy),.overrun(overrun));
endmodule
