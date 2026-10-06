"""Encode the pixels emitted by the RTL HUD test as PNG, using only stdlib."""
from pathlib import Path
import struct
import zlib
root=Path(__file__).resolve().parents[1]
words=(root/'reports/hud_preview.ppm').read_text().split()
assert words[0]=='P3' and words[3]=='255'
w,h=map(int,words[1:3]);pixels=bytes(map(int,words[4:]))
assert len(pixels)==w*h*3
def chunk(name,data):
    return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
raw=b''.join(b'\0'+pixels[y*w*3:(y+1)*w*3] for y in range(h))
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
(root/'reports/hud_preview.png').write_bytes(png)
print('Encoded actual RTL HUD pixels as reports/hud_preview.png')
