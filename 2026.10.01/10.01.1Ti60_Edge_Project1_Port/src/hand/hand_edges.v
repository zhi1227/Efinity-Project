// Reuses the existing verified median / line-buffer / Sobel implementations.
// No Xilinx IP. Raw RGB + sync are delayed to the same raster as Sobel.
module hand_edges #(parameter WIDTH=1280,H_TOTAL=1650)(
 input clk,rst_n,fs,de,vs,hs,input[10:0]x,input[9:0]y,input[23:0]rgb,
 output[23:0]rgb_out,output de_out,vs_out,hs_out,
 output[10:0]x_out,output[9:0]y_out,output[11:0]magnitude,output edge_valid);
 wire[15:0]gray_sum=rgb[23:16]*16'd77+rgb[15:8]*16'd150+rgb[7:0]*16'd29;
 reg[7:0]gray;reg v,fs0;reg[10:0]x0;reg[9:0]y0;
 always @(posedge clk)begin
   if(!rst_n)begin gray<=0;v<=0;fs0<=0;x0<=0;y0<=0;end
   else begin gray<=gray_sum[15:8];v<=de;fs0<=fs;x0<=x;y0<=y;end
 end
 wire[71:0]w1,w2;wire v1,vm,v2;wire[10:0]x1,xm,x2,xe;wire[9:0]y1,ym,y2,ye;wire[7:0]med;
 line_buffer_3x3 #(.WIDTH(WIDTH)) lb1(clk,rst_n,fs0,v,x0,y0,gray,w1,v1,x1,y1);
 median3x3 median(clk,rst_n,v1,x1,y1,w1,med,vm,xm,ym);
 line_buffer_3x3 #(.WIDTH(WIDTH)) lb2(clk,rst_n,fs0,vm,xm,ym,med,w2,v2,x2,y2);
 wire[1:0]unused_dir;wire ev;
 sobel3x3 sobel(clk,rst_n,v2,x2,y2,w2,magnitude,unused_dir,ev,xe,ye);
 wire[47:0]delayed;
 video_delay #(.BITS(48),.LATENCY(2*(H_TOTAL+1)+7)) align(clk,rst_n,{rgb,de,vs,hs,x,y},delayed);
 assign {rgb_out,de_out,vs_out,hs_out,x_out,y_out}=delayed;
 assign edge_valid=ev&&de_out&&xe==x_out&&ye==y_out;
endmodule
