from pathlib import Path
import hashlib,json,datetime
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'README.md';s=f.read_text(encoding='utf-8');s=s.replace('当前构建时序通过，正在完成最终回归与上板','五项回归及构建时序通过，已重新通过 JTAG 下载，等待此次修订的现场确认');f.write_text(s,encoding='utf-8')
sha=hashlib.sha256((P/'outflow/Ti60_Demo.bit').read_bytes()).hexdigest().upper()
f=P/'reports/board_feedback.md';s=f.read_text();s=s.replace('当前已下载诊断版 bit SHA256','上一诊断版 bit SHA256');s=s.replace('稳定性修订待最终回归和重新下载后现场确认。','稳定性修订已通过五项回归、完整构建及 JTAG 下载，等待现场确认。')
s+='\n稳定性修订 bit SHA256：'+sha+'。\n\n- 实现：XLR 13266/60800、RAM 246/256、DSP 6/160；13 个 setup/13 个 hold 时钟关系均通过，最小余量分别 +0.317 / +0.028 ns。\n- 重新读取到一颗 Ti60，JTAG ID 0x10660A79，下载日志 reports/jtag_program.log 显示完成，进程退出码 0。\n- 已请用户检查静止、缓慢移动与离开时的框连续性，以及框内白色边缘。\n';f.write_text(s,encoding='utf-8')
print('Programmed bit SHA256',sha)
manifest=json.loads((P/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((P/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in manifest['files'])
print('Verified manifest still matches all',len(manifest['files']),'files after documentation update.')
