// 1024x600 streaming menu. No framebuffer or DDR traffic.
// Coordinates, RGB and DE have the same two-clock pipeline latency.
module menu_renderer (
 input clk,reset,input [10:0] x,input [9:0] y,input visible,
 input [3:0] mode,input held,ready,input[7:0]health,
 output reg [23:0] rgb,output reg de
);
 reg [2:0] selected;
 always @* case(mode)
   0:selected=0;1:selected=1;10:selected=2;9:selected=3;
   14:selected=4;15:selected=5;default:selected=0;
 endcase
 function [23:0] accent;
 input [2:0] n;
 begin case(n)
   0:accent=24'h58D8E8;1:accent=24'h82B5FF;2:accent=24'hB8A0FF;
   3:accent=24'h65DBAB;4:accent=24'hFFAD72;default:accent=24'hFA93C3;
 endcase end
 endfunction
 reg [2:0] tile;
 reg [10:0] lx;
 always @* begin
   if(x>=828) begin tile=5;lx=x-828;end
   else if(x>=672) begin tile=4;lx=x-672;end
   else if(x>=516) begin tile=3;lx=x-516;end
   else if(x>=360) begin tile=2;lx=x-360;end
   else if(x>=204) begin tile=1;lx=x-204;end
   else begin tile=0;lx=x-48;end
 end
 wire tile_area=x>=48 && x<976 && lx<144 && y>=128 && y<272;
 wire tile_selected=(tile==selected);
 wire round_inside=(lx>=10 && lx<134)||(y>=138 && y<262);
 wire outer_edge=(lx<3||lx>=141||y<131||y>=269);
 wire [7:0] ix=lx[7:0];
 wire [7:0] iy=y-10'd160;
 // Shared 64-pixel symbol coordinates. Combinational arithmetic stays local.
 wire signed [8:0] cx=$signed({1'b0,ix})-9'sd72;
 wire signed [8:0] cy=$signed({1'b0,iy})-9'sd36;
 wire [17:0] radius2=cx*cx+cy*cy;
 wire ring=radius2>=625 && radius2<=784;
 wire head=radius2>=196 && radius2<=289 && iy<53;
 wire bracket=(ix>=31 && ix<=113 && (iy==0||iy==1||iy==70||iy==71) && (ix<49||ix>95)) ||
              ((ix==31||ix==32||ix==112||ix==113) && ((iy<18)||(iy>=54 && iy<72)));
 wire rect=(ix>=75 && ix<=119 && iy>=26 && iy<=67) && (ix<78||ix>116||iy<29||iy>64);
 wire signed [8:0] sx=$signed({1'b0,ix})-9'sd49;
 wire signed [8:0] sy=$signed({1'b0,iy})-9'sd29;
 wire [17:0] sr=sx*sx+sy*sy;
 wire small_ring=sr>=324 && sr<=441;
 reg icon_on;reg [23:0] icon_color;
 always @* begin
   icon_on=0;icon_color=accent(tile);
   case(tile)
     0:begin
       icon_on=iy>=12 && iy<64 && ix>=32 && ix<112;
       if(ix<58) icon_color=24'hFA8F9E;
       else if(ix<85) icon_color=24'h64DDB4;else icon_color=24'h79B8FF;
     end
     1:icon_on=ring || (ix>=44 && ix<=100 && (iy==70||iy==71));
     2:begin icon_on=ring||bracket;icon_color=24'hFF786C;end
     4:begin
       if(ix>=32 && ix<112 && iy>=8 && iy<66) begin
         if(ix<70) begin icon_on=1;icon_color=ix[4]?24'h64DDB4:24'h79B8FF;end
         else icon_on=(ix<74 || iy<11 || iy>=63 || ix>=109 || iy==ix-56);
       end
     end
     3:begin
       if(ix>=35 && ix<=109 && iy>=0 && iy<=73) begin
         icon_on=1;icon_color=24'h34505C;
         if(ring) icon_color=iy[4]?24'hFF40E0:24'h00FFFF;
         else if(ix>=43 && ix<50 && iy>=8 && iy<65) icon_color=24'h80B9AC;
       end
     end
     5:icon_on=head || (iy>=55 && iy<60 && ix>=52 && ix<=92) || (ix>=105 && ix<110 && iy>=8 && iy<55);
   endcase
 end
 // Text rows are composed from a compact shared Chinese/ASCII glyph ROM.
 reg [4:0] text_line;
 reg [5:0] text_index;
 reg [3:0] font_row,font_col;
 reg text_valid;
 reg [23:0] text_color,background;
 reg [10:0] dx;
 reg [9:0] dy;
 reg [7:0] br,bg,bb;
 always @* begin
   br=8'd9+{4'd0,y[9:6]}; bg=8'd18+{3'd0,y[9:5]}; bb=8'd36+{3'd0,y[9:5]};
   background={br,bg,bb};
   if(y==96 && x>=48 && x<976) background=24'h2C405C;
   if(y==532 && x>=48 && x<976) background=24'h34445C;
   if(tile_area && round_inside) begin
     background=tile_selected?24'h294263:24'h17283E;
     if(tile_selected && outer_edge) background=accent(tile);
     if(iy<80 && icon_on) background=icon_color;
   end
   if(y>=313 && y<316 && lx<144 && x>=48 && x<976 && tile_selected)
     background=accent(selected);
   // Eight diagnostic lights; labels are rendered from the font below.
   if(y>=507&&y<514&&x>=56&&x<824&&((x-56)%96)<80)
     background=health[(x-56)/96]?24'h35D499:24'hF06A70;
   // Status badge at top right.
   if(x>=840 && x<976 && y>=36 && y<72) background=held?24'h5C4328:24'h1B4B49;
   // Compact, decorative six-step progress indicator.
   if(y>=478 && y<483 && x>=56 && x<344 && ((x-56)%48)<36)
     background=accent(selected);
   text_valid=0;text_line=0;text_index=0;font_row=0;font_col=0;
   text_color=24'hECF4FF;dx=0;dy=0;
   if(y>=38 && y<70 && x>=48 && x<688) begin
     text_line=0;dx=x-48;dy=y-38;text_valid=1;
     text_index=dx[10:5];font_col=dx[4:1];font_row=dy[4:1];
   end else if(y>=46 && y<62 && x>=864 && x<960) begin
     text_line=ready?(held?2:1):3;dx=x-864;dy=y-46;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];
   end else if(y>=287 && y<303 && x>=48 && x<976 && lx<144) begin
     text_line=4+tile;dx=lx;dy=y-287;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];
     text_color=tile_selected?24'hFFFFFF:24'hA3B5CD;
   end else if(y>=356 && y<388 && x>=56 && x<952) begin
     text_line=10+selected;dx=x-56;dy=y-356;text_valid=1;
     text_index=dx[10:5];font_col=dx[4:1];font_row=dy[4:1];
   end else if(y>=411 && y<427 && x>=58 && x<954) begin
     text_line=16+selected;dx=x-58;dy=y-411;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];text_color=24'hAFC3DC;
   end else if(y>=448 && y<464 && x>=58 && x<954) begin
     text_line=22+selected;dx=x-58;dy=y-448;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];text_color=accent(selected);
   end else if(y>=488&&y<504&&x>=56&&x<824)begin
     text_line=29;dx=x-56;dy=y-488;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];text_color=24'hB8C9DE;
   end else if(y>=554 && y<570 && x>=56 && x<952) begin
     text_line=28;dx=x-56;dy=y-554;text_valid=1;
     text_index=dx[9:4];font_col=dx[3:0];font_row=dy[3:0];text_color=24'hB8C9DE;
   end
 end
 wire [15:0] glyph_bits;
 menu_glyph_rom glyph(.clk(clk),.line_id(text_line),.char_index(text_index),
   .row(font_row),.bits(glyph_bits));
 reg [3:0] col_q;
 reg text_q,visible_q;
 reg [23:0] bg_q,fg_q;
 always @(posedge clk) begin
   if(reset) begin rgb<=0;de<=0;col_q<=0;text_q<=0;visible_q<=0;bg_q<=0;fg_q<=0;end
   else begin
     col_q<=font_col;text_q<=text_valid;visible_q<=visible;
     bg_q<=background;fg_q<=text_color;
     de<=visible_q;
     rgb<=visible_q ? ((text_q && glyph_bits[15-col_q])?fg_q:bg_q):24'd0;
   end
 end
endmodule
