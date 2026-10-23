"""Regenerate local and shared glyph ROMs; one-cycle reads, no framebuffer."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
P=Path(__file__).resolve().parents[1]
lcd=['']*64
lcd[0]='VISION 八模式视觉系统'
lcd[1:9]=['01 原图','02 Canny','03 彩色红边','04 赛博边缘','05 彩边对照','07 手势识别','08 人脸识别','06 四帧对比']
lcd[9:16]=['LIVE','HOLD','人脸数量','当前画面 / 肤色轮廓候选','已冻结 / 保留当前人数','等待有效画面','人']
lcd[16:24]=['原图：摄像头彩色画面','Canny：黑白边缘','红边：彩色轮廓','赛博：霓虹边缘','对照：彩色画面与黑白边缘','手势：招手 点赞 比心 OK V字','人脸识别 / 实时人数','四帧：保存画面对比']
lcd[24:32]=['IO29 冻结 / 恢复画面','短按 K1 开关彩色画中画','短按 K1 开关彩色画中画','短按 K1 开关彩色画中画','IO29 冻结 / 恢复画面','IO34 长按录入；短按确认','IO29 冻结 / 恢复人数','IO29 保存；长按清空；IO34 换算法']
lcd[32:40]=['阈值 T','IO34 减小 / IO35 增大','长按 IO34 切步长；长按 IO35 复位','T =','LOW','HIGH','STEP','']
lcd[40:48]=['IO28 切换模式','IO29 冻结 / 恢复','08 人脸数量','切换至模式8显示','正在抓帧，请稍候','手势反馈显示在 HDMI','正在录入，请保持手型','当前画面实时更新']
lcd[48:52]=['已保存','长按 IO29 冻结 / 恢复','FRAME','版本']
lcd[52:63]=['联合调节','仅 HIGH','仅 LOW','L:1 H:2','L:4 H:8','L:8 H:16','STEP 1','STEP 4','STEP 8','K2 选阈值；长按 IO34 步长 / IO35 复位','抓拍失败，请重试']
lcd[63]='0123456789ABCDEF-+ '
hdmi=json.loads((P/'tools/hdmi_text.json').read_text(encoding='utf-8'))
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)
def raster(chars):
 words=[]
 for ch in chars:
  im=Image.new('L',(16,16));d=ImageDraw.Draw(im);box=d.textbbox((0,0),ch,font=font)
  d.text(((16-box[2]+box[0])//2-box[0],(16-box[3]+box[1])//2-box[1]),ch,font=font,fill=255)
  words.extend(sum(1<<(15-x) for x in range(16) if im.getpixel((x,y))>=100) for y in range(16))
 return words
def write_hex(name,words):
 (P/name).write_text(''.join(f'{v:04x}\n' for v in words),encoding='ascii')
def generate(lines,name,chars,union):
 assert len(chars)<=256
 words=raster(chars);banks=(len(words)+511)//512;words += [0]*(4096-len(words));memname=f'{name}_font'
 write_hex(memname+'.hex',words)
 code=[f'// Generated glyphs, {len(chars)} characters; no framebuffer.',f'module {name}_glyph_rom #(parameter SHARED_FONT=0)(input clk,input[5:0]line_id,input[5:0]char_index,input[3:0]row,output reg[15:0]bits,output[12:0]shared_addr,input[15:0]shared_bits);','reg[7:0]glyph;always @*begin glyph=0;case({line_id,char_index})']
 for li,line in enumerate(lines):
  assert len(line)<64
  for j,ch in enumerate(line):
   if ch!=' ':code.append(f"12'd{li*64+j}:glyph=8'd{chars.index(ch)};")
 code += ['default:glyph=0;endcase end','reg[8:0]common_glyph;always @*begin common_glyph=0;case(glyph)']
 code += [f"8'd{i}:common_glyph=9'd{union.index(ch)};" for i,ch in enumerate(chars)]
 code += ['default:common_glyph=0;endcase end','assign shared_addr={common_glyph,row};','generate if(SHARED_FONT)begin:shared_font_read','always @* bits=shared_bits;','end else begin:local_font_read','wire[11:0]a={glyph,row};reg[2:0]bank_q;','always @(posedge clk)bank_q<=a[11:9];']
 for b in range(banks):
  fn=f'{memname}_bank{b}.hex';write_hex(fn,words[b*512:(b+1)*512])
  code += [f'reg[15:0]bank{b}[0:511];reg[15:0]q{b};',f'initial $readmemh("{fn}",bank{b});',f'always @(posedge clk)q{b}<=bank{b}[a[8:0]];']
 code += ['always @*begin bits=0;case(bank_q)']+[f"3'd{b}:bits=q{b};" for b in range(banks)]+['default:bits=0;endcase end','end endgenerate','endmodule']
 (P/'rtl'/f'{name}_glyph_rom.v').write_text('\n'.join(code)+'\n',encoding='utf-8')
 (P/'reports'/f'{name}_font.json').write_text(json.dumps({'glyphs':len(chars),'bits':banks*512*16,'lines':lines},ensure_ascii=False,indent=2),encoding='utf-8')
 print(name,len(chars),banks*512*16)
def main():
 chars={name:' '+''.join(sorted(set(''.join(lines))-{' '})) for name,lines in [('menu',lcd),('vision6',hdmi)]}
 union=' '+''.join(sorted(set(''.join(chars.values()))-{' '}));assert len(union)<=512
 for name,lines in [('menu',lcd),('vision6',hdmi)]:generate(lines,name,chars[name],union)
 words=raster(union);banks=(len(words)+511)//512;words += [0]*(banks*512-len(words));write_hex('shared_font.hex',words)
 code=['// Generated dual-clock ROM banks. Both ports retain one-clock latency.','module shared_glyph_rom(input clk_hdmi,input[12:0]addr_hdmi,output reg[15:0]bits_hdmi,','input clk_lvds,input[12:0]addr_lvds,output reg[15:0]bits_lvds);','reg[3:0]hbank,lbank;always @(posedge clk_hdmi)hbank<=addr_hdmi[12:9];','always @(posedge clk_lvds)lbank<=addr_lvds[12:9];']
 for b in range(banks):
  fn=f'shared_font_bank{b}.hex';write_hex(fn,words[b*512:(b+1)*512])
  code += [f'(* ram_style="block" *)reg[15:0]bank{b}[0:511];reg[15:0]h{b},l{b};',f'initial $readmemh("{fn}",bank{b});',f'always @(posedge clk_hdmi)h{b}<=bank{b}[addr_hdmi[8:0]];',f'always @(posedge clk_lvds)l{b}<=bank{b}[addr_lvds[8:0]];']
 for port,sel,prefix in [('hdmi','hbank','h'),('lvds','lbank','l')]:
  code += [f'always @*begin bits_{port}=0;case({sel})']+[f"4'd{b}:bits_{port}={prefix}{b};" for b in range(banks)]+['default:;endcase end']
 code += ['endmodule'];(P/'rtl/shared_glyph_rom.v').write_text('\n'.join(code)+'\n',encoding='utf-8')
 (P/'reports/shared_font.json').write_text(json.dumps({'glyphs':len(union),'rows':len(words),'banks':banks,'bits':len(words)*16},indent=2))
 print('shared',len(union),'glyphs',banks,'banks')
if __name__=='__main__':main()
