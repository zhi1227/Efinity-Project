"""Lossless byte PackBits codec for the existing 400x300 image; no frame buffer."""
from pathlib import Path


def pack(data: bytes) -> bytes:
    result = bytearray()
    position = 0
    while position < len(data):
        count = 1
        while count < 128 and position + count < len(data) and data[position + count] == data[position]:
            count += 1
        if count >= 3:
            result.extend((0x80 | (count - 1), data[position]))
            position += count
            continue
        begin = position
        position += count
        while position < len(data) and position - begin < 128:
            count = 1
            while count < 3 and position + count < len(data) and data[position + count] == data[position]:
                count += 1
            if count >= 3:
                break
            position += min(count, 128 - (position - begin))
        result.append(position - begin - 1)
        result.extend(data[begin:position])
    return bytes(result)


def unpack(data: bytes) -> bytes:
    result = bytearray()
    position = 0
    while position < len(data):
        control = data[position]
        position += 1
        count = (control & 0x7f) + 1
        if control & 0x80:
            if position >= len(data):
                raise ValueError('Missing repeated byte')
            result.extend(bytes((data[position],)) * count)
            position += 1
        else:
            if position + count > len(data):
                raise ValueError('Truncated literal')
            result.extend(data[position:position + count])
            position += count
    return bytes(result)


def write_image(project: Path, data: bytes) -> int:
    if len(data) != 15000:
        raise ValueError('Expected exactly 400x300/8 bytes')
    encoded = pack(data)
    assert unpack(encoded) == data
    rows = [', '.join(f'0x{value:02x}' for value in encoded[start:start + 20])
            for start in range(0, len(encoded), 20)]
    text = ('// Generated lossless byte RLE. Regenerate with tools/pack_epaper_image.py.\n'
            '#include "epaper.h"\n'
            f'const uint16_t epaper_image_packed_size = {len(encoded)};\n'
            f'const uint8_t epaper_image_packed[{len(encoded)}] = {{\n'
            + ',\n'.join(rows) + '\n};\n')
    (project / 'firmware/epaper_image.c').write_text(text, encoding='ascii')
    return len(encoded)
