"""Write the Chinese handoff from the verified build and test evidence."""
from pathlib import Path
import hashlib
import json
import re

P = Path(__file__).resolve().parents[1]
R = P / 'reports/ram_optimization_20261020'
RUN = json.loads((R/'run.json').read_text(encoding='utf-8-sig'))
B = Path(RUN['baseline_build'])


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def link(path, text=None):
    return '[' + (text or path.name) + '](<' + str(path).replace('\\', '/') + '>)'


def main():
    before = read(B/'reports/build_verified.json')
    after = read(P/'reports/build_verified.json')
    tests = read(P/'reports/ramopt_regression/final_tests.json')
    audit = read(R/'delivery_audit.json')
    assert audit.get('status') == 'PASS', 'Final delivery audit must pass first'
    rows = []
    for name in ('Memory Blocks', 'XLRs', 'DSP Blocks', 'Global Clocks (GBUF)'):
        old, new = before['resources'][name], after['resources'][name]
        rows.append(f"| {name} | {old['used']}/{old['available']} | {new['used']}/{new['available']} | {new['used']-old['used']:+d} |")
    old_ram = before['resources']['Memory Blocks']['used']
    new_ram = after['resources']['Memory Blocks']['used']
    saved = old_ram-new_ram
    top_ram = []
    labels = {'ddr3_ctl_axi':'DDR3 控制器', 'u_axi4_ctrl':'摄像头/视频 DDR 接口及 FIFO',
              'u_shared_font':'共享字库', 'u_parallel':'视频算法并行支路（含人脸/手势）',
              'u_menu':'RISC-V 菜单/电子纸 SoC'}
    for line in (P/'outflow/Ti60_Demo.res.csv').read_text(errors='replace').splitlines():
        if not line.startswith(' +'):
            continue
        fields = line.split('\t')
        if len(fields) < 8:
            continue
        ram = int(re.match(r'\s*(\d+)', fields[6])[1])
        name = fields[0].strip()[1:].split(':', 1)[0]
        if ram:
            top_ram.append(f'| {labels.get(name,name)} | {ram} |')
    report = f'''# 五手势主工程 RAM 资源优化与验收（2026-10-20）

独立复制用户指定的最新五手势工程后实施。原工程完整文件集合及 SHA-256 与实施前清单核对；具体结果见交付审计。

- 原工程：`{RUN['original']}`
- 新工程：{link(P)}
- 原版独立编译对照：{link(B)}，用于同版工具、同约束的资源对比。
- 可打开：{link(P/'Ti60_Demo.xml')}。
- 本轮只做存储表示及布局优化，保留分辨率、颜色位宽、全部八模式、五类手势、现有按键与采样容量。

## 1. 最终资源与时序

以下数字来自两个独立副本本轮完整 Efinity 2025.1 布局布线结果。未使用历史综合报告或原工程里遗留 bit 作为本次基线。

| 资源 | 原版本轮完整编译 | 最终优化版完整编译 | 变化 |
| --- | ---: | ---: | ---: |
{chr(10).join(rows)}

RAM 减少 **{saved} 块（{saved/old_ram*100:.2f}%）**，占用率由 {old_ram/256*100:.2f}% 降至 {new_ram/256*100:.2f}%；剩余 {256-new_ram} 块。逻辑资源的增加主要来自字库解码，表中已同时列出其代价。没有降低 CPU 缓存/主存容量来换取数字。

| 时序检查 | 原版 | 最终优化版 |
| --- | ---: | ---: |
| 最差 setup slack | {before['min_setup_slack_ns']:.3f} ns | {after['min_setup_slack_ns']:.3f} ns |
| 最差 hold slack | {before['min_hold_slack_ns']:.3f} ns | {after['min_hold_slack_ns']:.3f} ns |
| 综合 / 接口 / 布局布线 / bit 生成 | 全部 PASS | 全部 PASS |

时序结论基于当前工程继承的 SDC 和 Efinity 时序模型；没有更改时钟频率、约束或通过删除路径来取得通过。

证据：{link(B/'reports/build_verified.json','原版构建校验')}、{link(P/'reports/build_verified.json','最终构建校验')}、{link(P/'outflow/Ti60_Demo.route.rpt','最终布局布线报告')}、{link(P/'outflow/Ti60_Demo.timing.rpt','最终时序报告')}。

为隔离候选并行编译，最终频次方案在新工程内部 `reports/ram_optimization_20261020/font_frequency_full_map/` 完成全流程。收集前逐项核对它与主目录全部 504 项规范构建输入一致，并检查位流、时序、文件时间及哈希；收集后再次在主目录执行原构建校验器。具体链路见 {link(R/'frequency_build_collection.json','最终构建收集证明')}。这是新工程内部同一份源码的构建与收集，原工程没有参与编译。

## 2. RAM 是怎样省下来的

| 修改 | 具体做法与不变量 | 节省物理 RAM 块 |
| --- | --- | ---: |
| HDMI/LVDS 共享字库 | 以已有像素为基准，无损行字典编码；五组 1024×10 索引 RAM 加组合解码。双时钟、单拍响应不变，原始字库 HEX 不改。原九个 512×16 双口 bank 在 Ti60 实际映射为 18 块，而非九块。 | 13 |
| 七行二值窗口 | 同地址、同使能的六条历史行合为六位存储字；形态学和延迟不变。 | 4 |
| 二值/分类三行窗口 | 两条历史行合并存储，保留有效区、帧边界和单拍 RAM 行为；包括人脸/手势支路及 Canny 滞后窗口。 | 5 |
| 8 位三行窗口 | 同列两行合成 16 位，按 512 深度分 bank；1280 列由每实例四块变三块，共三处生效。12/14 位等不受益配置保留原布局。 | 3 |
| Canny 数据对齐尾段 | 19 位、6618 拍延迟的最后一段由完整 1024 深度改为实际 474 深度，延迟拍数不变。 | 1 |
| 人脸候选 BFS 队列 | 14400 项队列由填充的行列坐标改存线性单元地址，先省两块；再把完整 2048 项分低 10 位/高 4 位平面，最后 64 项合成一块，实际队列由原 30 块降为 22 块。容量、顺序、单拍读取不变，160 列地址解码采用精确常数运算。 | 8 |
| 手势 CCL 坐标表 | 仅把已经被 ROI 限定在 x≤1000 的存储字段由 11 位收紧为 10 位；内部计算/外部坐标保持原宽，FIFO、行表、1024 标签表和候选上限不减。通用默认参数仍支持 11 位。 | 4 |
| 合计 | 物理块以最终完整编译为准 | 38 |

生产修改限定在七个 RTL 文件及五个新字库索引 HEX：

`src/gesture/ep1_skin.v`、`src/vision/line_buffer_3x3.v`、`src/parallel/video_delay.v`、`src/parallel/face_grid_regions.v`、`src/gesture/ep1_components.v`、`rtl/gesture_branch.v`、`rtl/shared_glyph_rom.v`；新增 `shared_font_index_bank0.hex`～`shared_font_index_bank4.hex`。

共享字库最终采用按使用频次编码。行值排序在孤立模块中少 358 LUT4，但放回完整工程后结果反转：同为 184 块 RAM，频次版整机综合 33281 LUT4，行值版 33999 LUT4，频次版少 718 LUT4，因此最终按整机证据选频次版并重做布局布线。新生成器默认也固定为频次版。人脸队列最后一轮布局优化再省六块 RAM，只增加 185 LUT4 和两位寄存器。另验证过三块 RAM 字库版本，但单模块仅再省两块就需增加 4754 LUT4，综合考虑后续逻辑余量，没有采用。单模块/整机综合对比只用于方案选择，最终资源见完整布局布线表。

CPU 的指令/数据缓存维持各 1KiB，主存维持 16KiB。现有固件占用分析显示已超过 8KiB，直接减到 8KiB 会造成运行风险。CPU 核心、固件、DDR 控制器与图片数据均未修改。此次压缩也未新增整帧片内缓存。

最终综合层级中的主要 RAM 分布如下（一级模块累计量，不与其子模块重复相加；最终总量以上述布局布线结果为准）：

| 一级模块 | RAM 块 |
| --- | ---: |
{chr(10).join(top_ram)}

## 3. 保留的功能与操作

八模式依次为：原图、Canny、红色 Sobel、赛博 Sobel、彩色/Canny 左右对照、五手势、人脸候选数量、四帧抓拍对比。保留模式2～4的右上角彩色画中画、IO35 独立 Canny 双阈值页、冻结/恢复、抓拍参数和源帧号、手势 ROI、动态招手和录入样本保持。

五手势仍是：张掌/动态招手、点赞、单手比心、OK、V字。ROI `(40,40)～(1000,680)`、掌心采样、完整性过滤、底部手腕规则均未改。Canny/Gaussian/Sobel 的数学处理、阈值规则和显示像素不变，只优化其底层存储。

按键与最新工程一致：IO28、IO29 为低有效；IO35 为高有效的独立阈值页键；板载 K1/K2 操作不迁移。引脚、I/O 标准和电平设置保持原值。本轮没有新增 Flash、编码器或电子纸按手势换图；电子纸仍由原 RISC-V 固件启动显示原图后休眠。

完整操作表见新工程 {link(P/'README.md','README')}。

## 4. 仿真与测试证据

最终测试清单：{link(P/'reports/ramopt_regression/final_tests.json')}；RAM/字库专项及源文件绑定核验：{link(R/'delivery_audit.json')}。

共 {tests['test_count']} 个功能台架（最终频次版本 26 项，以及同源 CPU/缓存/电子纸 3 项）及四类 RAM/字库等价专项通过。每个阶段的输入和日志分别保存，未混用历史 PASS。

完整输出图像也做了文件级比较：V1、行值候选与最终频次版的七张 1280×720 仿真画面，7/7 张 SHA 完全相同，共 6451200 像素；最终频次版与行值候选的 17 张 LVDS 菜单画面也逐字节一致，共 10444800 像素。证据见 {link(P/'reports/ramopt_regression/final_720p_image_equivalence.json','720p 完整画面比较')}、{link(P/'reports/ramopt_regression/final_ui_image_equivalence.json','完整菜单画面比较')}。这些是仿真输出图，不是实物摄像头或屏幕拍照。

- **逐周期等价**：二值窗口、宽位窗口、延迟链覆盖稀疏 DE、地址边界、回绕、复位及不同参数；宽位窗口 18 组参数、90000 拍。坐标压缩覆盖 160×90 队列全容量 14400 项、通用网格、10/11 位 CCL、标签溢出、合并、边界、截止时间及复位。与原版公开输出和状态时序比较。
- **双屏字库等价**：两路独立 74.4MHz/48MHz 时钟，分别穷举 8192 地址并随机访问；保持一拍输出，对比原版 RTL 与原始 HEX，累计 501424 个像素检查。原始字库像素数据未重新栅格化。
- **最终源码功能组**：25 个台架覆盖按键/页面上下文、FIFO、DDR、冻结、画中画、四帧、肤色/人脸、源帧去重、菜单跨时钟等；五类手势以 320×240 参数化合成手型验证完整 RGB 路径，完成五步录入、识别、未知形状拒绝、静止/抖动抑制、动态招手及样本保持。另以 720p 七帧覆盖原图、Canny、红边、赛博、左右对照及手势空闲路径。
- **实际显示路径**：最终字库下 17 个 LVDS 菜单场景，共 10444800 像素，对比共享字库与原始字体参考，包括菜单、双阈值/步长卡片、候选人数 0/3/8+/无结果、冻结和动画回绕。
- **真实 RISC-V 路径**：缓存压力、八模式菜单固件写寄存器/帧提交及电子纸启动 SPI 事务测试通过；电子纸逐字节核对 30033 字节、两完整图像平面、复位、BUSY和刷新期间菜单存活。这三项运行于首轮 V1；最终相对 V1 只继续调整视频行缓存与人脸队列，最终频次字库六个资产和全部 CPU/固件/菜单/电子纸依赖与 V1 字节一致，因此运行的就是相同 CPU 子系统代码。最终另重跑实际菜单像素和完整功能组，并验证 RAM/字库等价，没有把 V1 日志伪记为整机重跑。V1 全部 504 个生产输入已封存，电子纸在独立快照及其本地 ROM 文件中运行，与后续构建隔离。

首轮缺失/过时的三类手势台架已恢复并适配当前五类流程；失败尝试、台架来源和修订依据单独保存在 provenance/attempts 中，不计入最终 PASS。原工程历史报告、旧位流与合成手型测试都不代表实物识别准确率。

复现入口（只在新工程执行）：

```powershell
.\\tools\\test_ramopt_delivery.ps1 -VivadoBin 'D:\\Xilinx\\Vivado\\2018.3\\bin'
.\\tools\\build_fpga.ps1 -Efinity 'C:\\Efinity\\2025.1'
python -B .\\tools\\verify_ram_optimization_delivery.py
```

具体使用的各组脚本、输入 SHA、日志 SHA 和阶段见 JSON 清单。完整回归耗时较长；本机 XSim/Efinity 需能正常访问其已安装的工具目录。

## 5. 位流与交付完整性

- 可供 Efinity Programmer 使用的 {link(P/'outflow/Ti60_Demo.bit','Ti60_Demo.bit')}。
- 同次构建的 {link(P/'outflow/Ti60_Demo.hex','Ti60_Demo.hex')}。
- bit SHA-256：`{after['bit_sha256']}`。
- hex SHA-256：`{after['hex_sha256']}`。
- 构建输入清单 SHA-256：`{after['build_input_manifest_sha256']}`。
- 原工程完整 1035 文件与开始时哈希、文件集合一致；两个新副本的创建和核验记录见 {link(R/'run.json')}、{link(R/'original_before.json')} 及最终审计。

首轮 193RAM 版本的完整构建记录及位流保存在新工程 `reports/ram_optimization_20261020/v1_build/`，用于追溯；推荐下载上面链接的最终 `outflow` 文件。原版对照只用于回退/资源比较，不要与优化版输出混用。

## 6. 上板验收与后续空间

**本轮未进行 JTAG 下载、Flash 写入或真实板卡观测。** 仿真通过、布局布线通过和 bit/hex 生成均已分开记录；仍需用户下载后确认：

1. 先用新 bit 做 SRAM 下载，检查摄像头原图、颜色、分辨率与长时间运行稳定性，再遍历八模式。
2. 在 Canny/红边/赛博中检查边缘、冻结恢复与 PiP；阈值页验证 LOW/HIGH/LINK 和步长。
3. 五类手势重新录入，检查 OK 圆孔、V 字指缝、招手动态与模式切换/冻结后样本保持。
4. 连续抓拍四帧，跨模式保留并长按清空；检查人脸候选 0、多人、无有效结果的显示。
5. 查看 HDMI/LVDS 中文、数字、菜单动画是否完整，确认电子纸启动显示原图且后续休眠。

剩余占用已经逐层核查，下一步应按实际收益选择：

- DDR 相关 54 块包含厂商控制器 30 块和视频接口/FIFO 24 块。进一步减 FIFO 深度前，需要测量摄像头不可暂停写入、HDMI连续读取和抓拍并发时的峰值占用；容量过小会破坏实时稳定性。
- CPU 29 块包括主存 16、指令缓存 2、数据缓存 4、寄存器文件双读副本 4、UART 1、SPI 2。这里是物理块数量，与缓存有效字节容量不同。若后续专项裁掉未接出的 SoC UART/SPI 外设，有约三块的研究空间，需要重新核对固件、APB和CPU回归。
- 手势支路 23 块中，CCL 标签表 7、run FIFO 3、两份行队列 6，已保留完整容量并收紧字段；再少一位通常不会跨过当前 RAM 映射粒度。更大的节省涉及多周期共享或新算法结构。
- DSP 适合承担坐标换算等算术，FIFO和随机读写表仍需要存储器；本次实际 DSP 变化已列入资源表。

把部分低速状态/图片搬到外存、重排更大位宽的 NMS/边缘信息，或改为多周期计算/共享缓存仍可研究；这些会涉及带宽、延迟和更大验证范围。新增算法应以最终资源余量及实物稳定性为约束。
'''
    out = P.parent/'五手势主工程_RAM资源极限优化报告_20261020.md'
    out.write_text(report, encoding='utf-8-sig')
    old_readme = (P/'README.md').read_text(encoding='utf-8-sig')
    archived = R/'README_before.md'
    if not archived.exists():
        archived.write_text(old_readme, encoding='utf-8-sig')
    operations = old_readme.split('## 八模式的用途', 1)[1].split('## 验证与构建', 1)[0]
    operations = operations.replace('本次修正', '沿用当前工程')
    prefix = f'''# 五手势 Vision8 RAM 优化版（2026-10-20）

本工程从用户指定的 `2026.10.19/10_18_guo_Ti60_gesture5` 独立复制。原工程保持原样。
保留全部八模式、五类手势、720p画质、按键、阈值页、画中画、四帧、双屏和电子纸。

本轮完整编译对比：RAM **{old_ram} → {new_ram}/256**（减少{saved}块），XLR **{before['resources']['XLRs']['used']} → {after['resources']['XLRs']['used']}/60800**，DSP **{before['resources']['DSP Blocks']['used']} → {after['resources']['DSP Blocks']['used']}/160**。
综合、接口、布局布线、位流生成和setup/hold均通过；测试清单按V1/最终源码阶段分别列出。**尚未下载板卡验证。**

最终位流为本目录 `outflow/Ti60_Demo.bit` 和 `.hex`。源码与位流哈希见 `reports/build_verified.json`，完整说明：{link(out)}。
历史文档、旧台架结果和旧资源数字不代表本次交付；原README已封存为 `reports/ram_optimization_20261020/README_before.md`。

## 八模式的用途'''
    ending = '''## 验证与构建

在本目录执行 `tools/test_ramopt_delivery.ps1` 重跑测试；`tools/build_fpga.ps1` 完整编译；`python -B tools/verify_ram_optimization_delivery.py` 核验原工程保护、构建输入、资源、时序、位流及仿真证据。
工具路径和各项结果见上面的完整报告及 `reports/ramopt_regression/final_tests.json`。
不要直接执行历史 `prepare_*` 脚本覆盖当前源代码。没有执行JTAG或Flash写入。
'''
    (P/'README.md').write_text(prefix+operations+ending, encoding='utf-8-sig')
    print(out)


if __name__ == '__main__':
    main()
