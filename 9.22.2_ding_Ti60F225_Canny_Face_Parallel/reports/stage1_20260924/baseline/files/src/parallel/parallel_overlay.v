module parallel_overlay #(parameter MAX_FACES=8, THICKNESS=2)(
 input clk,rst_n,input [2:0] mode,input [23:0] rgb,input de,vs,hs,
 input [10:0] x,input [9:0] y,input edge_pixel,
 input [3:0] count,input [MAX_FACES*42-1:0] boxes,
 output reg [23:0] rgb_o,output reg de_o,vs_o,hs_o);
 integer i;reg inside_box,border;reg [10:0] x0,x1;reg [9:0] y0,y1;reg [23:0] colour;
 always @* begin
 inside_box=0;border=0;x0=0;x1=0;y0=0;y1=0;
 for(i=0;i<MAX_FACES;i=i+1) begin
 x0=boxes[i*42+:11];x1=boxes[i*42+11+:11];y0=boxes[i*42+22+:10];y1=boxes[i*42+32+:10];
 if(i<count && x>=x0 && x<=x1 && y>=y0 && y<=y1) begin
 inside_box=1;
 if(x-x0<THICKNESS || x1-x<THICKNESS || y-y0<THICKNESS || y1-y<THICKNESS) border=1;
 end
 end
 case(mode)
 0:colour=rgb;
 1:colour=edge_pixel?24'hffffff:0;
 2:colour=border?24'hff0000:(edge_pixel?(inside_box?24'hffff00:24'h00ff00):rgb);
 3:colour=border?24'hff0000:(edge_pixel?24'hffffff:0);
 4:colour=border?24'hff0000:(edge_pixel?(inside_box?24'hffff00:24'h303030):0);
 default:colour=rgb;
 endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de?colour:0;de_o<=de;vs_o<=vs;hs_o<=hs;end
endmodule
