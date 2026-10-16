"""Validate this independent ROI merge against fresh build/tests and originals."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
E = P / 'reports/roi_integration'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_text(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def input_sha(path):
    if path.name != 'Ti60_Demo.xml':
        return sha(path)
    root = ET.fromstring(path.read_bytes())
    for key in ('last_change', 'last_run_state', 'last_run_flow', 'config_result_in_sync', 'design_ood', 'place_ood', 'route_ood'):
        root.attrib.pop(key, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()


started = datetime.fromisoformat(json.loads((E / 'run_started.json').read_text())['started_utc']).timestamp()


def fresh(path):
    assert path.is_file(), f'Missing evidence: {path}'
    assert path.stat().st_mtime >= started, f'Inherited evidence cannot prove this run: {path}'


originals = json.loads((E / 'source_trees_before.json').read_text(encoding='utf-8'))
integrity = {}
for name, record in originals.items():
    root = Path(record['path'])
    now = {f.relative_to(root).as_posix(): sha(f) for f in sorted(root.rglob('*')) if f.is_file()}
    assert now == record['files'], f'{name} original project changed'
    integrity[name] = {'path': str(root), 'unchanged_files': len(now), 'unchanged': True}

manifest_path = P / 'reports/vision8/build_input_sha256.json'
fresh(manifest_path)
manifest = json.loads(manifest_path.read_text())
main = Path(originals['main']['path'])
baseline_manifest = json.loads((main / 'reports/vision8/build_input_sha256.json').read_text())
assert set(manifest) == set(baseline_manifest), 'Production input set changed'
suffixes = ('.v', '.sv', '.vh', '.hex', '.bin', '.mem', '.xml', '.sdc')
paths = [f for directory in ('rtl', 'src', 'vendor', 'ip') for f in (P / directory).rglob('*') if f.is_file() and f.suffix.lower() in suffixes]
paths += [f for f in P.iterdir() if f.is_file() and f.suffix.lower() in ('.v', '.sv', '.vh', '.hex', '.bin', '.xml', '.sdc')]
current_inputs = {f.relative_to(P).as_posix(): input_sha(f) for f in set(paths)}
assert current_inputs == manifest, 'Build input files or hashes changed after snapshot'
changes = [rel for rel in manifest if manifest[rel] != baseline_manifest[rel]]
assert changes == ['src/parallel/gesture_config.vh'], f'Unexpected production changes: {changes}'
for directory in ('firmware', 'image'):
    for f in (main / directory).rglob('*'):
        if f.is_file():
            assert sha(f) == sha(P / f.relative_to(main)), f'{directory} changed: {f.name}'

legacy = ['tb_h5_palm', 'tb_h5_wave', 'tb_h5_raster', 'tb_h4_controls', 'tb_h4_skin', 'tb_h4_templates', 'tb_h4_overlay', 'tb_controls6', 'tb_matrix8', 'tb_vision6', 'tb_h5_ui', 'tb_i2c6', 'tb_health6', 'tb_frame_path', 'tb_menu_cdc6']
vision8 = ['tb_vision8_controls', 'tb_vision8_fifo', 'tb_vision8_ddr', 'tb_vision8_frames', 'tb_vision8_faces', 'tb_vision8_gesture', 'tb_io29_freeze_ddr', 'tb_menu8_pixels']
required = {name: f'reports/{name}.log' for name in legacy}
required.update({name: f'reports/vision8/{name}.log' for name in vision8})
required.update({'tb_menu_cpu8': 'reports/tb_menu_cpu8.log', 'tb_epd_cpu': 'reports/tb_epd_cpu.log', 'tb_shared_glyphs': 'reports/cpu_font_ram/tb_shared_glyphs.log', 'tb_shared_ui': 'reports/cpu_font_ram/tb_shared_ui.log', 'tb_cache_stress': 'reports/cpu_font_ram/tb_cache_stress.log'})
assert len(required) == 28
tests = []
for name, rel in required.items():
    path = P / rel
    fresh(path)
    content = read_text(path)
    assert 'PASS:' in content and not re.search(r'Fatal:|Error:', content), f'Test failed: {name}'
    tests.append({'name': name, 'log': rel, 'sha256': sha(path), 'pass': True})
full_log = E / 'full_regression.console.log'
fresh(full_log)
assert 'All retained-video, Vision8, real-CPU UI and e-paper regressions passed.' in read_text(full_log), 'Full regression did not finish'

roi_results_path = E / 'roi_test_results.json'
fresh(roi_results_path)
roi_results = json.loads(roi_results_path.read_text(encoding='utf-8-sig'))
# Specialized runner records its own coverage and PASS results; independently check every log.
roi_tests = roi_results.get('tests', roi_results.get('benches'))
assert isinstance(roi_tests, list) and len(roi_tests) >= 2, 'ROI tests missing'
assert {t.get('bench', t.get('name')) for t in roi_tests} == {'tb_gesture_roi_rgb', 'tb_roi_shared_overlay'}, 'Required ROI coverage missing'
for test in roi_tests:
    rel = test.get('log', test.get('log_path'))
    assert rel, f'ROI log not recorded: {test}'
    path = Path(rel)
    if not path.is_absolute():
        path = P / path
    assert path.resolve().is_relative_to(P), f'ROI evidence outside new project: {path}'
    fresh(path)
    content = read_text(path)
    assert 'PASS:' in content and not re.search(r'Fatal:|Error:', content), f'ROI test failed: {path}'

build_path = P / 'reports/build_verified.json'
fresh(build_path)
build = json.loads(build_path.read_text())
baseline = json.loads((E / 'baseline_build_verified.json').read_text())
build_log = P / 'reports/efinity_build.log'
fresh(build_log)
fresh(P / 'outflow/Ti60_Demo.route.rpt')
fresh(P / 'outflow/Ti60_Demo.timing.rpt')
for stage in ['map', 'interface', 'pnr', 'pgm']:
    assert re.search(r'^\s*' + stage + r'\s*:\s*PASS', read_text(build_log), re.M), f'Build stage failed: {stage}'
for ext in ['bit', 'hex']:
    artifact = P / f'outflow/Ti60_Demo.{ext}'
    fresh(artifact)
    assert sha(artifact) == build[f'{ext}_sha256'], f'{ext} artifact hash mismatch'
assert sha(manifest_path) == build['build_input_manifest_sha256']
assert build['min_setup_slack_ns'] >= 0 and build['min_hold_slack_ns'] >= 0, 'Timing failed'
assert build['resources']['Memory Blocks']['used'] <= 212, 'ROI change increased RAM'
assert build['resources']['DSP Blocks']['used'] == 35, 'Unexpected DSP change'

result = {'verified_utc': datetime.now(timezone.utc).isoformat(), 'original_projects': integrity,
          'production_changes': changes, 'checked_build_inputs': len(manifest),
          'baseline': baseline, 'merged': build, 'retained_regression_count': len(tests),
          'retained_regressions': tests, 'roi_results': roi_results,
          'physical_board_test': 'not performed; fresh simulation and compilation only'}
(E / 'final_validation.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({k: result[k] for k in ['original_projects', 'production_changes', 'checked_build_inputs', 'retained_regression_count', 'merged']}, ensure_ascii=False, indent=2))
