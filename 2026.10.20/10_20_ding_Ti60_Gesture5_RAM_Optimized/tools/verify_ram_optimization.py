"""Audit the preserved original, lossless data and fresh final build/regressions."""
from pathlib import Path
import hashlib
import json
import re
from ram_image_codec import unpack

P = Path(__file__).resolve().parents[1]
R = P / 'reports/ram_optimization'
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest_file = R / 'original_manifest.json'
manifest = json.loads(manifest_file.read_text())
source = Path(manifest['source'])
current = {p.relative_to(source).as_posix(): sha(p) for p in source.rglob('*') if p.is_file()}
assert current == manifest['files'], 'Original project changed'
allowed = {'src/parallel/video_delay.v', 'rtl/menu_glyph_rom.v', 'rtl/vision6_glyph_rom.v',
           'vendor/EfxSapphireSoc.v', 'vendor/provenance.json', 'Ti60_Demo.xml'}
def project_without_timestamp(path):
    return re.sub(r'last_change="\d+"', 'last_change="BUILD_TIMESTAMP"',
                  path.read_text(encoding='utf-8-sig'))
assert project_without_timestamp(source / 'Ti60_Demo.xml') == project_without_timestamp(P / 'Ti60_Demo.xml')
unchanged = []
for name, digest in current.items():
    protected = (name.startswith(('src/', 'rtl/', 'vendor/', 'ip/', 'image/')) or
                 name in {'firmware/main.c', 'firmware/start.S'} or
                 name == 'example_top.v' or ('/' not in name and name.endswith(('.xml', '.sdc'))
                    and not name.endswith('.pt.sdc')))
    if protected and name not in allowed:
        assert sha(P / name) == digest, f'Unexpected design change: {name}'
        unchanged.append(name)
encoded = bytes(int(x, 16) for x in re.findall(r'0x([0-9a-fA-F]{2})',
                (P / 'firmware/epaper_image.c').read_text()))
image = bytes(int(x, 16) for x in (source / 'image/epaper.hex').read_text().split())
assert len(image) == 15000 and unpack(encoded) == image
assert sha(P / 'image/epaper.hex') == sha(source / 'image/epaper.hex')
for prefix, count in [('menu', 6), ('vision6', 7)]:
    before = (source / f'rtl/{prefix}_glyph_rom.v').read_text()
    after = (P / f'rtl/{prefix}_glyph_rom.v').read_text()
    assert before.split('default:glyph=0;endcase end')[0] == after.split('default:glyph=0;endcase end')[0]
    raw = [int(x, 16) for x in (source / f'{prefix}_font.hex').read_text().split()]
    banks = [int(x, 16) for i in range(count)
             for x in (P / f'{prefix}_font_bank{i}.hex').read_text().split()]
    assert len(banks) == count * 512 and banks == raw[:count * 512]
    assert not any(raw[count * 512:]), 'Discarded font storage contains glyphs'
program = (P / 'firmware/build/menu.bin').read_bytes()
for lane in range(4):
    values = [int(x, 2) for x in (P / f'EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{lane}.bin').read_text().split()]
    assert len(values) == 4096
    assert bytes(values) == program.ljust(16384, b'\0')[lane::4]
link_map = (P / 'firmware/build/menu.map').read_text()
def symbol(name):
    return int(re.search(r'0x([0-9a-f]+)\s+' + name + r'\s*=', link_map).group(1), 16)
stack_free = symbol('_stack_top') - symbol('_bss_end')
assert stack_free >= 2048
benches = ['tb_h5_palm', 'tb_h5_wave', 'tb_h5_raster', 'tb_h4_controls', 'tb_h4_skin',
           'tb_h4_templates', 'tb_h4_overlay', 'tb_controls6', 'tb_matrix8', 'tb_menu_render',
           'tb_vision6', 'tb_h5_ui', 'tb_i2c6', 'tb_health6', 'tb_frame_path', 'tb_menu_cdc6',
           'tb_menu_cpu6', 'tb_epd_cpu']
logs = [P / f'reports/{b}.log' for b in benches] + [R / 'equivalence.log']
final_markers = {'tb_menu_cpu6.log': 'PASS: CPU6 all six',
                 'tb_vision6.log': 'PASS: six modes, full raster',
                 'tb_epd_cpu.log': 'PASS: real RISC-V firmware, 30033 SPI bytes',
                 'equivalence.log': 'PASS: RAM lossless equivalence'}
for log in logs:
    data = log.read_bytes()
    text = data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')
    assert 'PASS:' in text and not re.search(r'Fatal:|Error:', text), str(log)
    assert final_markers.get(log.name, 'PASS:') in text, f'Incomplete test: {log}'
    assert log.stat().st_mtime >= manifest_file.stat().st_mtime, f'Inherited log: {log}'
before = json.loads((R / 'baseline/reports/build_verified.json').read_text())
after = json.loads((P / 'reports/build_verified.json').read_text())
assert sha(source / 'outflow/Ti60_Demo.bit') == before['bit_sha256'], 'Baseline bit does not match its report'
bit = P / 'outflow/Ti60_Demo.bit'
assert sha(bit) == after['bit_sha256'] and bit.stat().st_mtime >= manifest_file.stat().st_mtime
assert after['min_setup_slack_ns'] >= 0 and after['min_hold_slack_ns'] >= 0
def ram_names(path):
    return re.findall(r'^\s*EFX_(?:DP)?RAM10\s+\\([^\s]+)', path.read_text(errors='replace'), re.M)
old_names = ram_names(source / 'outflow/Ti60_Demo.map.v')
new_names = ram_names(P / 'outflow/Ti60_Demo.map.v')
assert len(old_names) == before['resources']['Memory Blocks']['used']
assert len(new_names) == after['resources']['Memory Blocks']['used']
module_ram = []
for prefix, expected_old, expected_new in [
        ('u_menu/soc/system_ramA_logic/', 32, 16),
        ('u_menu/display/renderer/glyph/', 8, 6),
        ('u_parallel/u_overlay/font/', 8, 7),
        ('u_parallel/u_video_delay/', 19, 14),
        ('u_parallel/gray_delay/', 8, 7),
        ('u_parallel/raw_delay/', 9, 5)]:
    old_count = sum(n.startswith(prefix) for n in old_names)
    new_count = sum(n.startswith(prefix) for n in new_names)
    assert (old_count, new_count) == (expected_old, expected_new), prefix
    module_ram.append({'hierarchy': prefix, 'before': old_count, 'after': new_count})
result = {'original_project': str(source), 'optimized_project': str(P),
          'original_files_verified_unchanged': len(current),
          'protected_design_files_verified_unchanged': len(unchanged),
          'project_xml_difference_only_build_timestamp': True,
          'before': before, 'after': after,
          'ram_saved_blocks': before['resources']['Memory Blocks']['used'] - after['resources']['Memory Blocks']['used'],
          'image_raw_bytes': len(image), 'image_packed_bytes': len(encoded),
          'image_raw_sha256': hashlib.sha256(image).hexdigest(),
          'firmware_bin_bytes_before': (R / 'baseline/firmware/build/menu.bin').stat().st_size,
          'firmware_bin_bytes_after': len(program), 'firmware_stack_and_free_bytes': stack_free,
          'module_ram_blocks_from_mapped_netlists': module_ram,
          'simulation_pass_count': len(logs), 'simulation_logs': [str(p.relative_to(P)) for p in logs],
          'physical_board_test': 'not performed'}
(R / 'comparison.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(result, indent=2, ensure_ascii=False))
