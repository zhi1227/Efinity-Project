// One binary-to-decimal conversion per gesture result, spread over 20 clocks.
module ep1_decimal(input clk,rst_n,start,input[19:0]number,output reg[23:0]digits);
 reg[19:0]binary;reg[23:0]work;reg[4:0]step;reg busy;
 reg[23:0]adjusted;integer j;
 always @*begin
  adjusted=work;
  for(j=0;j<6;j=j+1)if(work[j*4+:4]>=5)adjusted[j*4+:4]=work[j*4+:4]+4'd3;
 end
 always @(posedge clk)begin
  if(!rst_n)begin binary<=0;work<=0;digits<=0;step<=0;busy<=0;end
  else if(start)begin binary<=number;work<=0;step<=0;busy<=1;end
  else if(busy)begin
   work<={adjusted[22:0],binary[19]};binary<={binary[18:0],1'b0};
   if(step==19)begin digits<={adjusted[22:0],binary[19]};busy<=0;end
   else step<=step+1'b1;
  end
 end
endmodule

module ep1_hud(input[10:0]x,input[9:0]y,input[2:0]mode,input[7:0]threshold,
 input[1:0]gesture,input[23:0]digits,area_digits,ratio_digits,input[7:0]skin_lower,input overflow,output area,ink);
 reg[511:0]line;reg[79:0]name;reg[47:0]label;
 wire[10:0]local_x=x-11'd8;
 wire[6:0]col=local_x[10:4];
 wire[7:0]ch=col<64?line[(63-col)*8+:8]:8'h20;
 wire[34:0]glyph;hand_font font(ch,glyph);
 wire[2:0]gx=local_x[3:1];wire[2:0]gy=y[3:1];
 assign area=x>=8&&x<1032&&y<48;
 assign ink=area&&y[3:0]<14&&gx<5&&gy<7&&glyph[34-(gy*5+gx)];
 wire[7:0]hundreds=threshold/8'd100,tens=(threshold/8'd10)%8'd10,ones=threshold%8'd10;
 wire[7:0]t100={4'h3,hundreds[3:0]},t10={4'h3,tens[3:0]},t1={4'h3,ones[3:0]};
 function[47:0]decimal_text(input[23:0]bcd);integer k;begin
  for(k=0;k<6;k=k+1)decimal_text[k*8+:8]=8'h30+{4'd0,bcd[k*4+:4]};
 end endfunction
 wire[7:0]s10=8'h30+skin_lower/8'd10,s1=8'h30+skin_lower%8'd10;
 always @*begin
  case(mode)
   0:name="ORIGIN    ";1:name="GRAY      ";2:name="MEDIAN    ";3:name="SOBEL     ";
   4:name="PREWITT   ";5:name="EROSION   ";6:name="DILATION  ";default:name="GESTURE   ";
  endcase
  case(gesture)1:label="PALM  ";2:label="FIST  ";3:label="FINGER";default:label="NONE  ";endcase
  line={64{8'h20}};
  if(y<16)begin
   line[511-:16]="M:";line[495-:8]=8'h30+{5'b0,mode};line[479-:80]=name;
   line[391-:16]="T:";line[375-:24]={t100,t10,t1};
   line[343-:16]="G:";line[327-:48]=label;
   line[271-:16]="F:";
   line[255-:48]={8'h30+{4'b0,digits[23:20]},8'h30+{4'b0,digits[19:16]},
    8'h30+{4'b0,digits[15:12]},8'h30+{4'b0,digits[11:8]},
    8'h30+{4'b0,digits[7:4]},8'h30+{4'b0,digits[3:0]}};
   if(mode==7)begin
    line[391-:40]={"RG:",s10,s1};line[271-:16]="F:";
    line[255-:48]=decimal_text(digits);line[199-:40]="/1000";
    line[151-:16]="A:";line[135-:48]=decimal_text(area_digits);
    line[79-:16]="R:";line[63-:48]=decimal_text(ratio_digits);
   end
  end else if(y<32)line[511-:296]="K1 NEXT / HOLD PREV   K2 +5 / HOLD -5";
  else if(mode==7)begin
   line[511-:424]="RG LOW-90  F FILL/1000  R H/W/1000  INITIAL RULES    ";
   if(overflow)line[63-:24]="OVF";
  end
 end
endmodule

