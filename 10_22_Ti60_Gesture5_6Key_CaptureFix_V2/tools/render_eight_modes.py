"""Convert exact simulated RGB frames to PNG; no reconstructed mockups."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parents[1]
R=P/'reports/ui_eight_modes';R.mkdir(parents=True,exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
labels=['01 原图','02 Canny','03 彩色红边','04 赛博边缘','05 彩边对照','06 手势识别','07 人脸识别','08 四帧对比','零人','三人','人数冻结','人数无效','阈值：LOW选中','阈值：LINK / 上限','阈值：HIGH / 已更新','流水移动中','8→1环绕中']
frames=[]
for n in range(17):
 source=P/f'sim_menu8_pixels/reports/menu_{n}.ppm'
 if not source.is_file() or source.stat().st_size!=1843216: continue
 im=Image.open(source);im.load();im.save(R/f'menu_{n}.png');frames.append((n,im))
sheet=Image.new('RGB',(1024,((len(frames)+1)//2)*332),'#091224');d=ImageDraw.Draw(sheet)
for k,(n,im) in enumerate(frames):
 x=(k%2)*512;y=(k//2)*332;sheet.paste(im.resize((512,300)),(x,y));d.text((x+20,y+305),labels[n],font=font,fill='#ecf4ff')
sheet.save(R/'overview.png')
print(f'Converted {len(frames)} actual HDL frames')
