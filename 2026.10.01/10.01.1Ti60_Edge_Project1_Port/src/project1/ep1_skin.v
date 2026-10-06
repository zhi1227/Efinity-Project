// RGB skin segmentation: senior project's R-G rule, with brightness/blue guards.
module ep1_skin #(parameter UPPER=90,Y_MIN=32,Y_MAX=240)(
 input clk,rst_n,de,fs,input[10:0]x,input[9:0]y,input[23:0]rgb,
 input[7:0]lower,output reg mask,valid,frame_start,output reg[10:0]xo,output reg[9:0]yo);
 reg[15:0]luma;reg[7:0]diff,lo;reg red_blue,d,f;reg[10:0]xx;reg[9:0]yy;
 always @(posedge clk)begin
  if(!rst_n)begin luma<=0;diff<=0;lo<=10;red_blue<=0;d<=0;f<=0;xx<=0;yy<=0;mask<=0;valid<=0;frame_start<=0;xo<=0;yo<=0;end
  else begin
   luma<=rgb[23:16]*16'd77+rgb[15:8]*16'd150+rgb[7:0]*16'd29;
   diff<=rgb[23:16]>rgb[15:8]?rgb[23:16]-rgb[15:8]:8'd0;
   red_blue<=rgb[23:16]>rgb[7:0];lo<=lower;d<=de;f<=fs;xx<=x;yy<=y;
   mask<=d&&diff>lo&&diff<UPPER&&red_blue&&luma[15:8]>=Y_MIN&&luma[15:8]<=Y_MAX;
   valid<=d;frame_start<=f;xo<=xx;yo<=yy;
  end
 end
endmodule

// Seven rows, synchronous read BRAM; coordinate/valid latency equals the 3x3 window.
module ep1_window7 #(parameter WIDTH=1280)(
 input clk,rst_n,frame_start,de_i,input[10:0]x_i,input[9:0]y_i,input bit_i,
 output[48:0]window_o,output reg valid,output reg[10:0]xo,output reg[9:0]yo);
 reg bin_d,de_d;reg[10:0]xd;reg[9:0]yd;
 wire[5:0]rd;reg[6:0]sr[0:6];
 genvar g;
 generate for(g=0;g<6;g=g+1)begin:lines
  (* ram_style="block" *) reg mem[0:WIDTH-1];reg q;
  always @(posedge clk)begin
   if(de_d)mem[xd]<=g==0?bin_d:rd[g-1];
   q<=mem[x_i];
  end
  assign rd[g]=q;
 end endgenerate
 reg previous_valid,de_q;reg[9:0]previous_y;reg[2:0]samples,rows;
 wire new_line=de_d&&(!previous_valid||previous_y!=yd);
 integer i;
 generate for(g=0;g<7;g=g+1)begin:pack
  assign window_o[g*7+:7]=sr[g];
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)begin
   bin_d<=0;de_d<=0;xd<=0;yd<=0;previous_valid<=0;previous_y<=0;de_q<=0;samples<=0;rows<=0;valid<=0;xo<=0;yo<=0;
   for(i=0;i<7;i=i+1)sr[i]<=0;
  end else begin
   de_d<=de_i;de_q<=de_i;if(de_i)begin bin_d<=bit_i;xd<=x_i;yd<=y_i;end
   previous_valid<=de_d;
   if(frame_start)begin rows<=0;samples<=0;previous_valid<=0;end
   else begin
    if(de_q&&!de_i&&rows<6)rows<=rows+1'b1;
    if(de_d)begin previous_y<=yd;if(new_line)samples<=1;else if(samples<6)samples<=samples+1'b1;end
   end
   if(de_d)for(i=0;i<7;i=i+1)begin
    if(new_line)sr[i]<={6'd0,i==0?bin_d:rd[i-1]};
    else sr[i]<={sr[i][5:0],i==0?bin_d:rd[i-1]};
   end
   valid<=de_d&&samples==6&&rows==6&&!new_line&&!frame_start;
   xo<=xd-11'd3;yo<=yd-10'd3;
  end
 end
endmodule

module ep1_disk #(parameter THRESH=15)(input clk,rst_n,valid_i,input[10:0]x,input[9:0]y,
 input[48:0]w,output reg bit_o,valid_o,output reg[10:0]xo,output reg[9:0]yo);
 reg[5:0]sum;reg v;reg[10:0]xx;reg[9:0]yy;integer row,col;reg[5:0]count;
 always @*begin
  count=0;
  for(row=0;row<7;row=row+1)for(col=0;col<7;col=col+1)
   if((row-3)*(row-3)+(col-3)*(col-3)<=9)count=count+{5'd0,w[row*7+col]};
 end
 always @(posedge clk)begin
  if(!rst_n)begin sum<=0;v<=0;xx<=0;yy<=0;bit_o<=0;valid_o<=0;xo<=0;yo<=0;end
  else begin sum<=count;v<=valid_i;xx<=x;yy<=y;bit_o<=sum>=THRESH;valid_o<=v;xo<=xx;yo<=yy;end
 end
endmodule
