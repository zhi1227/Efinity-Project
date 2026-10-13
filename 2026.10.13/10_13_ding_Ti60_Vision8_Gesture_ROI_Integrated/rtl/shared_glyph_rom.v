// Exact original 16x16 glyphs; two independent synchronous read ports.
module shared_glyph_rom(input clk_hdmi,input[11:0]addr_hdmi,output reg[15:0]bits_hdmi,
 input clk_lvds,input[11:0]addr_lvds,output reg[15:0]bits_lvds);
 (* ram_style="block" *) reg[15:0]glyphs[0:4095];
 initial $readmemh("shared_font.hex",glyphs);
 always @(posedge clk_hdmi) bits_hdmi<=glyphs[addr_hdmi];
 always @(posedge clk_lvds) bits_lvds<=glyphs[addr_lvds];
endmodule
