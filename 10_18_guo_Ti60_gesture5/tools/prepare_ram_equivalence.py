"""Create read-only reference modules from the original snapshot for simulation."""
from pathlib import Path
import hashlib
import json

P = Path(__file__).resolve().parents[1]
manifest = json.loads((P / 'reports/ram_optimization/original_manifest.json').read_text())
source = Path(manifest['source'])
for module, relative in [('video_delay', 'src/parallel/video_delay.v'),
                         ('menu_glyph_rom', 'rtl/menu_glyph_rom.v'),
                         ('vision6_glyph_rom', 'rtl/vision6_glyph_rom.v')]:
    data = (source / relative).read_bytes()
    assert hashlib.sha256(data).hexdigest() == manifest['files'][relative]
    text = data.decode('utf-8-sig')
    text = text.replace('module ' + module, 'module ' + module + '_baseline', 1)
    (P / 'sim' / f'ram_baseline_{module}.v').write_text(text, encoding='utf-8')
print('Reference modules generated from verified original files; originals untouched.')
