from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
P=Path(__file__).resolve().parents[1]
lcd=[
 'VISION  六模式视觉系统','LIVE','HOLD','BOOT',
 '01 原图','02 Canny','03 彩色红边','04 赛博边缘','05 彩边对照','06 手势互动',
 '原图：摄像头彩色画面','Canny：黑底白色边缘','彩色红边：Sobel 轮廓','赛博边缘：Sobel 伪彩','对照：左彩色、右 Canny','手势互动：8x8 像素图案',
 '普通显示可开启候选计数；纯原图采样清除全部叠加。',
 '高斯、细化、双阈值及局部滞后；检测开关不改变边缘。',
 '复用原有 Sobel，在彩色画面上叠加红色轮廓。',
 '按 Sobel 幅值着色；不是彩色物体识别。',
 '同一图像左右半幅对照，保持原比例，不新增检测链。',
 '招手、点赞、单手比心；显示对应的 8x8 像素图案。',
 'M00   p 纯原图    f 候选计数',
 'M01   + / - 调整阈值',
 'M10   Sobel 红边',
 'M09   Sobel 幅值伪彩',
 'M14   g 灰度与 Sobel 对照    c 圆形矩形',
 'M15   长按 K2 录入手掌、点赞、单手比心',
 'K1 切换    K2 冻结 / 恢复    串口 t 测试彩条',
 'CFG   ACK   PCLK  VS    DDR   CAL   BUF   RGB',
]
hdmi=['01 原图','02 Canny','03 Sobel红边','04 赛博边缘','05 彩边对照','06 手势互动',
 '灰度 / Sobel','圆形 / 矩形','HDMI 测试彩条','',
 '等待手势','招手：你好','点赞：真棒','比心：爱你','8x8 像素图案',
 'CFG ACK CLK VS  DDR CAL BUF RGB ']+[f'肤色候选数：{n}' for n in range(9)]+['冻结','未启用：检查冻结状态','肤色掩膜为空','区域不合格：看诊断','处理溢出：简化背景','类别未匹配','正在确认手势','','','H5 手势模式：长按 K2 两秒重新录入三种手型。','K1 切换退出；K2 短按确认；录入后短按冻结。','WAVE','THUMB UP','HEART','手掌已找到，请左右挥动',
 '请先录入','录入手掌','录入点赞','录入比心',
 '摆好手型后短按 K2','倒计时：保持手型','正在采集掌心肤色',
 '保持不动，正在录入','肤色失败：掌心对准小框',
 '手型太相似：调整重录','轮廓不稳：检查预览重录',
 '已录入：招手需左右挥动','手部轮廓预览',
 '张开手掌，掌心盖住粉色小框，保持完整手指可见。',
 '拇指朝上，其余手指握紧；确认预览能看清拇指。',
 '单手拇指食指交叉小爱心；保持与录入时相同朝向。',
 '长按 K2 两秒开始录入','未确认张开手掌，请分开手指','手掌已确认：左右摆手','已检测摆动：向反方向摆','招手已识别','手部丢失：回到大框内']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)
def generate(lines,name):
 chars=' '+''.join(sorted(set(''.join(lines))-{' '}));assert len(chars)<=256
 depth=1
 while depth<len(chars)*16:depth*=2
 words=[0]*depth
 for n,ch in enumerate(chars):
  im=Image.new('L',(16,16));d=ImageDraw.Draw(im);box=d.textbbox((0,0),ch,font=font)
  d.text(((16-box[2]+box[0])//2-box[0],(16-box[3]+box[1])//2-box[1]),ch,font=font,fill=255)
  for y in range(16):words[n*16+y]=sum(1<<(15-x) for x in range(16) if im.getpixel((x,y))>=100)
 memname='menu_font.hex' if name=='menu' else 'vision6_font.hex'
 (P/memname).write_text('\n'.join(f'{v:04x}' for v in words)+'\n')
 code=[f'// Generated glyphs, {len(chars)} characters; no framebuffer.',
 f'module {name}_glyph_rom(input clk,input[{5 if name=='vision6' else 4}:0]line_id,input[5:0]char_index,input[3:0]row,output reg[15:0]bits);',
 'reg[7:0]glyph;always @*begin glyph=0;case({line_id,char_index})']
 for li,line in enumerate(lines):
  assert len(line)<64
  for j,ch in enumerate(line):
   if ch!=' ':code.append(f"{12 if name=='vision6' else 11}'d{li*64+j}:glyph=8'd{chars.index(ch)};")
 code+=['default:glyph=0;endcase end',f'reg[15:0]mem[0:{depth-1}];',f'initial $readmemh("{memname}",mem);',
 'always @(posedge clk)bits<=mem[{glyph,row}];','endmodule']
 (P/'rtl'/f'{name}_glyph_rom.v').write_text('\n'.join(code)+'\n')
 (P/'reports'/f'{name}_font.json').write_text(json.dumps({'glyphs':len(chars),'bits':depth*16,'lines':lines},ensure_ascii=False,indent=2),encoding='utf-8')
 print(name,len(chars),depth*16)
generate(lcd,'menu');generate(hdmi,'vision6')
