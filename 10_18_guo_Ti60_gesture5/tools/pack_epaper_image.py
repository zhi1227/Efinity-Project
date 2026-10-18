"""Pack image/character_calligraphy_source.png into 400x300 monochrome firmware data."""
from pathlib import Path
from PIL import Image
from ram_image_codec import write_image
P=Path(__file__).resolve().parents[1]
im=Image.open(P/'image/character_calligraphy_source.png').convert('L').resize((400,300),Image.Resampling.LANCZOS)
im=im.point(lambda x:255 if x>=160 else 0,mode='1')
im.save(P/'image/epaper_preview.png')
data=im.tobytes()
assert len(data)==15000
(P/'image/epaper.hex').write_text(''.join(f'{b:02x}\n' for b in data),encoding='ascii')
size=write_image(P,data)
print(f'Losslessly packed 15000 bytes into {size} bytes, MSB first, 1=white. Rebuild firmware then FPGA.')
