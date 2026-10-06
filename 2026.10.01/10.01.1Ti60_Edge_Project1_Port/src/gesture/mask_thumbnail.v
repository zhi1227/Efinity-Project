// Streaming block occupancy, no full RGB frame. Grid width must be 64.
module mask_thumbnail #(parameter BLOCK=20,ROWS=36,THRESHOLD=80)(
 input clk,rst_n,frame_start,de,mask,input available,
 output reg we,output reg [11:0] addr,output reg bit_out,output reg start,
 output reg capturing);
 reg [4:0] sub_x,sub_y;
 reg [5:0] cell_x,cell_y;
 reg [4:0] horizontal_sum;
 reg [8:0] row_sum[0:63];
 wire [5:0] row_total={1'b0,horizontal_sum}+mask;
 wire [9:0] tile_total=(sub_y==0)?row_total:({1'b0,row_sum[cell_x]}+row_total);
 reg pending;
 always @(posedge clk) begin
 if(!rst_n)begin
   sub_x<=0;sub_y<=0;cell_x<=0;cell_y<=0;horizontal_sum<=0;
   we<=0;start<=0;pending<=0;addr<=0;bit_out<=0;capturing<=0;
 end else begin
   we<=0;start<=pending;pending<=0;
   if(frame_start)begin
     sub_x<=0;sub_y<=0;cell_x<=0;cell_y<=0;horizontal_sum<=0;
     capturing<=available&&!pending&&!start;
   end else if(de && capturing)begin
     if(sub_x==BLOCK-1)begin
       sub_x<=0;horizontal_sum<=0;
       row_sum[cell_x]<=tile_total[8:0];
       if(sub_y==BLOCK-1)begin
         we<=1;addr<={cell_y,cell_x};bit_out<=tile_total>=THRESHOLD;
       end
       if(cell_x==63)begin
         cell_x<=0;
         if(sub_y==BLOCK-1)begin
           sub_y<=0;
           if(cell_y==ROWS-1)begin capturing<=0;pending<=1;end
           else cell_y<=cell_y+1'b1;
         end else sub_y<=sub_y+1'b1;
       end else cell_x<=cell_x+1'b1;
     end else begin sub_x<=sub_x+1'b1;horizontal_sum<=row_total[4:0];end
   end
 end
 end
endmodule
