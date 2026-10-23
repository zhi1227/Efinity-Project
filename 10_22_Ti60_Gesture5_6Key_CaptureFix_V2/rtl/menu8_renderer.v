// 1024x600 streaming UI. Eight mode cards; edge thresholds stay inline.
// Two-clock font/pixel pipeline; all animation registers advance in blanking.
module menu8_renderer #(parameter SHARED_FONT=0)(input clk,reset,input[10:0]x,input[9:0]y,input visible,
 input[639:0]state_i,output reg[23:0]rgb,output reg de,output[12:0]shared_addr,input[15:0]shared_bits,
 input frame_tick);
 `include "vision8_modes.vh"
 wire[2:0]mode=state_i[2:0];wire held=state_i[3];
 wire edge_mode=mode>=1&&mode<=4;
 wire[11:0]threshold=state_i[48:37];
wire canny_mode=mode==1||mode==4;
 wire[1:0]selection=state_i[62:61];
 wire[11:0]high_threshold=state_i[60:49];
 wire[1:0]step=state_i[64:63];
 function [23:0] accent;
 input [2:0] n;
 begin case(n)
   0:accent=24'h58D8E8;1:accent=24'h82B5FF;2:accent=24'hFF867F;
   3:accent=24'hB8A0FF;4:accent=24'hEBD084;5:accent=24'hFA93C3;
   6:accent=24'h65DBAB;default:accent=24'hFFAD72;
 endcase end
 endfunction
 // Circular 928-pixel rail. At one mode per press, travel takes ten frames.
 // A second press retargets the moving light without snapping to a card.
 reg[9:0]flow_pos;
 wire[9:0]flow_target={7'd0,mode_to_slot(mode)}*10'd116;
 wire[10:0]distance=flow_target>=flow_pos?{1'b0,flow_target}-{1'b0,flow_pos}:11'd928+{1'b0,flow_target}-{1'b0,flow_pos};
 wire[6:0]flow_step=distance>192?7'd64:7'd12;
 wire[10:0]next_flow={1'b0,flow_pos}+flow_step;
 always @(posedge clk)begin
  if(reset)flow_pos<=0;
  else if(frame_tick)begin
   if(distance<=flow_step)flow_pos<=flow_target;
   else flow_pos<=next_flow>=928?next_flow-928:next_flow;
  end
 end
 wire[10:0]rail_x=x-11'd48;
 wire[10:0]phase=rail_x>=flow_pos?rail_x-flow_pos:rail_x+11'd928-flow_pos;
 reg [2:0] slot;wire[2:0]tile=slot_to_mode(slot);reg [10:0] lx;
 always @* begin
   if(x>=860)begin slot=7;lx=x-860;end
   else if(x>=744)begin slot=6;lx=x-744;end
   else if(x>=628)begin slot=5;lx=x-628;end
   else if(x>=512)begin slot=4;lx=x-512;end
   else if(x>=396)begin slot=3;lx=x-396;end
   else if(x>=280)begin slot=2;lx=x-280;end
   else if(x>=164)begin slot=1;lx=x-164;end
   else begin slot=0;lx=x-48;end
 end
 wire tile_area=x>=48&&x<964&&lx<104&&y>=124&&y<266;
 wire tile_selected=tile==mode;
 wire cut_inside=(lx>=8&&lx<96)||(y>=132&&y<258);
 wire outer_edge=lx<2||lx>=102||y<126||y>=264;
 wire[7:0]ix=lx[7:0]+8'd20,iy=y-10'd172;
 wire signed[8:0]cx=$signed({1'b0,ix})-9'sd72,cy=$signed({1'b0,iy})-9'sd36;
 wire[17:0]radius2=cx*cx+cy*cy;
 wire ring=radius2>=625&&radius2<=784;
 wire head=radius2>=196&&radius2<=289&&iy<53;
 wire bracket=(ix>=31&&ix<=113&&(iy==0||iy==1||iy==70||iy==71)&&(ix<49||ix>95))||
              ((ix==31||ix==32||ix==112||ix==113)&&((iy<18)||(iy>=54&&iy<72)));
 reg icon_on;reg[23:0]icon_color;
 always @*begin
  icon_on=0;icon_color=accent(tile);
  case(tile)
   0:begin icon_on=iy>=12&&iy<64&&ix>=32&&ix<112;
    if(ix<58)icon_color=24'hFA8F9E;else if(ix<85)icon_color=24'h64DDB4;else icon_color=24'h79B8FF;
   end
   1:icon_on=ring||(ix>=44&&ix<=100&&(iy==70||iy==71));
   2:icon_on=ring||bracket;
   3:begin
    if(ix>=35&&ix<=109&&iy<=73)begin icon_on=1;icon_color=24'h34505C;
     if(ring)icon_color=iy[4]?24'hFF40E0:24'h00FFFF;
     else if(ix>=43&&ix<50&&iy>=8&&iy<65)icon_color=24'h80B9AC;
    end
   end
   7:begin
    icon_on=ix>=36&&ix<108&&iy>=4&&iy<68;
    if(ix>=69&&ix<75||iy>=33&&iy<39)icon_on=0;
    icon_color=iy<36?(ix<72?24'h79B8FF:24'h64DDB4):(ix<72?24'hFFAD72:24'hB8A0FF);
   end
   4:begin
    if(ix>=32&&ix<112&&iy>=8&&iy<66)begin
     if(ix<70)begin icon_on=1;icon_color=ix[4]?24'h64DDB4:24'h79B8FF;end
     else icon_on=ix<74||iy<11||iy>=63||ix>=109||iy==ix-56;
    end
   end
   6:icon_on=head||bracket||(iy>=57&&iy<62&&ix>=52&&ix<=92);
   5:icon_on=head||(iy>=55&&iy<60&&ix>=52&&ix<=92)||(ix>=105&&ix<110&&iy>=8&&iy<55);
  endcase
 end
 reg[5:0]line_id,ci;reg[3:0]fr,fc;reg text_on;
 reg[23:0]bg,fg;reg[10:0]tx;reg[9:0]ty;reg[11:0]number;
 reg[7:0]br,bg_green,bb;
 wire[1:0]column=x<208?0:x<360?1:x<512?2:3;
 wire[10:0]mx=x-(56+column*152);
 wire[127:0]meta=state_i[128+column*128+:128];
 function[3:0]decimal;input[11:0]v;input[1:0]p;
 begin case(p)0:decimal=v/1000;1:decimal=(v/100)%10;2:decimal=(v/10)%10;default:decimal=v%10;endcase end endfunction
 always @*begin
  line_id=0;ci=0;fr=0;fc=0;text_on=0;tx=0;ty=0;number=0;
  br=8'd9+{4'd0,y[9:6]};bg_green=8'd18+{3'd0,y[9:5]};bb=8'd36+{3'd0,y[9:5]};
  bg={br,bg_green,bb};fg=24'hecf4ff;
  if((y==96||y==540)&&x>=48&&x<976)bg=24'h2c405c;
  if(x>=840&&x<976&&y>=36&&y<72)bg=held?24'h5c4328:24'h1b4b49;
  if(x>=48&&x<800&&y>=38&&y<70)begin line_id=0;tx=x-48;ty=y-38;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;end
  if(x>=864&&x<960&&y>=46&&y<62)begin line_id=held?10:9;tx=x-864;ty=y-46;ci=tx>>4;fr=ty;fc=tx;text_on=1;end
  begin
   if(tile_area&&cut_inside)begin
    bg=tile_selected?24'h294263:24'h17283e;
    if(tile_selected&&outer_edge)bg=accent(tile);
    if(iy<80&&icon_on)bg=icon_color;
   end
   // Moving head and two progressively dimmer trailing sections, including wrap.
   if(x>=48&&x<976&&y>=304&&y<310)begin
    bg=24'h22354e;
    if(phase<104)bg=accent(mode);
    else if(distance!=0&&phase>=904)bg=24'h426b87;
    else if(distance!=0&&phase>=880)bg=24'h2d465f;
   end
   if(x>=48&&x<964&&lx>=36&&lx<68&&y>=140&&y<156)begin line_id=1+tile;tx=lx-36;ty=y-140;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=tile_selected?24'hffffff:24'h7f96b6;end
   if(x>=48&&x<964&&lx>=4&&lx<100&&y>=280&&y<296)begin line_id=1+tile;tx=lx-4;ty=y-280;ci=3+(tx>>4);fr=ty;fc=tx;text_on=1;fg=tile_selected?24'hffffff:24'ha3b5cd;end
   if(mode!=6&&x>=56&&x<960&&y>=346&&y<378)begin line_id=16+mode;tx=x-56;ty=y-346;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;end
   if(mode!=6&&x>=56&&x<968&&y>=398&&y<414)begin line_id=24+mode;tx=x-56;ty=y-398;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hafc3dc;end
   // Only mode 7 paints the live count. Unknown data is --; saturation is 8+.
   if(mode==6)begin
    if(x>=416&&x<608&&y>=338&&y<370)begin line_id=11;tx=x-416;ty=y-338;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;end
    if(x>=432&&x<560&&y>=390&&y<454)begin tx=x-432;ty=y-390;line_id=63;ci=!state_i[14]?16:(tx<64?state_i[19:16]:(state_i[15]?17:18));fr=ty>>2;fc=tx>>2;text_on=1;fg=24'h65dbab;end
    if(x>=568&&x<600&&y>=414&&y<446)begin line_id=15;ci=0;fr=(y-414)>>1;fc=(x-568)>>1;text_on=1;end
    if(x>=328&&x<696&&y>=476&&y<492)begin line_id=!state_i[14]?14:held?13:12;tx=x-328;ty=y-476;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hafc3dc;end
   end
   if(mode==5&&x>=56&&x<688&&y>=438&&y<454)begin line_id=state_i[28:26]!=0?46:45;tx=x-56;ty=y-438;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hfa93c3;end
   if(mode==7&&x>=56&&x<664&&mx<144&&state_i[113+column])begin
    if(y>=438&&y<454)begin line_id=1+meta[97:96];tx=mx;ty=y-438;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hffad72;end
    if(meta[97:96]!=0&&y>=466&&y<482&&mx<112)begin
     tx=mx;ty=y-466;fr=ty;fc=tx;text_on=1;
     if(mx<48)begin line_id=meta[97:96]==1?36:35;ci=tx>>4;end
     else begin line_id=63;tx=mx-48;number=meta[97:96]==1?meta[83:72]:meta[95:84];ci=decimal(number,tx>>4);fc=tx;end
    end
    if(y>=494&&y<510&&mx<128)begin
     fr=y-494;fc=mx;text_on=1;fg=24'ha3b5cd;
     if(meta[97:96]==1)begin
      if(mx<64)begin line_id=37;ci=mx>>4;end
      else begin line_id=63;tx=mx-64;number=meta[95:84];ci=decimal(number,tx>>4);fc=tx;end
     end else begin line_id=63;ci=meta[24+(7-(mx>>4))*4+:4];end
    end
   end
   // A single threshold and step are shown inside modes 2..5. The old
   // settings/LOW/HIGH/LINK page and its IO35 entry card no longer exist.
   if(edge_mode)begin
    if(x>=48&&x<976&&y>=430&&y<534)begin bg=24'h17283e;if(x<50||x>=974||y<432||y>=532)bg=24'h426487;end
    if(canny_mode)begin
     if(x>=64&&x<160&&y>=440&&y<472)begin line_id=36;tx=x-64;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==1?24'h7f96b6:24'h65dbab;end
     if(x>=176&&x<304&&y>=440&&y<472)begin line_id=63;tx=x-176;ty=y-440;ci=decimal(threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==1?24'h7f96b6:24'hecf4ff;end
     if(x>=400&&x<528&&y>=440&&y<472)begin line_id=37;tx=x-400;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==2?24'h7f96b6:24'h65dbab;end
     if(x>=544&&x<672&&y>=440&&y<472)begin line_id=63;tx=x-544;ty=y-440;ci=decimal(high_threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==2?24'h7f96b6:24'hecf4ff;end
     if(x>=720&&x<960&&y>=448&&y<464)begin line_id=selection==0?55+step:58+step;tx=x-720;ty=y-448;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'h65dbab;end
    end else begin
     if(x>=64&&x<256&&y>=440&&y<472)begin line_id=32;tx=x-64;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=24'h82b5ff;end
     if(x>=272&&x<400&&y>=440&&y<472)begin line_id=63;tx=x-272;ty=y-440;ci=decimal(threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;end
     if(x>=448&&x<512&&y>=448&&y<464)begin line_id=38;tx=x-448;ty=y-448;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hafc3dc;end
     if(x>=544&&x<576&&y>=440&&y<472)begin line_id=63;ci=step==0?1:step==1?4:8;fr=(y-440)>>1;fc=(x-544)>>1;text_on=1;fg=24'h65dbab;end
    end
    if(x>=64&&x<592&&y>=482&&y<498)begin line_id=33;tx=x-64;ty=y-482;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end
    if(canny_mode&&x>=608&&x<960&&y>=482&&y<498)begin line_id=52+selection;tx=x-608;ty=y-482;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'h65dbab;end
    if(x>=64&&x<960&&y>=510&&y<526)begin line_id=canny_mode?61:34;tx=x-64;ty=y-510;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end
   end
   if(x>=56&&x<376&&y>=558&&y<574)begin line_id=40;tx=x-56;ty=y-558;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end
   if(x>=400&&x<976&&y>=558&&y<574)begin line_id=mode==7?(state_i[13]?44:state_i[122]?62:31):mode==5?29:41;tx=x-400;ty=y-558;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end
  end
 end
 wire[15:0]bits;menu_glyph_rom #(.SHARED_FONT(SHARED_FONT)) font(clk,line_id,ci,fr,bits,shared_addr,shared_bits);
 reg[3:0]cq;reg tq,dq;reg[23:0]bq,fq;
 always @(posedge clk)begin
  if(reset)begin cq<=0;tq<=0;dq<=0;bq<=0;fq<=0;rgb<=0;de<=0;end
  else begin cq<=fc;tq<=text_on;dq<=visible;bq<=bg;fq<=fg;rgb<=dq?((tq&&bits[15-cq])?fq:bq):0;de<=dq;end
 end
endmodule
