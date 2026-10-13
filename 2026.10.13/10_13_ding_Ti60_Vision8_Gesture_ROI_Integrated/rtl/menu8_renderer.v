// Eight-mode LVDS UI. The RISC-V commits one coherent status bundle per frame.
module menu8_renderer #(parameter SHARED_FONT=0)(input clk,reset,input[10:0]x,input[9:0]y,input visible,
 input[639:0]state_i,output reg[23:0]rgb,output reg de,output[11:0]shared_addr,input[15:0]shared_bits);
 wire[2:0]mode=state_i[2:0];wire[11:0]low=state_i[48:37],high=state_i[60:49];
 wire[1:0]sel=state_i[62:61],step=state_i[64:63];
 wire[1:0]column=x<272?0:x<512?1:x<752?2:3;
 wire[10:0]lx=x-(32+column*240);
 wire[2:0]tile={y>=220,column};wire[9:0]ly=y-(y>=220?220:90);
 wire card=x>=32&&x<976&&lx<224&&((y>=90&&y<198)||(y>=220&&y<328));
 wire[127:0]meta=state_i[128+column*128+:128];
 reg[4:0]line_id;reg[5:0]ci;reg[3:0]fr,fc;reg text_on;
 reg[23:0]bg,fg;reg[10:0]tx;reg[9:0]ty;reg[11:0]number;reg[1:0]position;
 function[3:0]decimal;input[11:0]v;input[1:0]p;
 begin case(p)0:decimal=v/1000;1:decimal=(v/100)%10;2:decimal=(v/10)%10;default:decimal=v%10;endcase end endfunction
 always @*begin
  line_id=0;ci=0;fr=0;fc=0;text_on=0;tx=0;ty=0;number=0;position=0;bg=24'h08121e;fg=24'he7f3ff;
  if(card)begin
   bg=tile==mode?24'h183e52:24'h132336;
   if(lx<3||lx>=221||ly<3||ly>=105)bg=tile==mode?24'h35d499:24'h284258;
   if(ly>=20&&ly<52&&lx>=12&&lx<220)begin line_id=tile+1;tx=lx-12;ty=ly-20;ci=tx>>4;fr=ty>>1;fc=tx[3:0];text_on=1;end
   if(ly>=68&&ly<76&&lx>=12&&lx<208)bg=tile==mode?24'h35d499:24'h284258;
  end
  if(x>=32&&x<960&&y>=22&&y<54)begin line_id=0;tx=x-32;ty=y-22;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;end
  if(x>=32&&x<992&&y>=350&&y<366)begin line_id=mode==4?15:mode==5?10:mode==6?13:mode==7?14:11;tx=x-32;ty=y-350;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(x>=32&&x<992&&y>=374&&y<390)begin line_id=12;tx=x-32;ty=y-374;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(y>=414&&y<430&&x>=32&&x<896)begin line_id=9;tx=x-32;ty=y-414;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(y>=414&&y<430&&((x>=112&&x<176)||(x>=304&&x<368)))begin
   number=x<200?low:high;tx=x-(x<200?112:304);ty=y-414;position=tx>>4;line_id=31;ci=decimal(number,position);fr=ty[3:0];fc=tx[3:0];text_on=1;
   bg=mode==5&&((sel==0&&x<200)||(sel==1&&x>200)||sel==2)?24'h28604a:24'h132336;
  end
  if(y>=414&&y<430&&x>=656&&x<720)begin line_id=22;ci=(sel==0?0:sel==1?4:9)+((x-656)>>4);fr=y-414;fc=x-656;text_on=1;end
  if(y>=414&&y<430&&x>=816&&x<832)begin line_id=31;ci=step==0?1:step==1?4:8;fr=y-414;fc=x-816;text_on=1;end
  if(y>=446&&y<462&&x>=32&&x<272)begin line_id=state_i[3]?16:state_i[13]?17:18;tx=x-32;ty=y-446;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(mode==6&&y>=446&&y<462&&x>=320&&x<672)begin line_id=21;tx=x-320;ty=y-446;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(mode==6&&y>=446&&y<462&&x>=640&&x<672)begin
   line_id=31;ci=!state_i[14]?16:(x<656?state_i[19:16]:(state_i[15]?17:18));fr=y-446;fc=x[3:0];text_on=1;
  end
  if(mode==7&&y>=446&&y<462&&x>=320&&x<672)begin line_id=state_i[28:26]!=0?19:20;tx=x-320;ty=y-446;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
  if(mode==4&&state_i[113+column]&&lx<224)begin
   if(y>=490&&y<506)begin line_id=1+meta[97:96];tx=lx;ty=y-490;ci=tx>>4;fr=ty[3:0];fc=tx[3:0];text_on=1;end
   if(y>=516&&y<532&&lx<64)begin line_id=31;ci=decimal(meta[83:72],lx>>4);fr=y-516;fc=lx[3:0];text_on=1;end
   if(y>=516&&y<532&&lx>=80&&lx<144)begin line_id=31;ci=decimal(meta[95:84],(lx-80)>>4);fr=y-516;fc=lx[3:0];text_on=1;end
   if(y>=542&&y<558&&lx<128)begin line_id=31;ci=meta[24+(7-(lx>>4))*4+:4];fr=y-542;fc=lx[3:0];text_on=1;end
  end
  if(y>=578&&y<586&&x>=32&&x<544)bg=state_i[4+((x-32)>>6)]?24'h35d499:24'hf06a70;
 end
 wire[15:0]bits;menu_glyph_rom #(.SHARED_FONT(SHARED_FONT)) font(clk,line_id,ci,fr,bits,shared_addr,shared_bits);
 reg[3:0]cq;reg tq,dq;reg[23:0]bq,fq;
 always @(posedge clk)begin
  if(reset)begin cq<=0;tq<=0;dq<=0;bq<=0;fq<=0;rgb<=0;de<=0;end
  else begin cq<=fc;tq<=text_on;dq<=visible;bq<=bg;fq<=fg;rgb<=dq?((tq&&bits[15-cq])?fq:bq):0;de<=dq;end
 end
endmodule
