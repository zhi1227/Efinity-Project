"""Run one fresh real RISC-V/LVDS or e-paper regression without modifying firmware."""
from argparse import ArgumentParser
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
import json
import re
import shutil
import subprocess

P = Path(__file__).resolve().parents[1]


def digest(p):
    return sha256(p.read_bytes()).hexdigest()


def stamp():
    return datetime.now(timezone.utc).isoformat()


def main():
    ap = ArgumentParser(description=__doc__)
    ap.add_argument('--test', choices=('cpu8', 'epaper'), required=True)
    ap.add_argument('--vivado-bin', type=Path, default=Path('D:/Xilinx/Vivado/2018.3/bin'))
    ap.add_argument('--run-root', type=Path)
    args = ap.parse_args()
    started = stamp()
    bench = 'tb_inline_cpu8' if args.test == 'cpu8' else 'tb_inline_epd_cpu'
    marker = ('PASS: inline CPU8 all eight mode bundles, 4915200 pixels, inline threshold state, LIVE/HOLD, real CPU boot/APB, CDC, LVDS packing, frame timing'
              if args.test == 'cpu8' else
              'PASS: inline real RISC-V firmware, 30033 SPI bytes, both image planes, reset, BUSY and live eight-mode LVDS menu/state')
    rtl = ['rtl/shared_glyph_rom.v', 'vendor/EfxSapphireSoc.v', 'rtl/menu_status_cdc.v',
           'rtl/menu_glyph_rom.v', 'rtl/menu_renderer.v', 'rtl/menu8_renderer.v',
           'rtl/menu_lcd_apb.v', 'rtl/spi_write_byte.v', 'rtl/epd_apb.v', 'rtl/riscv_menu_top.v']
    sources = [*rtl, f'sim/{bench}.sv', 'tools/test_inline_cpu.py', 'image/epaper.hex']
    sources += [f.name for pattern in ('*font*.hex', '*.bin') for f in sorted(P.glob(pattern))]
    run = args.run_root or Path('D:/Github_Project/fpga_build')/('inline_'+args.test+'_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    if run.exists():
        raise RuntimeError(f'Refusing to overwrite run directory: {run}')
    run.mkdir(parents=True)
    (run/'reports').mkdir()
    report = P/'reports/inline_threshold'/args.test
    report.mkdir(parents=True, exist_ok=True)
    inputs = {}
    for rel in sources:
        target = run/rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(P/rel, target)
        inputs[rel] = digest(P/rel)
        assert digest(target) == inputs[rel]
    shutil.copy2(P/'image/epaper.hex', run/'epaper.hex')
    provenance = dict(status='RUNNING', started_utc=started, input_sha256=inputs,
                      test=args.test, stage=str(run), final_marker=marker)
    (report/'inputs.json').write_text(json.dumps(provenance, indent=2)+'\n', encoding='utf-8')

    def tool(name, extra, log):
        with log.open('w', encoding='utf-8') as out:
            r = subprocess.run([str(args.vivado_bin/(name+'.bat')), *extra], cwd=run,
                               stdout=out, stderr=subprocess.STDOUT)
        if r.returncode:
            raise RuntimeError(f'{name} failed: {log}')

    tool('xvlog', ['--sv', *rtl, f'sim/{bench}.sv'], report/'compile.log')
    tool('xelab', [bench, '-s', bench, '--relax'], report/'elab.log')
    log = report/'simulation.log'
    tool('xsim', [bench, '-runall', '-log', str(log)], report/'console.log')
    text = log.read_text(encoding='utf-8', errors='replace')
    if marker not in text or re.search(r'Fatal:|Error:|ERROR:', text):
        raise RuntimeError(f'Final completion marker missing or simulation failed: {log}')
    for rel, value in inputs.items():
        assert digest(P/rel) == value, f'Source changed during simulation: {rel}'
    result = dict(status='PASS', started_utc=started, completed_utc=stamp(),
                  test=args.test, input_sha256=inputs, stage=str(run),
                  logs=[dict(path=str(log.relative_to(P)).replace('\\','/'), sha256=digest(log), completion_marker=marker)],
                  coverage=(dict(modes=8, exact_pixels=4915200, pixels_per_mode=614400,
                                 real_riscv_firmware=True, cdc_frame_atomic=True, lvds_rgb_de_packing=True)
                            if args.test == 'cpu8' else
                            dict(spi_bytes=30033, image_planes=2, busy_wait_cycles=1200000,
                                 real_riscv_firmware=True, v8_menu_live_during_busy=True,
                                 simulated_spi_half_period=2, simulated_epd_clock_hz=100000)),
                  physical_board_test='NOT_RUN')
    (report/'results.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(marker)
    print(report/'results.json')


if __name__ == '__main__':
    main()
