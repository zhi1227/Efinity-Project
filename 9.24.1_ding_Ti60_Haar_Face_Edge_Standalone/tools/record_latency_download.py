from pathlib import Path
import hashlib,json
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
sha=hashlib.sha256((P/'outflow/Ti60_Demo.bit').read_bytes()).hexdigest().upper()
f=P/'README.md';s=f.read_text(encoding='utf-8');s=s.replace('当前完整构建已通过，最终回归及本次上板效果正在确认','七项回归和完整构建均已通过，已通过 JTAG 下载，首次出框与近距离现场效果待确认')
s=s.replace('7. `reports/build.log`','7. `sim/tb_haar_near.log`：完整 720p 输入的大脸样本经过 RGB565、均值缩图与 Haar 后，显示框宽度超过旧版 384 像素上限；后续空场景清框和采集边界检查通过。\n8. `reports/build.log`').replace('8. JTAG 下载结果','9. JTAG 下载结果')
f.write_text(s,encoding='utf-8')
f=P/'reports/board_feedback.md';s=f.read_text(encoding='utf-8');s+='''
## 首次响应与近距离修订

- 用户补充：无遮挡正脸首次出现框通常超过 3 秒，偶尔一直不出；靠近摄像头后也可能无法检出。
- 新版保留完整 25 级接受条件和原有框保持逻辑，加入四种起点偏移轮换、8×8 均值缩图、连续四角读取，以及新候选提前发布。
- 检测窗口由 192～384 像素扩展至 192～672 像素，共 13 个尺度；脸部被画面裁切仍不属于完整正脸保证范围。
- 7 项完整仿真全部通过，包括 12 轮相位/大脸/空场景软件比对，以及大脸样本的完整视频显示与清框；暂停中断的测试已完整补跑。
- 普通样本核心扫描 6,678,150 → 4,806,015 拍，按 74.399 MHz 为约 89.76 → 64.60 ms；首次候选约 6.06 ms，视频路径样本候选到显示约 8.71 ms。上述数值是仿真样本性能，尚不是真人首次检出的实测值。
- 完整实现：XLR 13427/60800、RAM 247/256、DSP 6/160。13 个 setup 与 13 个 hold 时钟关系均通过，最小余量 +0.312 / +0.028 ns。
- 用户确认重新连接后，JTAG 重新读到 Ti60 ID 0x10660A79；本次 6 MHz JTAG 下载完成，退出码 0。
- 已请用户对照测试首次出框等待时间和近距离完整正脸检出；当前待反馈。框内白色边缘的现场确认仍待补充。

本次已下载位流 SHA256：'''+sha+'。\n'
f.write_text(s,encoding='utf-8')
f=P/'reports/latency_comparison.json';r=json.loads(f.read_text());r['programmed_bit_sha256']=sha;r['jtag_programming']='complete';r['near_video_test']='PASS: displayed box > 384 pixels, timeout clear';f.write_text(json.dumps(r,indent=2),encoding='utf-8')
m=json.loads((P/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((P/item['path']).read_bytes()).hexdigest()==item['sha256'] for item in m['files'])
print('Recorded successful latency/near-face download; verified',len(m['files']),'manifest files unchanged.')
