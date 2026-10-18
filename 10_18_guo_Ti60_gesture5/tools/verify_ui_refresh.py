"""Audit this UI delivery using current tests, actual pixels and build hashes."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/ui_refresh'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

subprocess.run([sys.executable, str(P / 'tools/verify_build.py')], check=True)
tests = {
    'reports/vision8/tb_vision8_controls.log':'PASS: IO35 active-high shortcut',
    'reports/vision8/tb_vision8_faces.log':'PASS: real CCL nine separated regions',
    'reports/vision8/tb_vision8_frames.log':'PASS: frame-bound PiP/compare compositor',
    'reports/vision8/tb_io29_freeze_ddr.log':'PASS: IO29 active-low button',
    'reports/vision8/tb_menu8_pixels.log':'PASS: all eight UI modes',
    'reports/ui_refresh/tb_ui_fonts.log':'PASS: all 64 lines',
    'reports/roi_integration/tb_roi_shared_overlay.log':'PASS: HDMI diagnostics removed',
    'reports/tb_menu_cpu8.log':'PASS: CPU8 all eight menu modes',
}
evidence = []
for rel, signature in tests.items():
    path = P / rel
    text = path.read_text(encoding='utf-8-sig', errors='replace')
    assert signature in text and 'Fatal:' not in text and 'Error:' not in text, rel
    assert path.stat().st_mtime >= (P / 'rtl/vision8_controls.v').stat().st_mtime, f'Stale log: {rel}'
    evidence.append({'log':rel, 'status':'PASS', 'sha256':sha(path)})

ns = {'p':'http://www.efinixinc.com/peri_design_db'}
tree = ET.parse(P / 'Ti60_Demo.peri.xml')
ports = [e for e in tree.iter() if e.tag.endswith('comp_gpio') and e.get('name') == 'io35_button_i']
assert len(ports) == 1 and ports[0].get('gpio_def') == 'GPIOT_P_11'
assert 'B9,GPIOT_P_11,io35_button_i.P,Input' in (P / 'outflow/Ti60_Demo.pinout.csv').read_text()

# PPMs are the exact RGB stream captured by the HDL testbench.
def pixels(n):
    data = (P / f'sim_menu8_pixels/reports/menu_{n}.ppm').read_bytes()
    header = b'P6\n1024 600\n255\n'
    assert data.startswith(header) and len(data) == len(header)+1024*600*3
    return data[len(header):]

def count_crop(n):
    data = pixels(n)
    return b''.join(data[(y*1024+432)*3:(y*1024+560)*3] for y in range(390,454))

assert count_crop(9) == count_crop(10), 'Frozen count changed'
assert len({count_crop(n) for n in (6,8,9,11)}) == 4, '8+, zero, three and invalid must differ'
for n in range(12):
    pixels(n)
    assert (R / f'menu_{n}.png').is_file()

result = {
    'tests':evidence,
    'build':json.loads((P / 'reports/build_verified.json').read_text()),
    'io35':{'fpga_pin':'B9','gpio':'GPIOT_P_11','header':'P4 pin 40','idle':0,'pressed':1},
    'images':[{'path':f'reports/ui_refresh/menu_{n}.png','sha256':sha(R / f'menu_{n}.png')} for n in range(12)],
    'retained_assets':json.loads((R / 'retained_assets.json').read_text(encoding='utf-8')),
    'physical_board_test':'not performed',
}
(R / 'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: UI refresh delivery: 8 test logs, 12 frames, frozen/invalid counts, IO35 pin, current source/bitstream and timing verified')
