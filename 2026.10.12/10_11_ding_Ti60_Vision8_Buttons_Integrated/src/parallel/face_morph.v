// Full-raster binary cleanup; spatial coordinate is explicit, never inferred from DE.
module face_morph #(parameter WIDTH=1280)(
 input clk,rst_n,frame_start,input de,input [10:0] x,input [9:0] y,input skin,
 output reg binary_o,output reg valid_o,output reg [10:0] x_o,output reg [9:0] y_o);
 wire [8:0] w1,w2;wire v1,v2;wire [10:0] x1,x2;wire [9:0] y1,y2;
 reg m,mv;reg [10:0] mx;reg [9:0] my;
 wire [3:0] sum={3'b0,w1[0]}+w1[1]+w1[2]+w1[3]+w1[4]+w1[5]+w1[6]+w1[7]+w1[8];
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) a(clk,rst_n,frame_start,de,x,y,skin,w1,v1,x1,y1);
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin m<=0;mv<=0;mx<=0;my<=0;end
 else begin m<=sum>=5;mv<=v1;mx<=x1;my<=y1;end
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(1)) b(clk,rst_n,frame_start,mv,mx,my,m,w2,v2,x2,y2);
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin binary_o<=0;valid_o<=0;x_o<=0;y_o<=0;end
 else begin binary_o<=&w2;valid_o<=v2;x_o<=x2;y_o<=y2;end
endmodule
