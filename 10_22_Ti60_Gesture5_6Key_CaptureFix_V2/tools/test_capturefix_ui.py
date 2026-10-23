"""Fresh ASCII-stage XSim validation of the inline menu and lossless font ROM.

Does not run any historical prepare_* generator and never programs the FPGA.
"""
from argparse import ArgumentParser
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
import json
import re
import shutil
import subprocess
from PIL import Image, ImageDraw

P = Path(__file__).resolve().parents[1]


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def now():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--vivado-bin', type=Path, default=Path('D:/Xilinx/Vivado/2018.3/bin'))
    parser.add_argument('--baseline', type=Path, default=P.parent/'10_20_ding_Ti60_Gesture5_4Key_InlineThreshold')
    parser.add_argument('--run-root', type=Path)
    args = parser.parse_args()
    started = now()
    run = args.run_root or Path('D:/Github_Project/fpga_build')/('capturefix_ui_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    if run.exists():
        raise RuntimeError(f'Refusing to overwrite an existing run: {run}')
    run.mkdir(parents=True)
    report = P/'reports/capture_fix/ui'
    report.mkdir(parents=True, exist_ok=True)
    (run/'reports').mkdir()
    sources = ['src/parallel/vision8_modes.vh', 'rtl/shared_glyph_rom.v', 'rtl/menu_glyph_rom.v',
               'rtl/menu8_renderer.v', 'rtl/vision6_glyph_rom.v',
               'sim/tb_fourkey_font.sv', 'sim/tb_capturefix_menu.sv',
               'tools/generate_font.py', 'tools/hdmi_text.json',
               'tools/compress_shared_font_ram.py', 'tools/test_capturefix_ui.py']
    sources += [f.name for f in sorted(P.glob('*font*.hex'))]
    hashes = {}
    for rel in sources:
        target = run/rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(P/rel, target)
        hashes[rel] = digest(P/rel)
        assert digest(target) == hashes[rel]
    words = [int(v, 16) for v in (P/'shared_font.hex').read_text().split()]
    assert len(words) == 4608
    words += [0]*(8192-len(words))
    expected = run/'shared_font_expected_8192.hex'
    expected.write_text(''.join(f'{v:04x}\n' for v in words), encoding='ascii')
    # Independent checks retain the previous glyph pixels for every character
    # still used by this UI, even though their sorted glyph addresses changed.
    def union(project):
        lines = json.loads((project/'reports/menu_font.json').read_text(encoding='utf-8'))['lines']
        hdmi = json.loads((project/'tools/hdmi_text.json').read_text(encoding='utf-8'))
        return ' '+''.join(sorted(set(''.join(lines+hdmi))-{' '}))
    old_chars, new_chars = union(args.baseline), union(P)
    old_words = [int(v,16) for v in (args.baseline/'shared_font.hex').read_text().split()]
    common = sorted(set(old_chars)&set(new_chars))
    for ch in common:
        old_row, new_row = old_chars.index(ch)*16, new_chars.index(ch)*16
        assert old_words[old_row:old_row+16] == words[new_row:new_row+16], repr(ch)
    # Source metadata must contain the real new instructions, without K1/K2 or
    # any old settings-page strings. This validates what generated ROM contains.
    lcd = json.loads((P/'reports/menu_font.json').read_text(encoding='utf-8'))['lines']
    hdmi = json.loads((P/'tools/hdmi_text.json').read_text(encoding='utf-8'))
    assert lcd[32] == '阈值 T' and lcd[33] == 'IO34 减小 / IO35 增大'
    assert 'IO34' in lcd[29] and 'IO34' in lcd[31]
    assert lcd[36]=='LOW' and lcd[37]=='HIGH' and 'K2' in lcd[61]
    write_json(report/'inputs.json', dict(started_utc=started, run_root=str(run),
               input_sha256=hashes, expected_8192_sha256=digest(expected),
               unchanged_glyph_characters=len(common), baseline_shared_sha256=digest(args.baseline/'shared_font.hex')))

    def tool(name, arguments, logfile):
        with logfile.open('w', encoding='utf-8') as out:
            result = subprocess.run([str(args.vivado_bin/(name+'.bat')), *arguments], cwd=run,
                                    stdout=out, stderr=subprocess.STDOUT, text=True)
        if result.returncode:
            raise RuntimeError(f'{name} failed, see {logfile}')

    checks = []
    benches = [
        ('font', ['rtl/shared_glyph_rom.v', 'sim/tb_fourkey_font.sv'], 'tb_fourkey_font',
         'PASS: fourkey compressed font all 8192 addresses and 12000 seeded random reads per port; 646144 exact pixels; independent HDMI/LVDS one-edge latency'),
        ('menu', ['rtl/shared_glyph_rom.v', 'rtl/menu_glyph_rom.v', 'rtl/menu8_renderer.v', 'sim/tb_capturefix_menu.sv'], 'tb_capturefix_menu',
         'PASS: capturefix UI all 8 modes plus 4 threshold limit/step/freeze crops; 5301248 pixels; inline digits and actions; capture Canny LOW/HIGH; shared/local parity; retired settings bit ignored; rail timing/wrap')]
    for label, files, bench, marker in benches:
        tool('xvlog', ['--sv', '-i', 'src/parallel', *files], report/(label+'_compile.log'))
        tool('xelab', [bench, '-s', bench, '--relax'], report/(label+'_elab.log'))
        log = report/(label+'_simulation.log')
        tool('xsim', [bench, '-runall', '-log', str(log)], report/(label+'_console.log'))
        text = log.read_text(encoding='utf-8', errors='replace')
        if marker not in text or re.search(r'Fatal:|Error:|ERROR:', text):
            raise RuntimeError(f'{label} did not complete successfully: {log}')
        checks.append(dict(name=label, path=str(log.relative_to(P)).replace('\\','/'), sha256=digest(log), completion_marker=marker))
        print(marker, flush=True)
    for rel, expected_sha in hashes.items():
        assert digest(P/rel) == expected_sha, f'Source changed during simulation: {rel}'
    for i in range(12):
        image = Image.open(run/'reports'/f'menu_{i}.ppm')
        image.save(report/f'menu_{i}.png')
    sheet = Image.new('RGB', (1024, 4*330), '#0a1224')
    draw = ImageDraw.Draw(sheet)
    for i in range(8):
        im = Image.open(report/f'menu_{i}.png').resize((512,300))
        xx, yy = (i%2)*512, (i//2)*330
        sheet.paste(im, (xx,yy+24))
        draw.text((xx+8, yy+5), f'RTL simulation: mode {i+1}', fill='white')
    sheet.save(report/'eight_modes_rtl.png')
    result = dict(status='PASS', started_utc=started, completed_utc=now(),
                  input_sha256=hashes, logs=checks, run_root=str(run),
                  coverage=dict(full_modes=8, threshold_crops=4, ui_pixels=5301248,
                                font_addresses_per_port=8192, random_rows_per_port=12000,
                                font_exact_pixels=646144, unchanged_glyph_characters=len(common),
                                shared_font_latency_clocks=1, independent_font_clock_ports=2,
                                legacy_settings_bit_ignored=True, shared_local_pixel_parity=True))
    write_json(report/'results.json', result)
    print(json.dumps(dict(status='PASS', report=str(report/'results.json')), ensure_ascii=False))


if __name__ == '__main__':
    main()
