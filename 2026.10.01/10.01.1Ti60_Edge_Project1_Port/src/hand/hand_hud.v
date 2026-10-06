module hand_hud(input[10:0]x,input[9:0]y,input[2:0]mode,gesture,learn_id,action,
 input[1:0]profile,input[4:0]trained,input target,multi,clip,pending,save_ok,save_fail,
 input[11:0]score,output area,ink,output big_area,big_ink);
 wire[10:0]px=x-16;wire[9:0]py=y-12;
 wire[6:0]index=px/18;wire[2:0]col=(px%18)/3,row=(py%24)/3;
 reg[7:0]ch;reg[39:0]act;reg[47:0]status;reg[255:0]helptext;
 wire[34:0]glyph,bigglyph;wire[3:0]ntrained={3'b0,trained[0]}+trained[1]+trained[2]+trained[3]+trained[4];
 reg[3:0]hex;
 always @*begin
   status=save_fail?"RETRY ":(save_ok?"SAVED ":(pending?"WAIT  ":(multi?"MULTI ":(clip?"CLIP  ":(target?"TRACK ":"SEARCH")))));
   act="NONE ";case(action)1:act="LEFT ";2:act="RIGHT";3:act="WAVE ";4:act="HOLD ";endcase
   helptext="K1 MODE  K2 SKIN  KEEP HAND STILL";
   if(trained!=31)helptext="K1 TO M7  TEACH ALL 1-5 USING K2  ";
   if(mode==7)helptext="SHOW 1 THEN K2  HOLD K2 TO CLEAR  ";
   ch=" ";hex=score[3:0];
   if(py<24)case(index)
     0:ch="M";1:ch=":";2:ch="0"+mode;
     4:ch="P";5:ch=":";6:ch="0"+profile;
     8:ch="T";9:ch=":";10:ch="0"+ntrained;11:ch="/";12:ch="5";
     14:ch="G";15:ch=":";16:ch=(gesture==0)?"-":"0"+gesture;
     18:ch="S";19:ch=":";
     28:ch="A";29:ch="C";30:ch="T";31:ch=":";
     39:ch="D";40:ch=":";
     41,42,43:begin case(index)41:hex=score[11:8];42:hex=score[7:4];endcase ch=(hex<10)?"0"+hex:"A"+hex-10;end
     default:begin if(index>=20&&index<26)ch=status[(25-index)*8+:8];if(index>=32&&index<37)ch=act[(36-index)*8+:8];end
   endcase
   else if(py>=24&&py<48&&index<32)begin ch=helptext[(31-index)*8+:8];if(mode==7&&index==5)ch="0"+learn_id;end
 end
 hand_font font(ch,glyph);
 hand_font bigfont((gesture==0)?8'h2d:(8'h30+gesture),bigglyph);
 wire[6:0]bx=(x-48)/16,by=(y-552)/16;
 assign area=x>=16&&x<830&&y>=12&&y<60;
 assign ink=area&&col<5&&row<7&&glyph[34-row*5-col];
 assign big_area=x>=32&&x<160&&y>=536&&y<680;
 assign big_ink=big_area&&x>=48&&y>=552&&bx<5&&by<7&&bigglyph[34-by*5-bx];
endmodule
