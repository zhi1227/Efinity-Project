// Tiny 5x7, 2x scale. No framebuffer, no extra video register.
// "M:03 LIVE" / "M:03 HOLD"; shape mode also shows RECT / CIRC / NONE.
module vision_hud(input [10:0] x,input [9:0] y,input [3:0] mode,
 input frozen,input [1:0] shape_class,output area,ink);
 wire [10:0] px=x-8;wire [9:0] py=y-8;
 wire [4:0] char_index=px/12;wire [2:0] col=(px%12)>>1,row=py>>1;
 reg [7:0] ch;reg [34:0] glyph;
 always @* begin
 ch=" ";
 case(char_index)
 0:ch="M";1:ch=":";2:ch=(mode>=10)?"1":"0";3:ch="0"+((mode>=10)?mode-10:mode);
 5:ch=frozen?"H":"L";6:ch=frozen?"O":"I";7:ch=frozen?"L":"V";8:ch=frozen?"D":"E";
 10:if(mode==12)ch=(shape_class==1)?"R":((shape_class==2)?"C":"N");
 11:if(mode==12)ch=(shape_class==1)?"E":((shape_class==2)?"I":"O");
 12:if(mode==12)ch=(shape_class==1)?"C":((shape_class==2)?"R":"N");
 13:if(mode==12)ch=(shape_class==1)?"T":((shape_class==2)?"C":"E");
 endcase
 case(ch)
 "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
 "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
 "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
 "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
 "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
 "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
 "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
 "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
 "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
 "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
 "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
 "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
 "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
 "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
 "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
 "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
 "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
 "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
 "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
 "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
 "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
 "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
 ":":glyph=35'b00000_00100_00100_00000_00100_00100_00000;
 default:glyph=0;
 endcase
 end
 assign area=x>=8 && x<176 && y>=8 && y<24;
 assign ink=area && row<7 && col<5 && glyph[34-row*5-col];
endmodule
