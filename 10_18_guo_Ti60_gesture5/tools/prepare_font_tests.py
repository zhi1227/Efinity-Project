from pathlib import Path
import re
P=Path(__file__).resolve().parents[1];S=P.parent/'10_12_ding_Ti60_Vision8_Buttons_Integrated'
run=P/'sim_shared_font';(run/'reports').mkdir(parents=True,exist_ok=True)
for name in ['menu','vision6']:
 v=(S/f'rtl/{name}_glyph_rom.v').read_text(encoding='utf-8-sig').replace(f'module {name}_glyph_rom(',f'module {name}_glyph_ref(')
 (run/f'{name}_glyph_ref.v').write_text(v,encoding='utf-8')
for src in ['menu8_renderer','vision6_overlay']:
 v=(S/f'rtl/{src}.v').read_text(encoding='utf-8-sig').replace('module '+src,'module '+src+'_ref').replace('menu_glyph_rom font','menu_glyph_ref font').replace('vision6_glyph_rom font','vision6_glyph_ref font')
 (run/f'{src}_ref.v').write_text(v,encoding='utf-8')
v=(S/'sim/tb_menu8_pixels.sv').read_text(encoding='utf-8-sig').replace('module tb_menu8_pixels;','module tb_shared_ui;')
v=v.replace('menu8_renderer dut(clk,reset,x,y,visible,state,rgb,de);','''wire[11:0]addr;wire[15:0]bits;wire[23:0]ref_rgb;wire ref_de;
 reg hdmi_clk=0;always #6.72043 hdmi_clk=~hdmi_clk;reg[11:0]hdmi_addr=0;
 always @(negedge hdmi_clk)hdmi_addr<=hdmi_addr+1'b1;
 shared_glyph_rom common(hdmi_clk,hdmi_addr,,clk,addr,bits);
 menu8_renderer #(.SHARED_FONT(1)) dut(clk,reset,x,y,visible,state,rgb,de,addr,bits);
 menu8_renderer_ref reference(clk,reset,x,y,visible,state,ref_rgb,ref_de);
 always @(negedge clk)if(!reset && (rgb!==ref_rgb||de!==ref_de))$fatal(1,"Shared-font UI pixel/DE differs x%0d y%0d",x,y);''')
v=v.replace('PASS: all eight UI images','PASS: all eight shared UI images pixel-exact versus original, concurrent HDMI port;')
(run/'tb_shared_ui.sv').write_text(v,encoding='utf-8')
(run/'tb_shared_glyphs.sv').write_text('''`timescale 1ns/1ps
module tb_shared_glyphs;
 reg a=0,b=0;always #6.72043 a=~a;always #10.416667 b=~b;
 reg[5:0]la=0;reg[4:0]lb=0;reg[5:0]ca=0,cb=0;reg[3:0]ra=0,rb=0;
 wire[11:0]aa,ab;wire[15:0]qa,qb,orig_a,orig_b,ba,bb;
 shared_glyph_rom common(a,aa,qa,b,ab,qb);
 vision6_glyph_rom #(.SHARED_FONT(1)) ha(a,la,ca,ra,ba,aa,qa);
 menu_glyph_rom #(.SHARED_FONT(1)) mb(b,lb,cb,rb,bb,ab,qb);
 vision6_glyph_ref oa(a,la,ca,ra,orig_a);menu_glyph_ref ob(b,lb,cb,rb,orig_b);
 integer ia=0,ib=0;reg da=0,db=0;
 initial begin
  for(ia=0;ia<65536;ia=ia+1)begin @(negedge a);#0.01;if(ba!==orig_a)$fatal(1,"HDMI glyph row mismatch %0d",ia);{la,ca,ra}=ia;end
  repeat(2)@(negedge a);da=1;end
 initial begin
  for(ib=0;ib<32768;ib=ib+1)begin @(negedge b);#0.01;if(bb!==orig_b)$fatal(1,"LVDS glyph row mismatch %0d",ib);{lb,cb,rb}=ib;end
  repeat(2)@(negedge b);db=1;end
 initial begin wait(da&&db);$display("PASS: 65536 HDMI and 32768 LVDS glyph addresses match original under independent simultaneous clocks");$finish;end
endmodule
''')
# Real CPU tests exercise the new shared path while the other port reads continuously.
for file,clk in [('tb_menu_cpu8.sv','source_clk'),('tb_epd_cpu.sv','font_clk')]:
 v=(S/f'sim/{file}').read_text(encoding='utf-8-sig')
 extra='wire[11:0]font_addr;wire[15:0]font_bits;reg[11:0]other_addr=0;\n'
 if clk=='font_clk':extra+='reg font_clk=0;always #6.72043 font_clk=~font_clk;\n'
 extra+=f"always @(negedge {clk})other_addr<=other_addr+1'b1;\nshared_glyph_rom font_shared({clk},other_addr,,clk,font_addr,font_bits);\n"
 pos=v.index(' riscv_menu_top');v=v[:pos]+' '+extra+v[pos:]
 v=v.replace('riscv_menu_top #(','riscv_menu_top #(.SHARED_FONT(1),',1)
 v=v.replace(' dut(',' dut(.shared_addr(font_addr),.shared_bits(font_bits),',1)
 (P/f'sim/{file}').write_text(v,encoding='utf-8')
for tool in ['test_cpu8.ps1','test_epaper.ps1']:
 v=(S/f'tools/{tool}').read_text(encoding='utf-8-sig').replace("'../vendor/EfxSapphireSoc.v'","'../rtl/shared_glyph_rom.v' '../vendor/EfxSapphireSoc.v'")
 (P/f'tools/{tool}').write_text(v,encoding='utf-8')
print('Prepared exact-glyph and pixel-equivalence tests, real CPU tests use shared path')
