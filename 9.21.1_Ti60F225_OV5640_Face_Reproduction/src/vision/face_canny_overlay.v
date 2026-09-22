// DISPLAY_MODE: 0=colour + cyan contours inside candidates; 1=Canny B/W.
// Red rectangles are face-candidate bounding boxes in both modes.
`timescale 1ns/1ps
module face_canny_overlay #(parameter MAX_FACES=8,DISPLAY_MODE=1,THICKNESS=2)(
 input clk,input rst_n,input [23:0] rgb,
 input de,input vs,input hs,input [10:0] x,input [9:0] y,input edge_pixel,
 input [3:0] face_count,input [MAX_FACES*42-1:0] boxes,
 output reg [23:0] rgb_o,output reg de_o,output reg vs_o,output reg hs_o
);
 reg vs_q;reg [3:0] count_q;reg [MAX_FACES*42-1:0] boxes_q;
 reg border,inside;
 reg [10:0] x0,x1;reg [9:0] y0,y1;
 integer i;
 always @* begin
   border=0;inside=0;x0=0;x1=0;y0=0;y1=0;
   for(i=0;i<MAX_FACES;i=i+1) begin
     x0=boxes_q[i*42+:11];x1=boxes_q[i*42+11+:11];
     y0=boxes_q[i*42+22+:10];y1=boxes_q[i*42+32+:10];
     if(i<count_q && x>=x0 && x<=x1 && y>=y0 && y<=y1) begin
       inside=1;
       if((x-x0<THICKNESS)||(x1-x<THICKNESS)||
          (y-y0<THICKNESS)||(y1-y<THICKNESS)) border=1;
     end
   end
 end
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     vs_q<=1;count_q<=0;boxes_q<=0;rgb_o<=0;de_o<=0;vs_o<=1;hs_o<=1;
   end else begin
     vs_q<=vs;
     if(vs && !vs_q) begin count_q<=face_count;boxes_q<=boxes;end
     de_o<=de;vs_o<=vs;hs_o<=hs;
     if(!de) rgb_o<=0;
     else if(border) rgb_o<=24'hff3030;
     else if(DISPLAY_MODE==0)
       rgb_o<=(inside && edge_pixel)?24'h00ffff:rgb;
     else rgb_o<=edge_pixel?24'hffffff:24'h000000;
   end
 end
endmodule
