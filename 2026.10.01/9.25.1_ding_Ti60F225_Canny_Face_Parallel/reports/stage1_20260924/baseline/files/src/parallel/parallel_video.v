// Both branches consume EXACTLY the same registered DDR display stream.
module parallel_video #(parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,MAX_FACES=8)(
 input clk,rst_n,input [23:0] rgb_i,input de_i,vs_i,hs_i,
 input [2:0] mode_i,input [11:0] low_i,high_i,
 output [23:0] rgb_o,output de_o,vs_o,hs_o,output overrun);
 reg [10:0] x;reg [9:0] y;reg vs_q;
 wire fs=vs_i && !vs_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin x<=0;y<=0;vs_q<=1;end
 else begin
 vs_q<=vs_i;
 if(!vs_i) begin x<=0;y<=0;end
 else if(de_i) begin if(x==WIDTH-1) begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
 end
 wire [15:0] rgb565={rgb_i[23:19],rgb_i[15:10],rgb_i[7:3]};
 reg [11:0] low_active,high_active;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin low_active<=40;high_active<=80;end
 else if(fs) begin low_active<=low_i;high_active<=high_i;end
 wire ce,cv;wire [10:0] ex;wire [9:0] ey;
 canny_stream #(.WIDTH(WIDTH)) u_canny(clk,rst_n,fs,low_active,high_active,de_i,x,y,rgb565,ce,cv,ex,ey);
 // 4 centered windows = 4 rows+4 columns spatial lookahead; 14 registers.
 localparam DELAY=4*(H_TOTAL+1)+14;
 wire [39:0] aligned;
 video_delay #(.BITS(40),.LATENCY(DELAY)) u_video_delay(
 clk,rst_n,{vs_i,hs_i,de_i,y,x,rgb565},aligned);
 wire avs=aligned[39],ahs=aligned[38],ade=aligned[37];
 wire [9:0] ay=aligned[36:27];wire [10:0] ax=aligned[26:16];
 wire [23:0] argb;
 rgb565_to_rgb888 expand(aligned[15:0],argb);
 wire aligned_edge=ce && cv && ade && ex==ax && ey==ay;
 wire skin,sv;wire [10:0] sx;wire [9:0] sy;
 rgb565_to_ycbcr_skin u_skin(clk,rst_n,de_i,x,y,rgb565,8'd77,8'd127,8'd133,8'd173,8'd40,8'd235,skin,sv,sx,sy);
 wire mb,mv;wire [10:0] mx;wire [9:0] my;
 face_morph #(.WIDTH(WIDTH)) u_morph(clk,rst_n,fs,sv,sx,sy,skin,mb,mv,mx,my);
 // Reconstruct full 1280x720 mask (zero at two-pixel borders).
 wire [23:0] mask_raster;
 video_delay #(.BITS(24),.LATENCY(2*(H_TOTAL+1)+7)) u_mask_delay(
 clk,rst_n,{vs_i,hs_i,de_i,y,x},mask_raster);
 wire md=mask_raster[21];wire [9:0] mya=mask_raster[20:11];wire [10:0] mxa=mask_raster[10:0];
 wire clean_skin=mv && mb && mx==mxa && my==mya;
 wire [3:0] count;wire [MAX_FACES*42-1:0] boxes;wire busy;
 reg avs_q;wire display_fs=avs&&!avs_q;
 reg [2:0] mode_active;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin avs_q<=1;mode_active<=3;end
 else begin avs_q<=avs;if(display_fs) mode_active<=mode_i;end
 face_grid_regions #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_FACES(MAX_FACES)) u_regions(
 clk,rst_n,display_fs,md,clean_skin,mxa,mya,count,boxes,busy,overrun);
 parallel_overlay #(.MAX_FACES(MAX_FACES)) u_overlay(
 clk,rst_n,mode_active,argb,ade,avs,ahs,ax,ay,aligned_edge,count,boxes,rgb_o,de_o,vs_o,hs_o);
endmodule
