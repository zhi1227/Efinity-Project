// Generated dual-clock ROM banks. Both ports retain one-clock latency.
module shared_glyph_rom_reference(input clk_hdmi,input[12:0]addr_hdmi,output reg[15:0]bits_hdmi,
input clk_lvds,input[12:0]addr_lvds,output reg[15:0]bits_lvds);
reg[3:0]hbank,lbank;always @(posedge clk_hdmi)hbank<=addr_hdmi[12:9];
always @(posedge clk_lvds)lbank<=addr_lvds[12:9];
(* ram_style="block" *)reg[15:0]bank0[0:511];reg[15:0]h0,l0;
initial $readmemh("shared_font_bank0.hex",bank0);
always @(posedge clk_hdmi)h0<=bank0[addr_hdmi[8:0]];
always @(posedge clk_lvds)l0<=bank0[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank1[0:511];reg[15:0]h1,l1;
initial $readmemh("shared_font_bank1.hex",bank1);
always @(posedge clk_hdmi)h1<=bank1[addr_hdmi[8:0]];
always @(posedge clk_lvds)l1<=bank1[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank2[0:511];reg[15:0]h2,l2;
initial $readmemh("shared_font_bank2.hex",bank2);
always @(posedge clk_hdmi)h2<=bank2[addr_hdmi[8:0]];
always @(posedge clk_lvds)l2<=bank2[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank3[0:511];reg[15:0]h3,l3;
initial $readmemh("shared_font_bank3.hex",bank3);
always @(posedge clk_hdmi)h3<=bank3[addr_hdmi[8:0]];
always @(posedge clk_lvds)l3<=bank3[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank4[0:511];reg[15:0]h4,l4;
initial $readmemh("shared_font_bank4.hex",bank4);
always @(posedge clk_hdmi)h4<=bank4[addr_hdmi[8:0]];
always @(posedge clk_lvds)l4<=bank4[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank5[0:511];reg[15:0]h5,l5;
initial $readmemh("shared_font_bank5.hex",bank5);
always @(posedge clk_hdmi)h5<=bank5[addr_hdmi[8:0]];
always @(posedge clk_lvds)l5<=bank5[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank6[0:511];reg[15:0]h6,l6;
initial $readmemh("shared_font_bank6.hex",bank6);
always @(posedge clk_hdmi)h6<=bank6[addr_hdmi[8:0]];
always @(posedge clk_lvds)l6<=bank6[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank7[0:511];reg[15:0]h7,l7;
initial $readmemh("shared_font_bank7.hex",bank7);
always @(posedge clk_hdmi)h7<=bank7[addr_hdmi[8:0]];
always @(posedge clk_lvds)l7<=bank7[addr_lvds[8:0]];
(* ram_style="block" *)reg[15:0]bank8[0:511];reg[15:0]h8,l8;
initial $readmemh("shared_font_bank8.hex",bank8);
always @(posedge clk_hdmi)h8<=bank8[addr_hdmi[8:0]];
always @(posedge clk_lvds)l8<=bank8[addr_lvds[8:0]];
always @*begin bits_hdmi=0;case(hbank)
4'd0:bits_hdmi=h0;
4'd1:bits_hdmi=h1;
4'd2:bits_hdmi=h2;
4'd3:bits_hdmi=h3;
4'd4:bits_hdmi=h4;
4'd5:bits_hdmi=h5;
4'd6:bits_hdmi=h6;
4'd7:bits_hdmi=h7;
4'd8:bits_hdmi=h8;
default:;endcase end
always @*begin bits_lvds=0;case(lbank)
4'd0:bits_lvds=l0;
4'd1:bits_lvds=l1;
4'd2:bits_lvds=l2;
4'd3:bits_lvds=l3;
4'd4:bits_lvds=l4;
4'd5:bits_lvds=l5;
4'd6:bits_lvds=l6;
4'd7:bits_lvds=l7;
4'd8:bits_lvds=l8;
default:;endcase end
endmodule
