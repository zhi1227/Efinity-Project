// Public video pipeline: use the verified post-DDR RGB888 + LCD DE/HS/VS.
// No raw DDR request/data phase guessing. All geometry is from DE counting.
`timescale 1ns/1ps
module face_canny_video #(
 parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,DISPLAY_MODE=1,
 parameter TH_LOW=24,TH_HIGH=64,MAX_FACES=8
)(
 input clk,input rst_n,input [23:0] rgb_i,input de_i,input vs_i,input hs_i,
 output [23:0] rgb_o,output de_o,output vs_o,output hs_o,
 output [3:0] face_count,output face_overrun
);
 reg [10:0] x;reg [9:0] y;reg vs_q;
 wire frame_start=vs_i && !vs_q;
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin x<=0;y<=0;vs_q<=1;end
   else begin
     vs_q<=vs_i;
     if(!vs_i) begin x<=0;y<=0;end
     else if(de_i) begin
       if(x==WIDTH-1) begin x<=0;y<=y+1'b1;end
       else x<=x+1'b1;
     end
   end
 end
 wire [15:0] rgb565={rgb_i[23:19],rgb_i[15:10],rgb_i[7:3]};
 wire [MAX_FACES*42-1:0] boxes,raw_boxes;
 wire [3:0] raw_count;
 reg [1:0] frame_pipe;
 always @(posedge clk or negedge rst_n)
   if(!rst_n) frame_pipe<=0; else frame_pipe<={frame_pipe[0],frame_start};
 face_box_stabilizer #(.MAX_FACES(MAX_FACES)) u_stabilizer(
 .clk(clk),.rst_n(rst_n),.update(frame_pipe[1]),
 .count_i(raw_count),.boxes_i(raw_boxes),.count_o(face_count),.boxes_o(boxes));
 wire face_busy;
 face_candidate_pipeline #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES)) u_faces(
 .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.de(de_i),
 .x(x),.y(y),.rgb565(rgb565),.face_count(raw_count),.boxes(raw_boxes),
 .busy(face_busy),.overrun(face_overrun));
 wire ce,cv;wire [10:0] ex;wire [9:0] ey;
 canny_stream #(.WIDTH(WIDTH),.TH_LOW(TH_LOW),.TH_HIGH(TH_HIGH)) u_canny(
 .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.de_i(de_i),
 .x_i(x),.y_i(y),.rgb565_i(rgb565),.edge_o(ce),.valid_o(cv),.x_o(ex),.y_o(ey));
 // Each of four 3x3 windows consumes one row+column of look-ahead.
 localparam VIDEO_DELAY=4*(H_TOTAL+1)+14;
 wire [47:0] aligned;
 video_delay #(.BITS(48),.LATENCY(VIDEO_DELAY)) u_align(
 .clk(clk),.rst_n(rst_n),.din({vs_i,hs_i,de_i,y,x,rgb_i}),.dout(aligned));
 wire avs=aligned[47],ahs=aligned[46],ade=aligned[45];
 wire [9:0] ay=aligned[44:35];wire [10:0] ax=aligned[34:24];
 // Invalid borders are BLACK; never reuse the previous edge when valid=0.
 wire aligned_edge=ce && cv && ade && (ex==ax) && (ey==ay);
 face_canny_overlay #(.MAX_FACES(MAX_FACES),.DISPLAY_MODE(DISPLAY_MODE)) u_overlay(
 .clk(clk),.rst_n(rst_n),.rgb(aligned[23:0]),.de(ade),.vs(avs),.hs(ahs),
 .x(ax),.y(ay),.edge_pixel(aligned_edge),.face_count(face_count),.boxes(boxes),
 .rgb_o(rgb_o),.de_o(de_o),.vs_o(vs_o),.hs_o(hs_o));
endmodule
