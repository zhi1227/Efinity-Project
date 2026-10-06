from pathlib import Path
import json,re
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'README.md';s=f.read_text(encoding='utf-8')
a=s.index('2026-09-24');b=s.index('\n\n## 功能',a)
s=s[:a]+'2026-09-24 新建。上一版已由用户确认绿色框明显稳定、离开后会消失，但首次检出常超过 3 秒且近距离容易漏检。本次增加补扫位置、均值缩图、提前发布和大脸尺度，并加速积分图读取；当前完整构建已通过，最终回归及本次上板效果正在确认。详见 reports/board_feedback.md。'+s[b:]
s=s.replace('先在均匀光照下正对摄像头，让脸宽约占 1280 像素画面的 1/6～1/3。原型','先在均匀光照下正对摄像头，保持双眼、鼻子和嘴完整在画面内。原型')
s=s.replace('先在均匀光照下正对摄像头，让脸宽约占 1280 像素画面的 1/6～1/3。当前覆盖七个离散检测尺度：192、216、240、264、288、336、384 像素的正方形窗口','先在均匀光照下正对摄像头，保持双眼、鼻子和嘴完整在画面内。当前覆盖十三个离散检测尺度：192、216、240、264、288、336、384、432、480、528、576、624、672 像素的正方形窗口')
s=s.replace('小脸、侧脸、遮挡、强逆光及尺度间隙可能漏检','小于最小窗口的脸、侧脸、遮挡、脸部被画面裁切、强逆光及尺度间隙仍可能漏检')
s=s.replace('每 8×8 像素中心抽样，160×90 灰度帧在 Haar 计算期间不再写入。','每 8×8 灰度像素求平均并四舍五入为 8 bit，160×90 灰度帧在 Haar 计算期间不再写入。缩图只增加一行 160×14 bit 部分和缓存，降低单点抽样的混叠。')
s=s.replace('同一快照建立七个尺度的积分图：160×90、142×80、128×72、116×65、106×60、91×51、80×45，窗口扫描步长为 2。','同一快照按十三个尺度复用同一块积分图 RAM，尺寸为 ceil(1280/stride) × ceil(720/stride)，stride 为 8、9、10、11、12、14、16、18、20、22、24、26、28。窗口步长仍为 2，相邻四轮依次覆盖起点偏移 (0,0)、(1,0)、(0,1)、(1,1)，避免一直遗漏相同位置。\n- 积分图四角地址连续发出，利用同步 RAM 两拍读取延迟，原来每个矩形 12 拍的四角读取改为 6 拍；同一模型的全部分类条件保持不变。')
s=s.replace('结果先暂存，在显示帧边界发布。','每次发现新的、已通过全部 25 级的候选簇即申请发布，无需等十三尺度全部结束。跟踪端按就绪握手接收，在显示帧边界发布。')
s=s.replace('13427/60800，22.08%','13427/60800，22.08%').replace('13266/60800，21.82%','13427/60800，22.08%').replace('246/256，96.09%','247/256，96.48%').replace('+0.317 ns','+0.312 ns').replace('+4.445 / +0.047 ns','+3.941 / +0.047 ns')
a=s.index('1. `sim/tb_haar.log`');b=s.index('\n默认接口底座',a)
s=s[:a]+'''1. `sim/tb_haar.log`：普通真实测试图、由该图构造的大脸样本、均匀空场景各覆盖四种扫描相位，共 12 轮；全部候选坐标和尺寸与独立 C++ 整数参考逐一吻合。大脸样本包含超过 384 像素的有效候选；四轮空场景均为 0。
2. 同一普通测试图的相位 0 完整扫描从上一版 6,678,150 拍降为 4,806,015 拍，按 74.399 MHz 为 89.76 → 64.60 ms，减少约 28%。首次候选为 450,731 拍，即约 6.06 ms。这是样本计算耗时，不是所有真人都能在该时限内检出的承诺。
3. `sim/tb_haar_video.log`：完整两帧 720p，共 1,843,200 有效像素，控制/RGB 延迟与 Sobel 坐标通过。
4. `sim/tb_haar_integration.log`：720p RGB565 量化路径、完整缩图快照、补扫相位轮转、提前发布、帧内框稳定及后续空场景清框。首次候选到显示约 8.71 ms，并早于整轮完成；默认 36 帧保持由独立跟踪测试覆盖。
5. `sim/tb_haar_tracker.log`：默认保持、坐标平滑、独立消失、检测停止后过期、容量限制、过期重获及过期竞态通过。
6. `sim/tb_gray_thumbnail.log`：8×8 精确平均、间断有效信号、全白最大值和跨帧重新累加通过。`sim/tb_haar_selftest.log`：启动自检预期 11 个原始候选、测试框不进入实景，以及自动切换摄像头通过。
7. `reports/build.log` 与 `outflow/Ti60_Demo.timing.rpt`：综合、接口、布局布线及位流生成通过，13 个 setup 与 13 个 hold 时钟关系全部为正。
8. JTAG 下载结果以 `reports/jtag_program.log` 和 `reports/board_feedback.md` 中对应位流哈希为准。
''' +s[b:]
s=s.replace('稳定性修订已由用户确认框明显稳定且离开后会消失；框内边缘效果、不同人脸/背景泛化及长时间稳定性还需现场反馈。','上一稳定性修订已由用户确认框明显稳定且离开后会消失；本次首次响应、近距离效果、框内边缘以及长时间稳定性还需现场反馈。')
s=s.replace('七尺度版','十三尺度版').replace('诊断版总计 246/256；移除诊断后可回到 222 块','本次诊断配置总计 247/256；其中缩图均值新增 1 块 RAM，关闭诊断后的最终占用需重新实现验证')
s=s.replace('上一诊断版源码、测试、位流与报告保存在 `reports/before_stability.zip`，便于回退。','上一稳定性版本保存在 `reports/before_latency.zip`；更早诊断版在 `reports/before_stability.zip`，均包含源码、测试、位流和报告，便于回退。')
f.write_text(s,encoding='utf-8')
report={'core_clock_mhz':74.399,'previous_positive_cycles':6678150,'current_positive_cycles':4806015,'first_candidate_cycles':450731,'candidate_to_display_cycles':2484907-1837071,'full_done_clock':6072837,'first_display_clock':2484907,'phase_offsets':[[0,0],[1,0],[0,1],[1,1]],'strides':[8,9,10,11,12,14,16,18,20,22,24,26,28],'live_feedback':'pending'}
(P/'reports/latency_comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
f=P/'tools/check_stability_golden.py';f.write_text('''from pathlib import Path
import subprocess,sys,re
P=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(P/'tools/generate_test.py')],check=True)
expected=int(re.search(r'SELF_EXPECTED=(\\d+)',(P/'src/haar/haar_face_video.v').read_text())[1])
actual=int(re.search(r'SELF_EXPECTED_COUNT (\\d+)',(P/'sim/self_expected_count.vh').read_text())[1])
assert actual==expected,(actual,expected)
print('Startup self-test golden verified:',actual)
''',encoding='utf-8')
f=P/'tools/README.md';s=f.read_text();s+='\nLatency revision: `generate_test.py` now generates 13-scale, four-phase references for ordinary, enlarged-face and blank inputs. Normal workflow remains reference generation -> run_tests.ps1 -> build.ps1 -> review -> record_verified_build.py -> program_jtag.ps1. Other apply/fix/record/document helper scripts are historical edit records and must not be run as a batch.\n';f.write_text(s)
print('Updated latency, distance coverage and verification documentation.')
