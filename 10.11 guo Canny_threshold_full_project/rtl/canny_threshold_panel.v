// Shared bottom-right LCD/HDMI panel. One registered stage; the caller's
// existing output register supplies stage two, preserving video timing.
module canny_threshold_panel #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,reset,input[10:0]x,input[9:0]y,input enabled,editing,select_high,
 input[11:0]low,high,output area,output[23:0]rgb_q);
 localparam X0=WIDTH-400;
 wire [9:0] y0=editing?HEIGHT-144:HEIGHT-80;
 wire [10:0] px=x-X0;
 wire [9:0] py=y-y0;
 assign area=enabled&&(WIDTH>=400)&&(HEIGHT>=144)&&x>=X0&&x<WIDTH-16&&y>=y0&&y<HEIGHT-16;
 function [15:0] decimal4;
 input [11:0] value;
 reg [27:0] shift;
 integer i,j;
 begin
  shift={16'd0,value};
  for(i=0;i<12;i=i+1)begin
   for(j=0;j<4;j=j+1)
    if(shift[12+j*4+:4]>=5)shift[12+j*4+:4]=shift[12+j*4+:4]+4'd3;
   shift=shift<<1;
  end
  decimal4=shift[27:12];
 end
 endfunction
 reg[15:0]low_bcd,high_bcd;
 always @(posedge clk)begin
  if(reset)begin low_bcd<=16'h0040;high_bcd<=16'h0080;end
  else begin low_bcd<=decimal4(low);high_bcd<=decimal4(high);end
 end
 reg[2:0]line_id;
 reg[9:0]ty;
 wire[10:0]tx=px-16;
 wire[4:0]ci=tx[8:4];
 reg text_valid;
 reg[23:0]bg,fg;
 always @*begin
  bg=24'h101F34;fg=24'hCEDDEE;
  line_id=0;ty=0;text_valid=0;
  if(px<2||px>=382||py<2||y>=HEIGHT-18)bg=editing?24'h58D8E8:24'h344D69;
  if(py>=12&&py<28)begin line_id=editing?0:5;ty=py-12;text_valid=1;fg=24'h58D8E8;end
  else if(py>=36&&py<52)begin
   line_id=1;ty=py-36;text_valid=1;fg=24'hECF4FF;
   if(editing&&((!select_high&&ci<=7)||(select_high&&ci>=9&&ci<=16)))begin
    bg=24'h3D3440;fg=24'hFFD177;
   end
  end else if(editing&&py>=60&&py<76)begin line_id=2;ty=py-60;text_valid=1;end
  else if(editing&&py>=80&&py<96)begin line_id=3;ty=py-80;text_valid=1;end
  else if(editing&&py>=100&&py<116)begin line_id=4;ty=py-100;text_valid=1;end
  text_valid=text_valid&&px>=16&&px<368;
 end
 wire[15:0]bits;
 canny_ui_glyph_rom font(clk,line_id,ci,ty[3:0],low_bcd,high_bcd,bits);
 reg[3:0]col_q;reg text_q;reg[23:0]bg_q,fg_q;
 always @(posedge clk)begin
  if(reset)begin col_q<=0;text_q<=0;bg_q<=0;fg_q<=0;end
  else begin col_q<=tx[3:0];text_q<=text_valid;bg_q<=bg;fg_q<=fg;end
 end
 assign rgb_q=(text_q&&bits[15-col_q])?fg_q:bg_q;
endmodule
