"""Audit this RAM-optimization delivery without rewriting build evidence or originals.

Only this tool's audit JSON is written. --production-only defers simulation checks
until final_tests.json and final-source equivalence results have been finalized.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, subprocess, sys, xml.etree.ElementTree as ET

P = Path(__file__).resolve().parents[1]
R = P / 'reports/ram_optimization_20261020'
RAM_RTL = {
    'rtl/gesture_branch.v', 'rtl/shared_glyph_rom.v',
    'src/gesture/ep1_components.v', 'src/gesture/ep1_skin.v',
    'src/parallel/face_grid_regions.v', 'src/parallel/video_delay.v',
    'src/vision/line_buffer_3x3.v',
}
NEW_FONT = {f'shared_font_index_bank{i}.hex' for i in range(5)}
POST_V1 = NEW_FONT | {'rtl/shared_glyph_rom.v', 'src/vision/line_buffer_3x3.v'}
XML_VOLATILE = ('last_change', 'last_run_state', 'last_run_flow',
                'config_result_in_sync', 'design_ood', 'place_ood', 'route_ood')
HDL_EXT = {'.v', '.sv', '.vh', '.hex', '.bin', '.xml', '.sdc', '.mem'}

def require(ok, message):
    if not ok:
        raise AssertionError(message)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def text(path):
    value = path.read_text(encoding='utf-8-sig', errors='replace')
    return path.read_text(encoding='utf-16', errors='replace') if '\x00' in value else value

def inside(base, path):
    resolved = (base / path).resolve()
    require(resolved.is_relative_to(base.resolve()), f'Path escapes audited project: {path}')
    return resolved

def xml_sha(path):
    root = ET.fromstring(path.read_bytes())
    for key in XML_VOLATILE:
        root.attrib.pop(key, None)
    return hashlib.sha256(ET.tostring(root, encoding='utf-8')).hexdigest()

def is_production(name):
    parts = Path(name).parts
    return parts[0] in {'rtl', 'src', 'vendor', 'ip', 'firmware', 'image'} or (
        len(parts) == 1 and Path(name).suffix.lower() in HDL_EXT)

def category(name):
    first = name.split('/')[0]
    if is_production(name): return 'production'
    if first == 'tools': return 'verification_tools'
    if first in {'reports', 'reference'}: return 'reports_and_reference_evidence'
    if first.startswith('sim') or first == 'tb': return 'tests_and_simulation_artifacts'
    if first in {'outflow', 'work_syn', 'work_pnr', 'work_dbg'} or first.startswith(('xsim', '.Xil')):
        return 'generated_build_artifacts'
    if Path(name).suffix.lower() in {'.md', '.txt', '.pdf'}: return 'documentation'
    return 'other_nonproduction'

def compare_tree(project, original, allow_ram):
    names = {f.relative_to(project).as_posix() for f in project.rglob('*') if f.is_file()}
    protected = {n for n in original if is_production(n)}
    missing = sorted(protected - names)
    additions = sorted(n for n in names - original.keys() if is_production(n))
    modified = []
    for name in sorted(protected & names):
        if name == 'Ti60_Demo.xml':
            require(xml_sha(project/name) == xml_sha(O/name), f'Project configuration changed: {project}')
        elif sha(project/name) != original[name]:
            modified.append(name)
    require(not missing, f'Missing production files: {missing}')
    require(set(modified) == (RAM_RTL if allow_ram else set()), f'Unexpected production changes in {project.name}: {modified}')
    require(set(additions) == (NEW_FONT if allow_ram else set()), f'Unexpected production additions in {project.name}: {additions}')
    delta = {'modified': modified, 'added': additions, 'removed': missing,
             'protected_original_files': len(protected), 'project_xml': 'identical after volatile flow attributes removed'}
    if allow_ram:
        groups = {}
        for name in sorted(names | original.keys()):
            if name not in names: kind = 'removed'
            elif name not in original: kind = 'added'
            elif name == 'Ti60_Demo.xml': kind = 'flow_metadata' if sha(project/name) != original[name] else 'unchanged'
            else: kind = 'modified' if sha(project/name) != original[name] else 'unchanged'
            if kind != 'unchanged': groups.setdefault(category(name), {}).setdefault(kind, []).append(name)
        delta['all_other_deltas_classified'] = groups
    return delta

def readonly_verify_build(project, original):
    verifier = project/'tools/verify_build.py'
    require(sha(verifier) == original['tools/verify_build.py'], f'Build checker changed: {verifier}')
    # The existing checker normally writes build_verified.json. Run its exact
    # checks in a separate process, intercepting that write and requiring byte-
    # independent JSON equality with the already finalized report instead.
    code = r'''
from pathlib import Path
import json,runpy,sys
p=Path(sys.argv[1]).resolve();expected=p/'reports/build_verified.json'
saved=json.loads(expected.read_text(encoding='utf-8-sig'));writes=[]
def readonly_write(self,data,*args,**kwargs):
 if self.resolve()!=expected.resolve():raise AssertionError('Unexpected verifier write: '+str(self))
 if json.loads(data)!=saved:raise AssertionError('Existing build_verified.json is stale')
 writes.append(str(self));return len(data)
Path.write_text=readonly_write
sys.argv=[str(p/'tools/verify_build.py')]
runpy.run_path(sys.argv[0],run_name='__main__')
assert len(writes)==1,'Expected final report validation was not reached'
'''
    protected = ['reports/build_verified.json', 'reports/vision8/build_input_sha256.json',
                 'outflow/Ti60_Demo.bit', 'outflow/Ti60_Demo.hex']
    before = {n: sha(project/n) for n in protected}
    run = subprocess.run([sys.executable, '-B', '-c', code, str(project)],
                         capture_output=True, text=True, encoding='utf-8', errors='replace')
    require(run.returncode == 0, f'Read-only verify_build failed in {project}: {run.stdout}\n{run.stderr}')
    require(before == {n: sha(project/n) for n in protected}, f'Build evidence changed during audit: {project}')
    result = json.loads(run.stdout)
    result['project'] = str(project)
    result['build_input_files'] = len(read_json(project/'reports/vision8/build_input_sha256.json'))
    result['verification_method'] = 'Exact existing verify_build.py in subprocess; sole report write intercepted and compared, not performed'
    return result

def proof(path, marker, original):
    data = read_json(P/path)
    require(data.get('result') == 'PASS', f'Equivalence did not pass: {path}')
    optimized = data.get('optimized_sha256', {})
    require(bool(optimized), f'Proof lacks final source hashes; rerun its test: {path}')
    for name, digest in optimized.items():
        require(sha(inside(P, name)) == digest, f'Proof source changed: {name} in {path}')
    for name, digest in data.get('baseline_sha256', {}).items():
        require(original.get(name) == digest, f'Proof baseline is not original: {name}')
    for name, digest in data.get('reference_sha256', {}).items():
        require(sha(inside(P, name)) == digest, f'Proof reference changed: {name}')
        if name in original:
            require(original[name] == digest, f'Original pixel reference changed: {name}')
    if data.get('baseline_reference_rtl_sha256'):
        require(data['baseline_reference_rtl_sha256'] == original['rtl/shared_glyph_rom.v'], 'Font reference RTL is not original')
    for field in ('bench', 'log'):
        require(sha(inside(P, data[field])) == data[field+'_sha256'], f'Proof {field} changed: {path}')
    log = text(inside(P, data['log']))
    require(marker in log and not re.search(r'Fatal:|Error:|FATAL|ERROR:', log), f'Proof log failed: {path}')
    if data.get('reference_manifest'):
        require(sha(inside(P, data['reference_manifest'])) == data['reference_manifest_sha256'], 'Font reference manifest changed')
    return {'result': 'PASS', 'result_file': path, 'result_sha256': sha(P/path),
            'optimized_sha256': optimized, 'bench': data['bench'], 'log': data['log'],
            'log_sha256': data['log_sha256'], 'coverage': data.get('coverage', {
                k: data[k] for k in ('clocks','line_configurations','window7_widths','delay_configurations','face_grids','ccl_modes') if k in data})}

def audit_tests(original):
    manifest_path = P/'reports/ramopt_regression/final_tests.json'
    data = read_json(manifest_path)
    items = data['tests']
    require(len(items) == data['test_count'] and len(items) >= 29, 'Incomplete test manifest')
    names = [entry['name'] for entry in items]
    require(len(names) == len(set(names)), 'Duplicate test names')
    required = {'tb_gesture5_rgb_ramopt','tb_gesture5_templates_ramopt','tb_gesture5_controls_new',
                'tb_cache_stress','tb_menu_cpu8','tb_epd_cpu','tb_vision8_faces','tb_vision8_ddr','tb_io29_freeze_ddr'}
    require(required <= set(names), f'Missing retained-function tests: {sorted(required-set(names))}')
    registry = data.get('source_manifests', {})
    require({'v1','final'} <= registry.keys(), 'Both independently hashed source phase manifests are required')
    phase_inputs = {}
    for phase in ('v1','final'):
        record = registry[phase]
        path = inside(P, record['path'])
        require(sha(path) == record['sha256'], f'{phase} source manifest changed')
        phase_inputs[phase] = read_json(path)
    current = read_json(P/'reports/vision8/build_input_sha256.json')
    require(phase_inputs['final'] == current, 'Final test phase manifest differs from the final verified build inputs')
    archived = P/'reports/ramopt_regression/v1_inputs'
    for name, digest in phase_inputs['v1'].items():
        saved = inside(archived, name)
        actual = xml_sha(saved) if name == 'Ti60_Demo.xml' else sha(saved)
        require(actual == digest, f'Archived V1 production input changed: {name}')
    isolation_path = P/'reports/ramopt_regression/v1_epd_isolation.json'
    isolation = read_json(isolation_path)
    require(isolation.get('completed') == 'PASS' and
            isolation.get('all_runtime_assets_and_compiled_snapshot_unchanged_at_end') is True,
            'V1 isolated EPD did not finish with immutable inputs')
    for group in ('runtime_assets', 'compiled_snapshot_sha256'):
        require(bool(isolation.get(group)), f'Missing EPD isolation hashes: {group}')
        for name, digest in isolation[group].items():
            require(sha(inside(P, name)) == digest, f'Isolated V1 EPD input changed: {name}')
    require(data['source_manifest'] == registry['final']['path'] and
            data['source_manifest_sha256'] == registry['final']['sha256'], 'Top-level final phase binding differs from its registry')
    unchanged_cpu = sorted(n for n in phase_inputs['v1'] if n.startswith('vendor/') or
        (n.startswith('EfxSapphireSoc') and n.endswith('.bin')) or n in {
            'rtl/riscv_menu_top.v','rtl/menu_lcd_apb.v','rtl/epd_apb.v','rtl/spi_write_byte.v',
            'rtl/menu_status_cdc.v','rtl/menu8_renderer.v','rtl/menu_renderer.v'})
    require(bool(unchanged_cpu), 'CPU composition evidence is empty')
    for name in unchanged_cpu:
        require(phase_inputs['v1'][name] == phase_inputs['final'].get(name), f'V1 CPU/EPD composition input changed: {name}')
    phases = {}
    for entry in items:
        require(entry['status'] == 'PASS', f'Test not passed: {entry["name"]}')
        log = inside(P, entry['log'])
        require(sha(log) == entry['sha256'], f'Test log changed: {entry["name"]}')
        value = text(log)
        require('PASS:' in value and not re.search(r'Fatal:|Error:|FATAL|ERROR:', value), f'Test log failure: {entry["name"]}')
        if entry.get('bench'):
            require(sha(inside(P,entry['bench'])) == entry['bench_sha256'], f'Test bench changed: {entry["name"]}')
        phase = entry.get('source_phase', 'unspecified')
        require(phase in {'v1','final'}, f'Unspecified test source phase: {entry["name"]}')
        record = registry[phase]
        require(entry.get('source_manifest') == record['path'] and
                entry.get('source_manifest_sha256',entry.get('source_sha256')) == record['sha256'],
                f'Test is not bound to its own source phase manifest: {entry["name"]}')
        if phase == 'v1':
            require(entry['name'] in {'tb_cache_stress','tb_menu_cpu8','tb_epd_cpu'},
                    f'Only explicitly composed unchanged CPU/EPD tests may retain V1 runtime: {entry["name"]}')
        phases[phase] = phases.get(phase,0)+1
    tested = phase_inputs['v1']
    changed = sorted(n for n in current.keys() | tested.keys() if current.get(n) != tested.get(n))
    proofs = {
        'buffers': proof('reports/ramopt_buffers/results.json','PASS: RAM buffers exact equivalence',original),
        'coordinates': proof('reports/ramopt_coordinates/results.json','PASS: coordinate RAM exact equivalence',original),
        'fonts': proof('reports/ram_optimization_20261020/font/results.json','PASS: compressed shared font',original),
        'wide_lines': proof('reports/ramopt_wide_lines/results.json','PASS: wide banked line cycle-exact equivalence',original),
    }
    require({'src/vision/line_buffer_3x3.v','src/gesture/ep1_skin.v','src/parallel/video_delay.v'} <= proofs['buffers']['optimized_sha256'].keys(), 'Incomplete buffer proof')
    require({'src/gesture/ep1_components.v','src/parallel/face_grid_regions.v'} <= proofs['coordinates']['optimized_sha256'].keys(), 'Incomplete coordinate proof')
    require(NEW_FONT | {'rtl/shared_glyph_rom.v'} <= proofs['fonts']['optimized_sha256'].keys(), 'Incomplete font proof')
    allowed_bridge = POST_V1.copy()
    # An optional final BFS layout substitution is allowed only after its
    # complete original-vs-final coordinate proof has been hash-validated.
    if 'src/parallel/face_grid_regions.v' in proofs['coordinates']['optimized_sha256']:
        allowed_bridge.add('src/parallel/face_grid_regions.v')
    require(set(changed) <= allowed_bridge, f'Functional test sources diverged beyond proven final lossless substitutions: {changed}')
    return {'result': 'PASS', 'manifest': manifest_path.relative_to(P).as_posix(),
            'manifest_sha256': sha(manifest_path), 'test_count': len(items), 'source_phases': phases,
            'source_manifests_verified_independently': registry,
            'v1_archive_integrity': {'result':'PASS', 'production_inputs':len(phase_inputs['v1']),
                'isolated_runtime_assets':len(isolation['runtime_assets']),
                'isolated_compiled_snapshot_files':len(isolation['compiled_snapshot_sha256']),
                'isolation_manifest_sha256':sha(isolation_path)},
            'unchanged_cpu_epd_inputs': unchanged_cpu,
            'functional_manifest_diff_from_final': changed,
            'phase_policy': 'Only three unchanged CPU/cache/EPD V1 runtimes are composed explicitly; every test binds its own phase manifest; final line/font/BFS substitutions require final-source cycle-exact equivalence',
            'equivalence_proofs': proofs}

def main():
    global O
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--production-only', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output or R/('production_audit.json' if args.production_only else 'delivery_audit.json')
    output = output.resolve()
    require(output.is_relative_to((P/'reports').resolve()), 'Audit output must stay within this project reports/')
    report = {'started_utc': datetime.now(timezone.utc).isoformat(), 'project': str(P),
              'audit_mode': 'production-only' if args.production_only else 'full-delivery',
              'hardware_validation': 'not performed', 'only_written_file': str(output)}
    try:
        snapshot = read_json(R/'original_before.json')
        O = Path(snapshot['path']).resolve()
        original = snapshot['files']
        actual = {f.relative_to(O).as_posix(): sha(f) for f in O.rglob('*') if f.is_file()}
        require(actual == original, 'Original file set or bytes changed after initial copy')
        report['original_preservation'] = {'result': 'PASS', 'path': str(O), 'raw_files': len(actual),
                                           'manifest_sha256': sha(R/'original_before.json')}
        baseline = Path(read_json(R/'run.json')['baseline_build']).resolve()
        report['baseline_source_preservation'] = compare_tree(baseline, original, False)
        report['optimized_source_whitelist'] = compare_tree(P, original, True)
        report['baseline_build'] = readonly_verify_build(baseline, original)
        report['optimized_build'] = readonly_verify_build(P, original)
        comparison = {}
        for name, before in report['baseline_build']['resources'].items():
            after = report['optimized_build']['resources'][name]
            comparison[name] = {'before': before['used'], 'after': after['used'],
                                'delta': after['used']-before['used'], 'available': after['available']}
        require(comparison['Memory Blocks']['delta'] < 0, 'RAM optimization did not reduce final routed RAM')
        report['resource_comparison'] = comparison
        report['tests'] = {'status': 'deferred; production-only mode'} if args.production_only else audit_tests(original)
        # Also prove no original changed during the audit itself.
        final_original = {f.relative_to(O).as_posix(): sha(f) for f in O.rglob('*') if f.is_file()}
        require(final_original == original, 'Original changed during audit')
        report['result'] = 'PASS'
        report['status'] = 'PASS'
    except Exception as error:
        report['result'] = 'FAIL'
        report['status'] = 'FAIL'
        report['error'] = f'{type(error).__name__}: {error}'
    report['ended_utc'] = datetime.now(timezone.utc).isoformat()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'result': report['result'], 'audit': str(output), 'error': report.get('error'),
                      'resource_comparison': report.get('resource_comparison')}, ensure_ascii=True, indent=2))
    return 0 if report['result'] == 'PASS' else 1

if __name__ == '__main__':
    sys.exit(main())
