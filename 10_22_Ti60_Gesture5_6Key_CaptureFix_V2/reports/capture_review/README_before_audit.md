# 六键操作、四帧抓拍修复与 Canny 双阈值

## 打开哪个工程

当前版本：`D:\yilingsi_fpga\Efinity_Project\2026.10.20\10_20_ding_Ti60_Gesture5_6Key_CaptureFix\Ti60_Demo.xml`。

原故障版本 `10_20_ding_Ti60_Gesture5_4Key_InlineThreshold` 保留不动。本版完整复制了 7,683 个文件，复制时逐文件 SHA-256 一致；清单见 `reports/capture_fix/protection.json`。继承的旧构建输出放在 `reports/capture_fix/original_outflow`、`original_work_syn`、`original_work_pnr`，不能作为本次构建证据。

目标保持 Ti60F225 / C4 / Efinity 2025.1.110.5.9，1280×720；未改摄像头、PLL、DDR IP、原始管脚定义或视频时钟。未下载 FPGA、未写 Flash。

## 模式顺序

1 原图 → 2 Canny → 3 彩色红边 → 4 赛博边缘 → 5 彩边对照 → **6 四帧对比** → 7 五类手势 → 8 人脸候选。

内部算法编号不变；`src/parallel/vision8_modes.vh` 中 `slot_to_mode` / `mode_to_slot` 只转换显示和选择顺序。UART 数字 `0`～`7` 按上述显示顺序选择，例如 `5` 是四帧，`6` 是手势，`7` 是人脸候选。没有增加人脸身份录入或识别功能。

## 按键操作

六键均按低有效处理，双级同步、约 20 ms 消抖。上电时按住的键必须先释放，再按才触发。长按约 2 秒；长按松开不会再触发短按。改变模式或 Canny 调节对象时，已按住的旧动作作废。

| 按钮 | 短按 | 长按 |
|---|---|---|
| IO28 | 下一模式；离开四帧同时清空并进入手势 | 无动作 |
| IO29 | 普通模式冻结/恢复；四帧保存一张 | 四帧清空，其他模式无动作 |
| IO34 | 边缘模式减阈值；手势确认；四帧换抓拍算法 | 边缘步长 1→4→8；手势进入/重新录入 |
| IO35 | 边缘模式加阈值 | 恢复当前算法默认值 |
| 板载 K1 | 模式 2、3、4 切换画中画 | 无动作 |
| 板载 K2 | 模式 2、5 切换 联合→仅 HIGH→仅 LOW→联合 | 无动作 |

K1 使用已有 `key_mode_n`（N2/GPIOL_P_02），K2 使用 `key_freeze_n`（M2/GPIOL_N_02），不新增接线。手势录入期间 IO29 不冻结。

## Canny 如何调

始终显示 LOW 和 HIGH。上电默认 **LOW=40，HIGH=80**。进入模式 2 或 5 时默认选择“联合”，数值不重置；两模式共享这组参数。IO34 减，IO35 加。

- 联合：基础步长为 d，LOW 每次变化 d，HIGH 每次变化 2d。例如步长 1 时 40/80 → 41/82。
- 仅 HIGH / 仅 LOW：选中的值每次变化 d，另一个保持。
- 总是保持 `1 ≤ LOW < HIGH ≤ 2040`。联合时成对限幅，临近边界可缩小最后一步；不能只动其中一个。
- 单独调过后，不强制把数值改回 2:1。联合模式只规定增量的比例。
- IO35 长按恢复 40/80，并回到联合选择；基础步长保留。
- 控制器 `low/high` 是待提交值，`low_active/high_active` 在输入帧边界一起更新，`version` 随实际参数改变递增。冻结时仍可调节。
- 红边默认 40（1～2040），赛博默认 24（1～255），各自独立。UART `+/-` 调当前算法，四帧中调所选抓拍算法；`r` 恢复全部默认值和原有复位行为。

阈值单位仍是原工程的梯度量纲。Canny 高低阈值、滤波、方向 NMS 及一次局部 8 邻域连接定义没有改变；没有加入跨帧叠加或自适应算法。

## 四帧操作与故障修复

进入第 6 模式，IO34 选择原图/Canny/红边/赛博，IO29 短按保存。允许连续四次保存，第五次替换最早一格。抓拍需等待冻结应答、完整有效源帧及 DDR 完成，显示 BUSY 时不能再次保存。

**四帧中 IO28 短按：清空四格、图片元数据、待发布结果及保存序号，抓拍算法回原图，然后进入第 7 模式手势。** 已调算法阈值保留。UART 离开四帧同样清空。IO29 长按只清空，保持四帧模式。再次进入时四格为空；后台 DDR 排空期间显示忙。

清空只是目录失效，不擦写全部 DDR。正在进行的总线事务必须完成后，才能复位快照 FIFO；如果 DDR 永远不响应，不能伪造完成，此时清理仍会保持忙，需要检查 DDR/复位硬件。抓拍专用冻结不等待后台排空，避免带着锁定进入后续模式。

确认并修复的代码缺陷：

1. 原 `vision8_frames` 的取消不能保证退出等待状态，`lock_source` 可能持续保持。负向回归在缺失冻结应答/VS 时复现了该缺陷。新状态 7 专门排空，状态 8 完成 FIFO 复位；清零优先于图片发布。
2. 原 `vision8_ddr` 看门狗退出仍依赖 `snap_end`，丢失结束信号时不能恢复。新增 `snap_abort`，不依赖帧结束令牌取消；已呈现的 AW、停顿中的 W 保持稳定，完成 W/B 后才返回失败完成。
3. 原“首个读地址接受”不代表完整图像。`vision8_base_axi` 新增 `read_frame_good/read_frame_bad`，统计主读像素、空读和复位忙；`vision8_frames` 逐像素核对坐标、数量及源帧号，源号在首有效像素绑定。
4. 强制长时间 W 背压时，摄像头 FIFO 在空的填充拍接收新数据，原来直通 AXI 的 WDATA 会变化。已在 `vision8_ddr` 为已呈现且停顿的摄像头写拍增加保持寄存器；正常 ready 路径仍无附加拍，摄像头初始化/IP 不变。这是压力测试支持的最小保护性改动。
5. 四帧空闲时主视频读不再停启：`main_enable` 恒为 1。灰屏可能还有板上信号/DDR等原因，因此这些修复和仿真不能单独证明实物灰屏已经消失。

抓拍使用实际生效参数和版本。Canny 图像标注保存时 LOW/HIGH；红边和赛博标注真实 T。保存后的数据和标签不会跟随后续调参变化。HDMI 上保留源帧号及版本标签。

像素侧无进展超时为四个标称帧周期（4×1650×750 拍，约 66.5 ms）；DDR 侧保留 27 位看门狗（最大 134217727 拍，约 1.40 s @96 MHz）。超时不能撤回已经呈现的 AXI 事务。

## 验证分层与复现

运行环境为本机 Python + Vivado 2018.3 XSim + Efinity 2025.1，没有升级全局工具。命令在本工程目录执行，Python 可使用：

`C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`

```powershell
$py = 'C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -X utf8 -B tools/run_capture_fix.py tb_capture_exit_regression --original --expect-fail
& $py -X utf8 -B tools/run_capture_fix.py tb_capture_exit_regression
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_controls
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_chain
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_abort
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_pip
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_faults
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_720p_pressure
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_full_load
& $py -X utf8 -B tools/test_capturefix_video.py
& $py -X utf8 -B tools/test_capturefix_ui.py
& $py -X utf8 -B tools/test_capturefix_final.py
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_cancel_boundary
& $py -X utf8 -B tools/run_capture_fix.py tb_capturefix_binding
& $py -X utf8 -B tools/verify_capturefix_delivery.py
& $py -X utf8 -B tools/test_capturefix_cpu.py --test cpu8
& $py -X utf8 -B tools/test_capturefix_cpu.py --test epaper
```

`run_capture_fix.py` 每次创建新英文路径和时间戳报告。其他回归脚本会更新本版相应报告，复现前可另存已有日志。不要运行 `implement_*` 脚本：它们仅记录本轮一次性编辑过程，不是可重复安装器。继承的旧交付验收器保留作历史参考，其旧按键断言不适用于本版本。

- `tb_capturefix_chain`：128×96 实际控制器→厂商摄像头/主读 FIFO→DDR→实际四种算法→保存→AUX→四格显示。检查四次保存、第五次替换、各抓拍阶段退出及再抓拍。没有伪造冻结/DDR完成应答。
- `tb_capturefix_binding`：实际 Canny 抓拍期间经 UART 改参数，检查本次捕获锁定旧 LOW/HIGH、已保存标签不变，下一次捕获使用新值和版本。
- `tb_capturefix_cancel_boundary`：清零恰好与 DMA 开始或目录发布同拍时的优先级单元测试。
- `tb_capturefix_abort`：真实 DDR 模块的 AW/W/B 停顿、取消、缺失 `snap_end` 看门狗；检查停顿信号稳定。
- `tb_capturefix_faults`：末像素缺失、VS 中断、DDR BRESP 错误及快照 FIFO 写满；失败不发布、释放抓拍锁、清空后重新保存。
- `tb_capturefix_720p_pressure`：1280×720、1650×750、74.4 MHz 像素、96 MHz AXI、100 MHz 摄像头字节产生器，真实主读/快照/四格 AUX 并发。为隔离内存吞吐，该项使用 RAW 延迟流水；不把它称为四种算法的全分辨率闭环测试。
- `tb_capturefix_full_load`：先在仿真存储器预置四格 RAW 数据和有效目录，随后真实执行一次替换抓拍，同时逐拍检查每个主读请求及四格 AUX 有效像素不空读/不复位/不失效。这个独立压力夹具用于最大并发负载，不能替代前项从空目录开始的四次真实保存。
- `test_capturefix_video.py`：独立验证完整 720p 默认算法逐像素一致性，以及运行时阈值响应。
- UI 仿真图在 `reports/capture_fix/ui`；这是 RTL 渲染结果，不是实拍。

总线模型固定随机种子 `0x9126acd8`，模型、测试输入生成代码和生产源码 SHA-256 均保存在对应结果中。AXI 存储模型包含读写随机停顿和应答延迟，但读写通道独立，不完整建模 DRAM 刷新、读写换向、物理 DDR 校准、真实传感器/MIPI、电气噪声或显示器。因此压力仿真通过不等于板上 DDR 带宽已实测通过。

构建必须使用新英文目录：

```powershell
$py = 'C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -X utf8 -B tools/capture_fix_build.py prepare D:/Github_Project/fpga_build/capturefix_MY_NEW_RUN
& $py -X utf8 -B tools/capture_fix_build.py build D:/Github_Project/fpga_build/capturefix_MY_NEW_RUN
& $py -X utf8 -B tools/capture_fix_build.py collect D:/Github_Project/fpga_build/capturefix_MY_NEW_RUN
```

首次交付的具体构建阶段、资源、setup/hold、bit/hex 哈希及测试状态见 `reports/capture_fix/delivery.json`（全部验证结束后生成）。收集器不会覆盖现有 outflow 或证据目录；再次使用收集器前，请先把 `outflow`、`reports/capture_fix/build`、`reports/capture_fix/selected_build.json` 和旧 `build_stage.json` 一起另存到新备份目录。禁止把继承 bit 当成新文件。

## 修改边界与回退

主要逻辑：`rtl/vision8_frames.v`、`rtl/vision8_ddr.v`、`rtl/vision8_base_axi.v`、`rtl/vision8_controls.v`、`example_top.v`。显示：`rtl/menu8_renderer.v`、新 `src/parallel/vision8_modes.vh`、`tools/generate_font.py`、`tools/hdmi_text.json` 及相应生成字库。约束仅追加 K1/K2 到首级同步器的异步输入约束。逐文件位置和用途见 `reports/capture_fix/CHANGES.md`，完整差异哈希见 `reports/capture_fix/changed_files.json`。排错中未选用的构建和测试说明见 `reports/capture_fix/iteration_notes.md`。

工程中原有模块已在 `Ti60_Demo.xml` 清单，新头文件通过现有 include 路径被三个模块引用。未添加未参与综合的占位模块。

**回退方法：直接打开原目录中的 `Ti60_Demo.xml`。** 本版是独立副本，不需覆盖原工程，不执行 reset/clean，不提交或推送。可用 `tools/verify_capturefix_delivery.py` 检查原目录仍与复制时 SHA 清单一致。原版也包含原来的抓拍问题。

## 上板建议观察的三个现象

1. 第 6 模式依次保存原图、Canny、红边、赛博，确认每格有真实图像，第五次能替换；小标签与保存时参数一致。
2. 保存等待/保存过程中按 IO28，确认立即离开到手势；再进入四帧是空格，其余模式持续更新。忙状态结束后能再次保存。
3. Canny 初始显示 40/80；K2 三种选择轮换，联合加一次为 41/82，单独调节只动所选数；K1 在模式 2～4 开关画中画。

未执行上板、JTAG 或 Flash 操作。必须由你实际加载本次生成 bit 并观察后，才能确认板上灰屏是否完全消除。

## 本次最终构建结果

最终构建目录：`D:\Github_Project\fpga_build\capturefix_20261021_final2`。综合、接口、布局布线及 bit/hex 生成全部通过。构建输入与本工程 506 个生产文件核对一致，生成物已收集到本工程 `outflow`。

| 项目 | 原版既有、源码匹配的构建 | 本次新构建 |
|---|---:|---:|
| XLR | 52,399 | 55,047 |
| RAM 块 | 184 | 184 |
| DSP 块 | 39 | 38 |
| 最小 setup slack | 0.298 ns | 0.302 ns |
| 最小 hold slack | 0.026 ns | 0.026 ns |

原版列来自原工程已有报告，并已重验其源码与 bit/hex 哈希，**不是本轮重新构建原版**。新增逻辑使 XLR 增加 2,648；RAM 没增加。保留 XLR≤60,000、RAM≤230 和非负 setup/hold 验收，不改频率或视频约束。

下载时选择本工程 `outflow/Ti60_Demo.bit`；需要 Flash 文件时对应 `outflow/Ti60_Demo.hex`。本次未执行下载或 Flash 写入。

```text
Ti60_Demo.bit SHA-256
5d602c66a7e55b250aa3c72f7c5af01c11f4e9ef488a5c372e1072ca3cf8c97d
Ti60_Demo.hex SHA-256
06c47b7b6a989159434208bc355330c515f096275dfb4a09ca64408992f56ce9
```

现有接口邻近 MIPI/LVDS 的工具警告保留；本轮没有重映射管脚。综合未出现匹配锁存器/多驱动的警告，K1/K2 首级同步寄存器约束目标在映射网表中已确认。完整工具警告仍可在 outflow 查看，不将构建通过描述成“零警告”。

## 最终验收状态（2026-10-21）

`tools/verify_capturefix_delivery.py` 实际执行结果为 **PASS，12 个交付核验项目全部通过，无未完成项**。这里的“全部”指本文件列出的软件/RTL/构建验收范围；上板仍为未执行。

| 验证层级 | 实际结果 |
|---|---|
| 原版故障负向回归 | 成功复现抓拍等待中退出仍锁住视频 |
| 最终 RTL 回归 | 30 项 PASS，包括六键、真实跨时钟抓拍、错误恢复、PiP、手势、人脸、FIFO及摄像头 |
| 同拍取消边界与参数绑定专项 | 2 项 PASS；抓拍锁定旧40/80、下一次使用42/84 |
| 720p 默认算法对比 | 6,451,200 个像素与原版逐像素一致；动态阈值另核对147,456像素 |
| 720p 空目录→四次保存压力 | PASS；核对主图33,177,619像素、四格显示14,556,420像素，稳态未新增AUX欠载 |
| 720p 四格已满再替换压力 | PASS；监控8个完整帧；逐拍未发现主读空读/有效区复位/AUX失效 |
| 菜单/字库 | 5,301,248 UI像素检查；压缩字库8192地址与每端口12000次固定种子随机读取 PASS |
| 实际 RISC-V 固件/LVDS 菜单仿真 | 八模式4,915,200像素 PASS |
| 电子纸仿真 | 30,033 SPI字节、两图层、复位及BUSY等待 PASS |
| 综合 | PASS |
| 布局布线及时序 | PASS，setup 0.302 ns，hold 0.026 ns |
| Python/OpenCV图像参考模型 | 未新增；本轮不改变算法，以原版RTL逐像素对比 |
| 上板实测/JTAG/Flash | **未执行** |

原工程全部7,683个文件及文件集合在最终验收时再次核对一致；新工程506个生产文件与最终构建输入一致，47个构建输出文件哈希已复核。当前可选位流只有本工程 `outflow` 中本次收集的文件，不能使用 `original_outflow` 或第一次试构建的位流。

建议按正文最后三个观察点上板验证。出现失败提示时先用 IO29 长按清空，再确认摄像头状态后重试；IO28 用于清空并退出。原工程和历史证据保留，回退不需要删除任何文件。
