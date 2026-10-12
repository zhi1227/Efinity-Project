"""Preserve all glyph pixels/indices, split padded ROMs into 512-word banks."""
from pathlib import Path
import json
import re

P = Path(__file__).resolve().parents[1]


def compact_one(name):
    filename = 'menu_font' if name == 'menu' else 'vision6_font'
    metadata_path = P / 'reports' / f'{name}_font.json'
    rom_path = P / 'rtl' / f'{name}_glyph_rom.v'
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding='utf-8-sig'))
    else:
        count = re.search(r'Generated glyphs,\s*(\d+) characters', rom_path.read_text(encoding='utf-8-sig'))
        if not count:
            raise ValueError('Cannot recover glyph count from original generated ROM')
        metadata = {'glyphs': int(count.group(1))}
    words = [int(word, 16) for word in (P / f'{filename}.hex').read_text().split()]
    useful = metadata['glyphs'] * 16
    assert not any(words[useful:]), 'Unused glyph padding must be zero'
    banks = (useful + 511) // 512
    parts = ['// Banked glyph storage: same lookup and one-clock latency.',
             'wire[11:0] glyph_address={glyph,row};',
             'reg[2:0] selected_bank;',
             f'wire[{banks * 16 - 1}:0] bank_values;']
    for bank in range(banks):
        data = words[bank * 512:(bank + 1) * 512]
        data += [0] * (512 - len(data))
        bank_filename = f'{filename}_bank{bank}.hex'
        (P / bank_filename).write_text(''.join(f'{value:04x}\n' for value in data), encoding='ascii')
        parts.extend([f'reg[15:0] bank{bank}[0:511];', f'reg[15:0] q{bank};',
                      f'initial $readmemh("{bank_filename}",bank{bank});',
                      f'always @(posedge clk) q{bank}<=bank{bank}[glyph_address[8:0]];',
                      f'assign bank_values[{bank * 16}+:16]=q{bank};'])
    parts.extend(['always @(posedge clk) selected_bank<=glyph_address[11:9];',
                  'always @* begin bits=0; case(selected_bank)'])
    for bank in range(banks):
        parts.append(f"3'd{bank}:bits=bank_values[{bank * 16}+:16];")
    parts.extend(['default:bits=0; endcase end', 'endmodule'])
    path = rom_path
    text = path.read_text(encoding='utf-8-sig')
    marker = '// Banked glyph storage' if '// Banked glyph storage' in text else 'reg[15:0]mem'
    path.write_text(text[:text.index(marker)] + '\n'.join(parts) + '\n', encoding='utf-8')
    metadata.update({'storage_banks': banks, 'allocated_bits': banks * 512 * 16,
                     'useful_words': useful, 'storage': '512-word independent ROM banks'})
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{name}: {metadata["glyphs"]} glyphs, {banks} x 512-word ROM banks')


if __name__ == '__main__':
    compact_one('menu')
    compact_one('vision6')
