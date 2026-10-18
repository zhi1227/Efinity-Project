"""Validate the IO35 migration and distinguish new tests from retained evidence."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/io35_migration'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def input_sha(path):
    if path.name != 'Ti60_Demo.xml':
        return sha(path)
    root = ET.fromstring(path.read_bytes())
    for key in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):
        root.attrib.pop(key, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()

subprocess.run([sys.executable, str(P / 'tools/verify_build.py')], check=True)
baseline = json.loads((R / 'prior_build_inputs.json').read_text())
current = json.loads((P / 'reports/vision8/build_input_sha256.json').read_text())
assert set(current) == set(baseline), 'Unexpected added/removed hardware inputs'
changed = {rel for rel in baseline if input_sha(P / rel) != baseline[rel]}
assert changed == {'example_top.v','rtl/vision8_controls.v','rtl/menu_glyph_rom.v','Ti60_Demo.peri.xml','Ti60_Demo.pt.sdc'}, changed
for rel in changed:
    before = (R / 'before' / rel).read_text(encoding='utf-8-sig')
    expected = before.replace('io34','io35').replace('IO34','IO35')
    if rel == 'Ti60_Demo.peri.xml':
        expected = expected.replace('GPIOT_N_11','GPIOT_P_11')
    if rel == 'rtl/menu_glyph_rom.v':
        for address in (2115,2179):
            expected = expected.replace(f"12'd{address}:glyph=8'd8;",f"12'd{address}:glyph=8'd9;")
    assert expected == (P / rel).read_text(encoding='utf-8-sig'), rel

ports = [e for e in ET.parse(P / 'Ti60_Demo.peri.xml').iter() if e.tag.endswith('comp_gpio')]
assert not any(e.get('name') == 'io34_button_i' for e in ports)
assert len([e for e in ports if e.get('gpio_def') == 'GPIOT_P_11']) == 1
assert 'B9,GPIOT_P_11,io35_button_i.P,Input' in (P / 'outflow/Ti60_Demo.pinout.csv').read_text()

new_tests = {
    'reports/vision8/tb_vision8_controls.log':'PASS: IO35 active-high shortcut',
    'reports/vision8/tb_io29_freeze_ddr.log':'PASS: IO29 active-low button',
    'reports/vision8/tb_menu8_pixels.log':'PASS: all eight UI modes',
    'reports/ui_refresh/tb_ui_fonts.log':'PASS: all 64 lines',
}
evidence = []
for rel, signature in new_tests.items():
    path = P / rel
    text = path.read_text(encoding='utf-8-sig', errors='replace')
    assert signature in text and 'Fatal:' not in text and 'Error:' not in text, rel
    assert path.stat().st_mtime >= (P / 'rtl/vision8_controls.v').stat().st_mtime
    evidence.append({'log':rel,'status':'PASS','sha256':sha(path),'scope':'rerun for IO35'})

# Previous full-CPU / video / HDMI tests are inherited only after proving the
# complete hardware input delta above is exactly the pin/name/two-label change.
prior = json.loads((R / 'prior_ui_validation.json').read_text(encoding='utf-8'))
inherited = [e for e in prior['tests'] if e['log'] not in new_tests]
for e in inherited:
    assert sha(P / e['log']) == e['sha256'], e['log']
    e['scope'] = 'previous UI revision; not rerun for IO35'

pixels = json.loads((R / 'pixel_equivalence.json').read_text())
assert len(pixels) == 12 and all(e['only_io_label_changed'] for e in pixels)
result = {
    'tests':evidence,'inherited_regression_tests':inherited,
    'hardware_changes':sorted(changed),
    'build':json.loads((P / 'reports/build_verified.json').read_text()),
    'io35':{'fpga_pin':'B9','gpio':'GPIOT_P_11','header':'P4 pin 40','idle':0,'pressed':1},
    'images':pixels,'physical_board_test':'not performed',
}
for path in (R / 'validation.json', P / 'reports/ui_refresh/validation.json'):
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS: IO35 B9 pin, four fresh regressions, 12 frames changed only at the IO label, exact migration delta and current bitstream verified')
