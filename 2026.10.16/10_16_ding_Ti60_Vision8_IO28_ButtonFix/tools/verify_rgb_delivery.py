"""ding, 2026-10-15: verify this delivery, originals, new tests and build."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import csv
import json
import re
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/rgb_balance'

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def build_sha(path):
    if path.name != 'Ti60_Demo.xml':
        return sha(path)
    root = ET.fromstring(path.read_bytes())
    for key in ('last_change', 'last_run_state', 'last_run_flow',
                'config_result_in_sync', 'design_ood', 'place_ood', 'route_ood'):
        root.attrib.pop(key, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()

run = read_json(R / 'run_started.json')
started = datetime.fromisoformat(run['started_utc']).timestamp()
tests_started = started
if (R / 'tests_started.json').is_file():
    tests_started = datetime.fromisoformat(read_json(R / 'tests_started.json')['started_utc']).timestamp()
originals = []
for name in ('10_13_ding_Ti60_Vision8_Gesture_ROI_Integrated',
             '10_13_liu__Ti60_Vision8_Gesture_ROI_Integrated'):
    root = P.parent / name
    expected = read_json(P / 'reports/provenance' / (name + '.json'))
    current = {p.relative_to(root).as_posix(): sha(p)
               for p in root.rglob('*') if p.is_file()}
    assert current == expected, 'Original project changed: ' + name
    originals.append({'project': str(root), 'files': len(current),
                      'file_set_and_sha256': 'unchanged'})

baseline = read_json(P / 'reports/provenance' /
    '10_13_liu__Ti60_Vision8_Gesture_ROI_Integrated.json')
protected = {}
for rel, digest in baseline.items():
    first = rel.split('/')[0]
    if first in ('src', 'rtl', 'firmware', 'image', 'vendor', 'ip', 'tb') or (
        '/' not in rel and (rel.endswith(('.hex', '.bin', '.sdc')) or
                            rel == 'Ti60_Demo.peri.xml')):
        assert sha(P / rel) == digest, 'Retained baseline file changed: ' + rel
        protected[rel] = digest

retained_video = ('tb_h5_palm tb_h5_wave tb_h5_raster tb_h4_controls '
    'tb_h4_skin tb_h4_templates tb_h4_overlay tb_controls6 tb_matrix8 '
    'tb_vision6 tb_h5_ui tb_i2c6 tb_health6 tb_frame_path tb_menu_cdc6').split()
vision8 = ('tb_vision8_controls tb_vision8_fifo tb_vision8_ddr '
    'tb_vision8_frames tb_vision8_faces tb_vision8_gesture '
    'tb_io29_freeze_ddr').split()
logs = ['reports/' + x + '.log' for x in retained_video]
logs += ['reports/vision8/' + x + '.log' for x in vision8]
logs += ['reports/vision8/tb_menu8_pixels.log', 'reports/tb_menu_cpu8.log',
         'reports/tb_epd_cpu.log', 'reports/ui_refresh/tb_ui_fonts.log',
         'reports/cpu_font_ram/tb_cache_stress.log',
         'reports/roi_integration/tb_gesture_roi_rgb.log',
         'reports/roi_integration/tb_roi_shared_overlay.log',
         'reports/rgb_balance/tb_camera_rgb_balance.log',
         'reports/rgb_balance/configured_disabled/tb_camera_rgb_balance.log',
         'reports/rgb_balance/configured_custom/tb_camera_rgb_balance.log']
fifo = read_json(R / 'camera_fifo_results.json')
assert len(fifo['tests']) == 4, 'Missing corrected-camera/vendor-FIFO/model integration'
logs += [test['log'] for test in fifo['tests']]
tests = []
for rel in dict.fromkeys(logs):
    path = P / rel
    assert path.stat().st_mtime >= tests_started, 'Inherited or stale test: ' + rel
    data = path.read_text(encoding='utf-8-sig', errors='replace')
    assert 'PASS:' in data, 'Missing PASS: ' + rel
    assert not re.search(r'Fatal:|Error:|\$fatal|^ERROR:', data, re.M), rel
    tests.append({'log': rel, 'status': 'PASS', 'sha256': sha(path)})

build = read_json(P / 'reports/build_verified.json')
manifest_path = P / 'reports/vision8/build_input_sha256.json'
assert sha(manifest_path) == build['build_input_manifest_sha256']
inputs = read_json(manifest_path)
for rel in ('rtl/camera_rgb_balance.v', 'src/parallel/rgb_balance_config.vh'):
    assert rel in inputs, 'Missing new build input: ' + rel
for rel, digest in inputs.items():
    assert build_sha(P / rel) == digest, 'Build source drift: ' + rel
for suffix in ('bit', 'hex'):
    path = P / ('outflow/Ti60_Demo.' + suffix)
    assert path.stat().st_mtime >= started, 'Stale ' + suffix
    assert sha(path) == build[suffix + '_sha256'], 'Wrong ' + suffix
assert build['resources']['Memory Blocks']['used'] <= 230
assert build['resources']['XLRs']['used'] <= 60000
assert build['min_setup_slack_ns'] >= 0 and build['min_hold_slack_ns'] >= 0
for item in build['resources'].values():
    assert item['used'] <= item['available']
text = (P / 'reports/efinity_build.log').read_text(encoding='utf-8-sig', errors='replace')
if '\x00' in text:
    text = (P / 'reports/efinity_build.log').read_text(encoding='utf-16')
for stage in ('map', 'interface', 'pnr', 'pgm'):
    assert re.search(r'^\s*' + stage + r'\s*:\s*PASS', text, re.M), stage
pinout = P / 'outflow/Ti60_Demo.pinout.csv'
rows = list(csv.reader(pinout.read_text(encoding='utf-8-sig').splitlines()))
pins = {}
for port, ball, resource in (
    ('io28_button_i', 'C1', 'GPIOL_N_16'),
    ('io29_button_i', 'D1', 'GPIOL_P_16'),
    ('io35_button_i', 'B9', 'GPIOT_P_11'),
    ('key_mode_n', 'N2', 'GPIOL_P_02_CSI'),
    ('key_freeze_n', 'M2', 'GPIOL_N_02_CSO')):
    matches = [row for row in rows if len(row) >= 7 and row[2].split('.')[0] == port]
    assert len(matches) == 1, 'Missing or duplicate pin: ' + port
    row = matches[0]
    assert (row[0], row[1], row[3], row[6]) == (ball, resource, 'Input', '1.8 V LVCMOS'), row
    pins[port] = {'ball': ball, 'resource': resource,
                  'direction': row[3], 'standard': row[6]}

top = (P / 'example_top.v').read_text(encoding='utf-8')
for connection in ('.wframe_vsync   (balanced_camera_vs)',
                   '.wframe_data_en (balanced_camera_de)',
                   '.wframe_data    (balanced_camera_data)'):
    assert connection in top, 'Camera balance not connected to DDR'
xml = ET.fromstring((P / 'Ti60_Demo.xml').read_bytes())
assert any(n.attrib.get('name') == 'rtl/camera_rgb_balance.v' for n in xml.iter())
config = (P / 'src/parallel/rgb_balance_config.vh').read_text(encoding='utf-8')
gains = {name: int(value) for name, value in re.findall(
    r'^`define\s+RGB_BALANCE_(ENABLE|PROFILE_ENABLE|CENTER_[RGB]|EDGE_[RGB]|OUTER_[RGB]|MID_[RGB]|CORE_[RGB])\s+(\d+)\s*$', config, re.M)}
assert set(gains) == {'ENABLE', 'CENTER_R', 'CENTER_G', 'CENTER_B',
                     'EDGE_R', 'EDGE_G', 'EDGE_B', 'PROFILE_ENABLE',
                     'OUTER_R', 'OUTER_G', 'OUTER_B', 'MID_R', 'MID_G', 'MID_B',
                     'CORE_R', 'CORE_G', 'CORE_B'}, gains
assert gains['ENABLE'] in (0, 1) and gains['PROFILE_ENABLE'] in (0, 1) and all(0 <= v <= 1024 for k, v in gains.items() if k != 'ENABLE'), gains
for name in ('README.md', '工程对比报告_20261015.md', 'RGB调色与上板验收_20261015.md'):
    path = P / name
    assert path.is_file() and 'ding' in path.read_text(encoding='utf-8-sig')

result = {'author': 'ding', 'date': '2026-10-15', 'project': str(P),
          'completed_utc': datetime.now(timezone.utc).isoformat(),
          'baseline': run['baseline'], 'originals': originals,
          'retained_baseline_files': len(protected),
          'retained_baseline_manifest_sha256': hashlib.sha256(
              json.dumps(protected, sort_keys=True).encode()).hexdigest(),
          'tests': tests, 'test_count': len(tests), 'build': build,
          'fixed_rgb_gains_q8_8': gains,
          'generated_pinout': pins,
          'calibration': 'experimental coefficients; white/grey target board calibration pending',
          'hardware_programming': 'not performed', 'physical_board_test': 'not performed'}
(R / 'final_validation.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'tests_passed': len(tests), 'retained_baseline_files': len(protected),
                  'resources': build['resources'],
                  'setup_ns': build['min_setup_slack_ns'],
                  'hold_ns': build['min_hold_slack_ns'],
                  'original_projects': 'unchanged', 'physical_board_test': 'not performed'}, indent=2))
