"""Read-only baseline snapshot and exact-copy proof, followed by lossless packing."""
from pathlib import Path
import hashlib
import json
import re
import shutil
from ram_image_codec import write_image

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT.parent / '10_10_liu_ Ti60_Vision6_WaveFix'
REPORT = PROJECT / 'reports/ram_optimization'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert SOURCE.resolve() != PROJECT.resolve()
    REPORT.mkdir(parents=True, exist_ok=True)
    manifest_path = REPORT / 'original_manifest.json'
    if manifest_path.exists():
        raise RuntimeError('Baseline already captured; do not reset it')
    manifest = {}
    for file in sorted(SOURCE.rglob('*')):
        if file.is_file():
            relative = file.relative_to(SOURCE).as_posix()
            sha = digest(file)
            assert digest(PROJECT / relative) == sha, relative
            manifest[relative] = sha
    manifest_path.write_text(json.dumps({'source': str(SOURCE), 'files': manifest}, indent=2), encoding='utf-8')
    for relative in ['reports/build_verified.json', 'outflow/Ti60_Demo.route.rpt',
                     'outflow/Ti60_Demo.map.rpt', 'outflow/Ti60_Demo.timing.rpt',
                     'firmware/build/menu.map', 'firmware/build/menu.bin',
                     'firmware/epaper_image.c', 'vendor/EfxSapphireSoc.v',
                     'rtl/menu_glyph_rom.v', 'rtl/vision6_glyph_rom.v',
                     'menu_font.hex', 'vision6_font.hex']:
        destination = REPORT / 'baseline' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE / relative, destination)
    image = bytes(int(value, 16) for value in re.findall(r'0x([0-9a-fA-F]{2})',
                    (SOURCE / 'firmware/epaper_image.c').read_text(encoding='ascii')))
    reference = bytes(int(line, 16) for line in (SOURCE / 'image/epaper.hex').read_text().split())
    assert image == reference and len(image) == 15000
    packed_size = write_image(PROJECT, image)
    result = {'original_files_unchanged_at_copy': len(manifest), 'image_raw_bytes': len(image),
              'image_packed_bytes': packed_size, 'image_raw_sha256': hashlib.sha256(image).hexdigest()}
    (REPORT / 'lossless_image.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
