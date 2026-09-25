"""Read actual XSim VCD, independently check frame-slot safety and video delay.
Writes derived JSON and an SVG waveform, never edits RTL or input recordings.
"""
import json
from collections import deque
from pathlib import Path
import argparse

def snapshots(path):
    symbols, state, scopes = {}, {}, []
    time = 0
    body = False
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            line = line.strip()
            if line.startswith('$scope'):
                scopes.append(line.split()[2])
            elif line.startswith('$upscope'):
                scopes.pop()
            elif line.startswith('$var'):
                p = line.split()
                symbols[p[3]] = '.'.join(scopes + [p[4]])
            elif line.startswith('$enddefinitions'):
                body = True
            elif body and line.startswith('#'):
                yield time, state.copy()
                time = int(line[1:])
            elif body and line and line[0] in '01xz':
                state[symbols[line[1:]]] = int(line[0]) if line[0] in '01' else None
            elif body and line.startswith('b'):
                value, key = line[1:].split()
                state[symbols[key]] = None if any(c in value for c in 'xz') else int(value, 2)
        yield time, state.copy()

def freeze_check(path):
    previous = {}
    transitions, traces = [], []
    checks = 0
    for t, state in snapshots(path):
        s = {k.split('.')[-1]: v for k, v in state.items()}
        if t <= 3_000_000:
            traces.append((t / 1000, s))
        if s.get('clk') == 1 and previous.get('clk') == 0 and s.get('reset') == 0:
            assert s['ws'] != s['rs'], (t, 'writer/display collision')
            if s['rs'] != previous['rs']:
                assert s['rd'] == 1, (t, 'slot changed outside reader boundary')
            if s['frozen'] != previous['frozen']:
                assert s['rd'] == 1, (t, 'freeze changed outside reader boundary')
                transitions.append({'time_ns': t / 1000, 'frozen': s['frozen'], 'read_slot': s['rs']})
            if previous['frozen'] and s['frozen']:
                assert s['rs'] == previous['rs'], (t, 'held frame changed')
            checks += 1
        previous = s
    assert checks > 2000 and len(transitions) >= 3
    return {'cycles_checked': checks, 'transitions': transitions}, traces

def video_check(path, delay):
    previous = {}
    queue = deque()
    raster, coords = 0, 0
    for t, s in snapshots(path):
        root = 'tb_contest_video.'
        def get(name):
            return s.get(root + name)
        if get('clk') == 1 and previous.get(root + 'clk') == 0:
            if not get('rst'):
                queue.clear()
            else:
                queue.append(tuple(get(k) for k in ('vs', 'hs', 'de')))
                if len(queue) > delay:
                    expected = queue.popleft()
                    actual = tuple(get(k) for k in ('ov', 'oh', 'od'))
                    assert actual == expected, (t, actual, expected)
                    raster += 1
                if get('dut.cv'):
                    assert get('dut.ade') and get('dut.ex') == get('dut.ax') and get('dut.ey') == get('dut.ay'), t
                    coords += 1
        previous = s
    assert raster > 20000 and coords > 1000
    return {'delay_cycles_before_overlay': delay, 'raster_cycles_checked': raster, 'canny_coordinates_checked': coords}

def plot(traces, output):
    names = ['key_n', 'request', 'rd', 'wr', 'frozen', 'rs', 'ws']
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="465" viewBox="0 0 1200 465">',
           '<rect width="1200" height="465" fill="#101827"/>',
           '<g font-family="monospace" font-size="14" fill="#dce8ef">',
           '<text x="20" y="26">Actual XSim waveform: K2 freeze / DDR frame slots (first 3000 ns)</text>']
    scale = 1020 / 3000
    for i, name in enumerate(names):
        base = 90 + i * 48
        svg.append(f'<text x="18" y="{base}">{name}</text>')
        points = []
        last = None
        for time, state in traces:
            value = state.get(name)
            if value is None:
                continue
            xx = 140 + time * scale
            yy = base - 20 * value / (3 if name in ('rs', 'ws') else 1)
            if last is not None and value != last[1]:
                points.append(f'{xx:.1f},{last[0]:.1f}')
            points.append(f'{xx:.1f},{yy:.1f}')
            if name in ('rs', 'ws') and (last is None or value != last[1]):
                svg.append(f'<text x="{xx+3:.1f}" y="{yy-3:.1f}" font-size="10">{value}</text>')
            last = yy, value
        svg.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="#38d8bd" stroke-width="1.5"/>')
    for t in range(0, 3001, 500):
        xx = 140 + t * scale
        svg.append(f'<text x="{xx}" y="438">{t}</text>')
    svg += ['<text x="20" y="438">time/ns</text>', '</g></svg>']
    output.write_text('\n'.join(svg), encoding='utf-8')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    freeze, traces = freeze_check(args.directory / 'freeze.vcd')
    video = video_check(args.directory / 'video_alignment.vcd', 658)
    result = {'status': 'PASS', 'source': 'recorded VCD, not generated expected traces', 'freeze': freeze, 'video': video}
    (args.directory / 'wave_audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    plot(traces, args.directory / 'freeze_waveform.svg')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
