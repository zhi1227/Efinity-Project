// A normalized 16x16 silhouette from the previous complete candidate box.
// Only 256 sample bits are stored, not an image. CCL association validates it.
module gesture_sample16(
 input clk,rst_n,enable,fs,de,skin,input[10:0]x,input[9:0]y,
 input box_valid,input[41:0]box,
 output reg valid,output reg[41:0]sample_box,output reg[255:0]bitmap);
 reg active,pending;reg[41:0]ref_box;reg[255:0]working;reg[8:0]samples;
 reg[3:0]col,row;
 wire[10:0]bw=ref_box[21:11]-ref_box[10:0]+1;
 wire[9:0]bh=ref_box[41:32]-ref_box[31:22]+1;
 wire[16:0]xp=({1'b0,col,1'b1})*bw;
 wire[15:0]yp=({1'b0,row,1'b1})*bh;
 wire[10:0]tx=ref_box[10:0]+(xp>>5);
 wire[9:0]ty=ref_box[31:22]+(yp>>5);
 always @(posedge clk)begin
  if(!rst_n||!enable)begin active<=0;pending<=0;ref_box<=0;working<=0;samples<=0;col<=0;row<=0;valid<=0;sample_box<=0;bitmap<=0;end
  else if(fs)begin
   valid<=active&&samples==256;sample_box<=ref_box;bitmap<=working;
   active<=0;pending<=1;working<=0;samples<=0;col<=0;row<=0;
  end else if(pending)begin active<=box_valid;ref_box<=box;pending<=0;end
  else if(active&&de&&samples<256&&x==tx&&y==ty)begin
   working[{row,col}]<=skin;samples<=samples+1'b1;
   if(col==15)begin col<=0;row<=row+1'b1;end else col<=col+1'b1;
  end
 end
endmodule
