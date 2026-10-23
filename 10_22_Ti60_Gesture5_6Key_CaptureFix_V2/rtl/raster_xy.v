// Reconstruct coordinates from the delayed FULL raster (never cropped edge DE).
module raster_xy #(parameter WIDTH=1280)(input clk,rst_n,vs,de,
 output reg[10:0]x,output reg[9:0]y);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;end
 else if(!vs)begin x<=0;y<=0;end
 else if(de)begin
   if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
 end
endmodule
