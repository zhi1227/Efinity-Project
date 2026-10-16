"""Write the requested Chinese report from completed, validated evidence."""
from pathlib import Path
import json

P = Path(__file__).resolve().parents[1]
v = json.loads((P / 'reports/roi_integration/final_validation.json').read_text(encoding='utf-8'))
b, n = v['baseline'], v['merged']
rows = []
for label, title in [('Memory Blocks', 'RAM块'), ('XLRs', 'XLR逻辑资源'), ('DSP Blocks', 'DSP'), ('Global Clocks (GBUF)', 'GBUF')]:
    before, after = b['resources'][label], n['resources'][label]
    delta = after['used'] - before['used']
    rows.append(f"| {title} | {before['used']}/{before['available']} | {after['used']}/{after['available']} | {delta:+d} | {after['available'] - after['used']} |")
roi_rows = '\n'.join(f"| {t['bench']} | PASS | {t['elapsed_seconds']:.3f}秒 |" for t in v['roi_results']['tests'])
main, ref = v['original_projects']['main'], v['original_projects']['reference']
report = P.parent / 'Vision8_手势ROI融合说明与资源测试_20261013.md'
text = f'''# Vision8 手势 ROI 融合说明与资源测试

日期：2026-10-13。新工程已完成扩大手势ROI融合、28项原有回归、2项新增专项测试以及Efinity完整编译。两个原工程未修改。尚未下载开发板，实际摄像头、显示屏、按钮和手势识别率需上板验收。

## 1. 独立工程与原件保护

- 新工程：`{P}`。
- 主工程：`{main['path']}`，实施前后文件集合和全部 **{main['unchanged_files']}个文件SHA256一致**。
- 参考工程：`{ref['path']}`，实施前后文件集合和全部 **{ref['unchanged_files']}个文件SHA256一致**。
- 完整复制时，新副本与主工程的{main['unchanged_files']}个文件逐一匹配。修改、仿真及编译在新副本进行。

最终核验{v['checked_build_inputs']}个构建输入，生产设计唯一变化是 `src/parallel/gesture_config.vh` 四个范围宏。Canny、Sobel、顶层、GPIO约束、CPU、固件、初始化数据、共享字库和电子纸图像保持一致。Efinity改写的项目XML运行状态/时间属性在设计核验中规范化排除，器件、源文件和实现参数仍全部核验。

## 2. 融合后的功能

| 项目 | 融合前 | 融合后 |
| --- | --- | --- |
| 手势ROI左上角 | (160,60) | **(40,40)** |
| 手势ROI右下角，含边界 | (960,660) | **(1000,680)** |
| 有效范围面积 | 801×601 = 481401像素 | 961×641 = 616001像素，增加约27.96% |
| 实际检测与屏幕大框 | 共享ROI参数 | 同步扩大，屏幕框仍两像素宽 |
| 掌心肤色采样 | 中心(560,360)，32×32 | 保持不变 |
| 右侧预览和提示 | 原位置 | 保持不变 |

ROI参数同时用于滤波后的肤色掩膜门控、CCL候选边界检查及屏幕大框。全图原始/滤波肤色诊断计数仍是全图计数，不应解释为ROI内计数。完整手型的最小宽、高、面积、左右及顶部边界拒绝继续保留；底部继续允许手腕伸出。没有新增分类器或图像缓存。

八模式、画中画、四帧处理结果抓拍、人脸候选统计、手势反馈、真实时间录入倒计时和摄像头源帧去重均保留。第6模式仍为LOW/HIGH/LINK调节，步长1/4/8，默认40/80，范围 `1 ≤ LOW < HIGH ≤ 2040`，在帧边界生效。Canny算法未改；外接图片Flash和编码器未接入；电子纸仍保留开机静态图片。

## 3. 优化主工程与融合工程的资源对比

双方均为Ti60F225，Efinity 2025.1。融合前采用已核对源码与bit/hex哈希的主工程报告；融合后采用本轮新生成的 `outflow/Ti60_Demo.route.rpt`，没有沿用参考工程或复制来的旧结果。

| 资源 | 融合前 | 融合后 | 变化 | 融合后剩余 |
| --- | ---: | ---: | ---: | ---: |
{chr(10).join(rows)}

| 时序 | 融合前 | 融合后 |
| --- | ---: | ---: |
| 最小setup余量 | {b['min_setup_slack_ns']:+.3f} ns | {n['min_setup_slack_ns']:+.3f} ns |
| 最小hold余量 | {b['min_hold_slack_ns']:+.3f} ns | {n['min_hold_slack_ns']:+.3f} ns |

RAM满足“不增加”的目标，既有CPU缓存及共享双屏字库优化保留。Map、Interface、PNR、PGM均PASS，当前约束下setup/hold均非负。构建输入开始/结束哈希一致，新bit与hex均晚于本次执行开始时间；布局布线/时序报告也核对了新时间戳。

## 4. 测试结果与证据

原有 **28项回归全部重新运行并PASS**：15项既有视觉/控制/录入回归、7项Vision8控制/FIFO/DDR/四帧/人脸/手势/IO29冻结、八模式菜单像素、真实CPU八模式菜单、真实CPU电子纸、2项共享字库比较、CPU缓存压力。所有最终日志有本次新时间戳和PASS，无Fatal/Error。

| 新增专项 | 结果 | 台架耗时，含elab |
| --- | --- | ---: |
{roi_rows}

- 实际RGB专项按320×240比例光栅驱动肤色→形态学→CCL，四侧新增区域可检测；左/右/顶部截断与空景被拒绝，底部手腕到ROI边界被接受。74帧中71个不同源ID被接受、3次重复ID被拦截；生产使用的 `SOURCE_TAGGED=1` 开启。
- 显示专项使用1280×720坐标及实际 `SHARED_FONT=1` 路径，检查新大框四边两像素、旧框消失、掌心框和右HUD不移位，以及纯图取消叠加。521389个像素与独立字库逐拍一致；另一独立时钟端口372425次LCD读取正常。
- 原有回归覆盖三类模板录入、招手、冻结/切模式保留样本、实时时钟倒计时/超时、重复源帧不得累积确认票数、IO29到DDR冻结及恢复、阈值联动与饱和、四帧/PiP和真实CPU菜单/电子纸。
- 真实CPU八模式每模式检查614400个像素及853440个时钟；电子纸逐字节确认30033个SPI字节、两组完整图像数据、复位/BUSY及刷新期间LVDS菜单更新；缓存压力回归完成42503周期的索引别名、完整地址标签、byte/halfword写掩码、指令冲突和fence检查。

首次显示专项有一个矩阵点亮像素的台架预期写错；修正为既有招手图案的正确像素后重编译复跑PASS，生产RTL没有为此修改。最终证据以通过的日志为准。

关键证据在新工程 `reports/roi_integration/` 目录：`final_validation.json`、`source_trees_before.json`、`copy_verified.json`、`roi_test_results.json`和两项专项日志；构建结果在 `reports/build_verified.json`、`reports/efinity_build.log`。完整复跑命令见新工程README，验收脚本为 `tools/verify_roi_integration.py`。

## 5. 下载文件与上板检查

- JTAG/SRAM临时运行：`{P / 'outflow/Ti60_Demo.bit'}`。
- 配置Flash持久保存：`{P / 'outflow/Ti60_Demo.hex'}`。这是FPGA配置Flash，与暂未实现的外接图片Flash不同。
- bit SHA256：`{n['bit_sha256']}`。
- hex SHA256：`{n['hex_sha256']}`。

本次未执行JTAG下载或配置Flash烧录，未进行物理板卡验收。建议先使用新bit临时运行：

1. 检查摄像头、HDMI、LVDS和原电子纸开机图片；IO28切换八模式，IO29冻结/恢复。
2. 第6模式用板载K1选择LOW/HIGH/LINK、长按切步长，板载K2增加、IO29减少，验证画面与参数一致。
3. 第8模式长按板载K1约2秒进入录入，再用K1短按依次确认张掌、点赞和单手比心。掌心先盖住原粉色小框；下载/复位后必须重新录入。
4. 在扩大大框的左、右、上、下新增区域移动完整手型，观察候选框与轮廓预览。指尖及左右保持框内，底部允许手腕延伸。检查冻结期间不因重复源帧产生新确认，恢复后正常识别。
5. 回到模式2～4长按IO28检查PiP；模式5用板载K2选算法、IO29抓拍/长按清空，检查四格图像和参数。模式7检查人脸候选框及人数显示。

扩大ROI的功能已通过仿真，实际灯光、背景与手型条件下的识别准确率仍以开发板观察为准。
'''
report.write_text(text, encoding='utf-8')
print(report)
