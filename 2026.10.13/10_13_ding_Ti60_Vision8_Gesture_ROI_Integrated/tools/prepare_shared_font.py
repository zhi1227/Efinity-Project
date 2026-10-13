from pathlib import Path
import json,re
P=Path(__file__).resolve().parents[1];S=P.parent/'10_12_ding_Ti60_Vision8_Buttons_Integrated'
chars={};words={}
for name in ['menu','vision6']:
 lines=json.loads((S/f'reports/{name}_font.json').read_text(encoding='utf-8'))['lines']
 chars[name]=' '+''.join(sorted(set(''.join(lines))-{' '}))
 flat=[int(x,16) for x in (S/f'{name}_font.hex').read_text().split()]
 for i,ch in enumerate(chars[name]):
  glyph=flat[16*i:16*i+16]
  if ch in words:assert words[ch]==glyph,ch
  words[ch]=glyph
union=' '+''.join(sorted(set(words)-{' '}));assert len(union)==256
(P/'shared_font.hex').write_text('\n'.join(f'{v:04x}' for ch in union for v in words[ch])+'\n')
(P/'rtl/shared_glyph_rom.v').write_text('''// Exact original 16x16 glyphs; two independent synchronous read ports.
module shared_glyph_rom(input clk_hdmi,input[11:0]addr_hdmi,output reg[15:0]bits_hdmi,
 input clk_lvds,input[11:0]addr_lvds,output reg[15:0]bits_lvds);
 (* ram_style="block" *) reg[15:0]glyphs[0:4095];
 initial $readmemh("shared_font.hex",glyphs);
 always @(posedge clk_hdmi) bits_hdmi<=glyphs[addr_hdmi];
 always @(posedge clk_lvds) bits_lvds<=glyphs[addr_lvds];
endmodule
''')
for name in ['menu','vision6']:
 path=f'rtl/{name}_glyph_rom.v';v=(S/path).read_text(encoding='utf-8-sig')
 v=v.replace(f'module {name}_glyph_rom(',f'module {name}_glyph_rom #(parameter SHARED_FONT=0)(')
 v=v.replace('output reg[15:0]bits);','output reg[15:0]bits,output[11:0]shared_addr,input[15:0]shared_bits);')
 marker='// Banked glyph storage';idx=v.index(marker)
 lookup=['reg[7:0]common_glyph;always @*begin common_glyph=0;case(glyph)']
 lookup += [f"8'd{i}:common_glyph=8'd{union.index(ch)};" for i,ch in enumerate(chars[name])]
 lookup += ['default:common_glyph=0;endcase end','assign shared_addr={common_glyph,row};',
 'generate if(SHARED_FONT)begin:shared_font_read','always @* bits=shared_bits;',
 'end else begin:local_font_read']
 v=v[:idx]+'\n'.join(lookup)+'\n'+v[idx:]
 pos=v.rfind('endmodule');v=v[:pos]+'end endgenerate\n'+v[pos:]
 (P/path).write_text(v,encoding='utf-8')
# Append ports; default local path keeps standalone modules compatible.
paths=['rtl/menu8_renderer.v','rtl/menu_renderer.v','rtl/menu_lcd_apb.v','rtl/riscv_menu_top.v','rtl/vision6_overlay.v','src/parallel/parallel_video.v']
for path in paths:
 v=(S/path).read_text(encoding='utf-8-sig')
 if path=='rtl/menu8_renderer.v':v=v.replace('module menu8_renderer(','module menu8_renderer #(parameter SHARED_FONT=0)(')
 elif path=='rtl/menu_renderer.v':v=v.replace('module menu_renderer (','module menu_renderer #(parameter SHARED_FONT=0) (')
 elif path=='rtl/menu_lcd_apb.v':v=v.replace('parameter V8_ENABLE=0','parameter V8_ENABLE=0,SHARED_FONT=0')
 elif path=='rtl/riscv_menu_top.v':v=v.replace('parameter V8_ENABLE=0','parameter V8_ENABLE=0,SHARED_FONT=0')
 elif path=='rtl/vision6_overlay.v':v=v.replace('GESTURE_DEBUG=0','GESTURE_DEBUG=0,SHARED_FONT=0',1)
 else:v=v.replace('HUD_ENABLE=0,GESTURE_DEBUG=0','HUD_ENABLE=0,GESTURE_DEBUG=0,SHARED_FONT=0',1)
 end=v.index(');',v.index('module '));v=v[:end]+',output[11:0]shared_addr,input[15:0]shared_bits'+v[end:]
 v=v.replace('menu_glyph_rom font(clk,line_id,ci,fr,bits);','menu_glyph_rom #(.SHARED_FONT(SHARED_FONT)) font(clk,line_id,ci,fr,bits,shared_addr,shared_bits);')
 v=v.replace('vision6_glyph_rom font(clk,line_id,ci,fr,bits);','vision6_glyph_rom #(.SHARED_FONT(SHARED_FONT)) font(clk,line_id,ci,fr,bits,shared_addr,shared_bits);')
 v=v.replace('menu_glyph_rom glyph(', 'menu_glyph_rom #(.SHARED_FONT(SHARED_FONT)) glyph(').replace('.row(font_row),.bits(glyph_bits)', '.row(font_row),.bits(glyph_bits),.shared_addr(shared_addr),.shared_bits(shared_bits)')
 v=v.replace('menu8_renderer renderer(clk,reset,x,y,visible,active8,rgb,de);','menu8_renderer #(.SHARED_FONT(SHARED_FONT)) renderer(clk,reset,x,y,visible,active8,rgb,de,shared_addr,shared_bits);')
 v=v.replace('menu_renderer renderer(', 'menu_renderer #(.SHARED_FONT(SHARED_FONT)) renderer(').replace('.rgb(rgb),.de(de));','.rgb(rgb),.de(de),.shared_addr(shared_addr),.shared_bits(shared_bits));')
 v=v.replace('menu_lcd_apb #(.V8_ENABLE(V8_ENABLE))','menu_lcd_apb #(.V8_ENABLE(V8_ENABLE),.SHARED_FONT(SHARED_FONT))')
 v=v.replace('.prdata(menu_prdata), .rgb(rgb), .de(de)', '.prdata(menu_prdata), .rgb(rgb), .de(de),.shared_addr(shared_addr),.shared_bits(shared_bits)')
 if path=='src/parallel/parallel_video.v':
  v=v.replace('.GESTURE_DEBUG(GESTURE_DEBUG)) u_overlay(','.GESTURE_DEBUG(GESTURE_DEBUG),.SHARED_FONT(SHARED_FONT)) u_overlay(\n .shared_addr(shared_addr),.shared_bits(shared_bits),')
 (P/path).write_text(v,encoding='utf-8')
v=(S/'example_top.v').read_text(encoding='utf-8-sig')
v=v.replace('parallel_video #(','''wire[11:0]font_hdmi_addr,font_lvds_addr;
 wire[15:0]font_hdmi_bits,font_lvds_bits;
 shared_glyph_rom u_shared_font(.clk_hdmi(clk_pixel),.addr_hdmi(font_hdmi_addr),.bits_hdmi(font_hdmi_bits),
 .clk_lvds(clk_lvds_1x),.addr_lvds(font_lvds_addr),.bits_lvds(font_lvds_bits));
 parallel_video #(.SHARED_FONT(1),''',1)
v=v.replace(' u_parallel(',' u_parallel(\n .shared_addr(font_hdmi_addr),.shared_bits(font_hdmi_bits),',1)
v=v.replace('riscv_menu_top #(.V8_ENABLE(1))','riscv_menu_top #(.V8_ENABLE(1),.SHARED_FONT(1))')
v=v.replace(' u_menu(',' u_menu(\n .shared_addr(font_lvds_addr),.shared_bits(font_lvds_bits),',1)
(P/'example_top.v').write_text(v,encoding='utf-8')
v=(S/'Ti60_Demo.xml').read_text(encoding='utf-8-sig');needle='<efx:design_file name="rtl/menu_glyph_rom.v"'
v=v.replace(needle,'<efx:design_file name="rtl/shared_glyph_rom.v" version="default" library="default" />\n        '+needle)
(P/'Ti60_Demo.xml').write_text(v,encoding='utf-8')
(P/'reports/cpu_font_ram/font_merge.json').write_text(json.dumps({'characters':len(union),'rows':4096,'shared_characters':len(set(chars['menu'])&set(chars['vision6'])),'all_original_pixels_equal':True},indent=2),encoding='utf-8')
print('Shared exact glyphs:',len(union),'two clocks, unchanged latency')
