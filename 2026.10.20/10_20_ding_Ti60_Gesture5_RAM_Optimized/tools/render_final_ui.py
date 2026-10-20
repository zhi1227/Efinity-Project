from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parents[1]
names=['原图彩色','Canny','Sobel红边','Sobel赛博','四帧对比','阈值调节','人脸候选计数','手势识别']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
sheet=Image.new('RGB',(1024,1344),'#202020');draw=ImageDraw.Draw(sheet)
for i,name in enumerate(names):
 im=Image.open(P/f'sim_menu8_pixels/reports/menu_{i}.ppm')
 im.save(P/f'reports/vision8/menu_{i}_final.png')
 x=(i%2)*512;y=(i//2)*336
 sheet.paste(im.resize((512,300)),(x,y+36))
 draw.text((x+10,y+4),f'{i+1}. {name}',font=font,fill='white')
sheet.save(P/'reports/vision8/lvds_eight_modes_final.png')
