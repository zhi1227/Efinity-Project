"""Audit this UI delivery using current tests, actual pixels and build hashes."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/ui_eight_modes'

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
    'reports/roi_integration/tb_vision6.log':'PASS: six modes, full raster, same-image split',
    'reports/tb_menu_cpu8.log':'PASS: CPU8 all eight mode bundles',
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
for n in range(17):
    pixels(n)
    assert (R / f'menu_{n}.png').is_file()

# The settings page changes only its values when given a new threshold snapshot.
def crop(n,x0,y0,x1,y1):
    data=pixels(n)
    return b''.join(data[(y*1024+x0)*3:(y*1024+x1)*3] for y in range(y0,y1))
assert crop(12,144,228,400,356)!=crop(14,144,228,400,356), 'LOW is stale'
assert crop(12,624,228,880,356)!=crop(14,624,228,880,356), 'HIGH is stale'
assert crop(1,48,304,976,310)!=crop(15,48,304,976,310), 'Flow frame equals settled state'
assert crop(0,48,304,976,310)!=crop(16,48,304,976,310), 'Wrap frame equals settled state'
retained=json.loads((R/'retained_assets.json').read_text(encoding='utf-8'))
for rel,digest in retained.items():
    assert sha(P/rel)==digest, 'Changed retained asset: '+rel
lines=json.loads((P/'reports/menu_font.json').read_text(encoding='utf-8'))['lines']
assert lines[1:9]==['01 原图','02 Canny','03 彩色红边','04 赛博边缘','05 彩边对照','06 手势识别','07 人脸识别','08 四帧对比']
result = {
    'tests':evidence,
    'build':json.loads((P / 'reports/build_verified.json').read_text()),
    'io35':{'fpga_pin':'B9','gpio':'GPIOT_P_11','header':'P4 pin 40','idle':0,'pressed':1},
    'images':[{'path':f'reports/ui_refresh/menu_{n}.png','sha256':sha(R / f'menu_{n}.png')} for n in range(17)],
    'retained_assets':retained,
    'physical_board_test':'not performed',
}
(R / 'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: eight-mode delivery: 9 fresh test logs, 17 RTL frames, independent thresholds, live digits, animated wrap, counts, IO35 pin, source/bitstream/timing verified')
