// Generated fixed phrases; synchronous glyph BRAM aligned with video/debug RAM.
module demo_text(input clk,rst_n,input[10:0]x,input[9:0]y,input[1:0]mode,
 input model_ready,model_error,input model_enabled,input frozen,target,multi,clip,
 input[2:0]gesture,output area,ink);
 reg[4:0]msg;reg[10:0]px;reg[9:0]py;reg enable;reg[255:0]message;
 reg[15:0]rom[0:1120-1],bits;reg[3:0]column;reg area_reg;
 initial $readmemh("model/glyphs.mem",rom);
 always @*begin
 msg=0;px=0;py=0;enable=0;
 if(mode!=2)begin
   if(x>=16&&x<848&&y>=16&&y<48)begin
     enable=1;px=x-16;py=y-16;
     msg=mode==1?13:(model_error?14:(!model_enabled?1:(!model_ready?15:0)));
   end else if(x>=16&&x<848&&y>=64&&y<96&&mode==0)begin
     enable=1;px=x-16;py=y-64;msg=multi?3:(clip?4:(!target?2:(gesture==0?6:(gesture==1?7:(gesture==2?8:9)))));
   end else if(x>=976&&x<1232&&y>=412&&y<444&&mode==0)begin
     enable=1;px=x-976;py=y-412;msg=gesture==0?6:(gesture==1?7:(gesture==2?8:9));
   end else if(x>=16&&x<848&&y>=680&&y<712)begin
     enable=1;px=x-16;py=y-680;msg=10;
   end else if(x>=1120&&x<1248&&y>=16&&y<48)begin
     enable=1;px=x-1120;py=y-16;msg=frozen?11:12;
   end
 end
 message=0;
 case(msg)
  0:message=256'h2416391300000000000000000000000000000000000000000000000000000000;
  1:message=256'h3f404238451f2c153c302d000000000000000000000000000000000000000000;
  2:message=256'h3a25242a0d2f0e00000000000000000000000000000000000000000000000000;
  3:message=256'h192a0b1924000000000000000000000000000000000000000000000000000000;
  4:message=256'h24343d2f3e0b3200000000000000000000000000000000000000000000000000;
  5:message=256'h0c26241644352239130000000000000000000000000000000000000000000000;
  6:message=256'h2c3913443a0c2624160000000000000000000000000000000000000000000000;
  7:message=256'h1827000200000000000000000000000000000000000000000000000000000000;
  8:message=256'h1410240003000000000000000000000000000000000000000000000000000000;
  9:message=256'h2129000400000000000000000000000000000000000000000000000000000000;
  10:message=256'h0502001128334100000503000f36231b00000000000000000000000000000000;
  11:message=256'h0f36000000000000000000000000000000000000000000000000000000000000;
  12:message=256'h1e2b000000000000000000000000000000000000000000000000000000000000;
  13:message=256'h3120000100060a070809003d3700000000000000000000000000000000000000;
  14:message=256'h301a2e431c3b0000000000000000000000000000000000000000000000000000;
  15:message=256'h301a121d17000000000000000000000000000000000000000000000000000000;
 endcase
 end
 wire[7:0]character=message[255-(px>>5)*8-:8];
 wire[10:0]address={character[6:0],py[4:1]};
 always @(posedge clk)begin
 if(!rst_n)begin bits<=0;column<=0;area_reg<=0;end
 else begin bits<=rom[enable?address:0];column<=px[4:1];area_reg<=enable;end end
 assign area=area_reg;assign ink=area_reg&&bits[15-column];
endmodule
