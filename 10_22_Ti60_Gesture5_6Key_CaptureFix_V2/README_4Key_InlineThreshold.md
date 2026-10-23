# 四个外接按钮与模式内阈值整合（2026-10-20）

本版工程：`D:\yilingsi_fpga\Efinity_Project\2026.10.20\10_20_ding_Ti60_Gesture5_4Key_InlineThreshold`。

在Efinity打开本目录 **`Ti60_Demo.xml`**。目标Titanium Ti60F225，工程记录Efinity 2025.1.110.5.9；保留原分辨率、时钟及视频接口。不自动下载FPGA或写Flash。

## 模式与参数

模式6一直是五类手势识别，独立阈值页不是模式6。新版本保留全部八模式，删除IO35打开的独立阈值页，模式2～5直接显示一个 **T** 和 **STEP**，不用选择LOW / HIGH / LINK。

这里的实时T/STEP显示在**LVDS菜单屏**。HDMI实时视频不新增T数字，模式8的HDMI四帧标签显示保存时的T；不要把菜单数值与HDMI实时叠字混为一处。

| 屏幕模式（内部编号） | 内容 | 默认值与范围 |
| --- | --- | --- |
| 1（0） | 摄像头彩色原图 | 不调边缘阈值 |
| 2（1） | Canny黑白边缘 | T=80，范围2～2040 |
| 3（2） | Sobel红边叠加 | RED T=40，范围1～2040 |
| 4（3） | Sobel赛博边缘 | CYBER T=24，范围1～255 |
| 5（4） | 彩色/Canny左右对照 | 与模式2共享Canny T |
| 6（5） | 招手、点赞、单手比心、OK、V字 | IO34录入与确认，不调边缘阈值 |
| 7（6） | 肤色/轮廓人脸候选数 | 保留原检测条件，不是身份识别 |
| 8（7） | 四帧对比 | 保存时绑定实际算法及阈值 |

Canny内部仍区分强/弱边缘，固定`LOW=max(1,floor(T/2))`、`HIGH=T`，默认40/80。Canny与红边T使用未缩放Sobel L1幅值单位；赛博T使用当前8位幅值显示单位，控制低幅值置黑，保留64/128/192分色规则。三个数字不能直接比较灵敏度。默认值沿用原版，不表示所有光照下最优。

本轮没有移植其他日期工程的自适应阈值，没有跨帧边缘叠加。原灰度、高斯、梯度、NMS和一次局部8邻域连接保留；局部连接不是完整任意长度连通追踪。红边T接到真正显示红轮廓的原始Sobel支路，不只是中值后诊断比较支路。

## 四键接线与操作

四键全部**松开高、按下低**。IO35已由原工程高有效接收改为低有效，原来的“IO35按下高”说明不适用本版。

| 按钮/顶层端口 | P4/DC3-40位置 | FPGA球位 / GPIO |
| --- | --- | --- |
| IO28 / `io28_button_i` | 第33脚 | C1 / GPIOL_N_16 |
| IO29 / `io29_button_i` | 第34脚 | D1 / GPIOL_P_16 |
| IO34 / `io34_button_i` | 第39脚 | A9 / GPIOT_N_11 |
| IO35 / `io35_button_i` | 第40脚 | B9 / GPIOT_P_11 |

FPGA侧均为1.8 V LVCMOS输入；P4 User_3V3经底板电平转换，连接器侧与FPGA侧电压不同，不要把FPGA标准改为3.3 V或配置成输出。按钮将信号可靠拉到GND。板载K1/K2保留管脚，控制层屏蔽动作，当前不使用。

| 按钮 | 模式2～5 | 模式6手势 | 模式8四帧 |
| --- | --- | --- | --- |
| IO28短按 | 下一模式 | 下一模式，取消未完成录入 | 下一模式 |
| IO28长按 | 模式2～4开关PiP；模式5无动作 | 无动作 | 无动作 |
| IO29短按 | 冻结/恢复 | 非录入期间冻结/恢复 | 保存一张；忙时忽略 |
| IO29长按 | 无动作 | 无动作 | 清空四格 |
| IO34短按 | T减小 | 确认当前录入步骤 | 原图→Canny→红边→赛博；忙时忽略 |
| IO34长按 | STEP按1→4→8循环 | 进入/重新录入，并恢复实时画面 | 无动作 |
| IO35短按 | T增大 | 无动作 | 无动作 |
| IO35长按 | 恢复当前算法默认T | 无动作 | 无动作 |

模式1、7中，IO28短按切模式、IO29短按冻结，其余操作忽略。约20 ms双边消抖；长按约2秒触发一次，松开不补短按，不自动连发。上电按住须先稳定松开，再重新按下；跨模式或录入上下文取消旧动作。

STEP默认1，是三组边缘参数共用步长。切模式保留数值，长按IO35只复位当前算法T，不影响别组及STEP。断电、复位或UART `r`恢复全部默认值，不写Flash。

先用STEP=1短按增减观察；需大幅探索时长按IO34切换4或8。缺边时减小T，噪声多时增大T；随时长按IO35恢复默认。不能只因边缘变少便认为图像质量提高。

## RTL信号与帧边界

| 参数 | `vision8_controls`请求信号 | 控制域活动信号 |
| --- | --- | --- |
| Canny T及内部LOW | `high` / `low` | `high_active` / `low_active` |
| 红边T | `red` | `red_active` |
| 赛博T | `cyber` | `cyber_active` |
| STEP | `step_select` | 编码0/1/2对应1/4/8 |

请求经帧边界提交，再在对应视频域整帧使用。菜单沿用640位状态通道，`state[48:37]`为当前活动T，`state[64:63]`为STEP；手势`state[125:124]`保留，旧`state[123]`不再控制阈值页。控制、像素和LVDS域有CDC及各自帧提交延迟，不保证按键、HDMI和菜单在同一拍改变；一帧内不使用前后两组阈值。

调整不改变手势、人脸或维护诊断支路的内部条件。摄像头、DDR、PLL、分辨率和像素流水级数保留，RAM优化后的缓存与字库压缩结构继续使用。

## 冻结、手势、抓拍与串口

冻结保留摄像头源帧，边缘算法仍可重新处理该帧，模式2～5可冻结后调T比较同一画面。切模式沿用原有恢复实时画面的行为。

手势模式长按IO34录入，短按逐步确认张掌、点赞、比心、OK、V字。掌心盖住原粉色小框，手指放入大ROI，倒计时保持稳定。切模式取消未完成录入；已完成模板在模式切换及冻结/恢复后保留，复位/断电后重新录入。五手势算法没有换成新的识别器。

模式8用IO34短按换算法，IO29短按逐格保存，第五次覆盖第一格，长按清空。忙时忽略新抓拍及算法切换。图片及元数据保存后锁定，后续调T不修改旧图。每格只显示保存时的一个T：Canny用HIGH，红边/赛博用各自T，原图不显示阈值。内部LOW、源帧号和参数版本继续保留。

UART保留原模式及维护命令，`+`/`-`调当前模式T；模式8作用于选中的抓拍算法，原图或非边缘模式忽略。`r`恢复全部默认阈值与原复位状态。波特率沿用工程配置。

## 原版保护、恢复与生成工具

原版`10_20_ding_Ti60_Gesture5_RAM_Optimized`只读保留，新版是完整独立副本。继承的旧RAM报告、旧日志和旧bit属于历史证据，不能证明本轮通过。最终验收位于`reports/inline_threshold/delivery_audit.json`，实际构建及位流见同目录`selected_build.json`。本轮UI/字库专用证据在`reports/fourkey`，最终验收会绑定其哈希。

回退时在Efinity打开同日期原版的`Ti60_Demo.xml`，重新编译/下载，不混用两个目录的bit。恢复源码不会撤销板上已运行的配置。原版IO35高有效，若硬件现按低有效接线，回退前须对应原版接法。

不要运行历史`prepare_*`覆盖脚本。只需重建本版字体时依次运行：

```powershell
python -B tools/generate_font.py
python -B tools/compress_shared_font_ram.py --index-bits 10 --ordering frequency --report-dir reports/fourkey/font
python -B tools/test_fourkey_ui.py
```

第二步必须执行，恢复频率排序的10位索引压缩，仍为5个索引bank、独立双时钟读口、1拍延迟。原固定字库参考测试属于旧字形版本，本版单独验证新字库，不要求改过提示文字的整幅菜单与旧版相等。

## 修改清单与内部兼容参数

主要修改：`example_top.v`接入IO34、三组工作参数和菜单状态；`rtl/vision8_controls.v`实现四键与参数寄存器；`src/parallel/parallel_video.v`接入RED原始梯度比较及延迟帧边界CYBER门槛；`rtl/vision6_overlay.v`使用同一CYBER门槛；`rtl/vision8_frames.v`保留元数据结构并显示真实单T；`rtl/menu8_renderer.v`删除独立页并就地显示T/STEP。三套字库RTL和对应HEX按当前文字重新生成，保持原共享字库RAM布局。

`Ti60_Demo.peri.xml`只新增IO34输入；`Ti60_Demo.pt.sdc`只新增IO34到首级同步器`controls/c/meta~FF|D`的异步例外，旧约束原样保留。实际综合源码清单无需新增算法模块，`Ti60_Demo.xml`的原文件清单不变。完整逐文件SHA清单和差异见`reports/inline_threshold/source_changes.json`、`source_changes.diff`。

`parallel_video.INLINE_THRESHOLDS`在本版顶层明确设为1；模块默认0是为了旧独立台架兼容。这不是整工程的一键回退开关：将它改0只会关闭Sobel新门槛接入，不会恢复旧按键与菜单。完整回退使用保留的原工程。

本轮复现命令（在本工程PowerShell中运行；Vivado使用本机2018.3）：

```powershell
$Py='C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& .\tools\test_inline_controls.ps1 -VivadoBin 'D:\Xilinx\Vivado\2018.3\bin'
& $Py -X utf8 -B tools/test_inline_video.py
& $Py -X utf8 -B tools/test_inline_capture.py
& $Py -X utf8 -B tools/test_inline_retained.py
& $Py -X utf8 -B tools/test_fourkey_ui.py
& $Py -X utf8 -B tools/test_inline_cpu.py --test cpu8
& $Py -X utf8 -B tools/test_inline_cpu.py --test epaper
& $Py -X utf8 -B tools/finalize_inline_tests.py
& $Py -X utf8 -B tools/verify_inline_threshold_delivery.py
```

复跑会更新各自测试日志；最终汇总另保存了`reports/inline_threshold/final_logs`内的按SHA绑定证据。新增完整编译使用`tools/inline_threshold_build.py prepare/build/collect <全新英文目录>`；已有构建目录不可覆盖复用，collect拒绝覆盖现有outflow。编译与生成bit/hex不等于下载板卡。

## 测试与构建证据

`sim/tb_fourkey_menu.sv`验证8模式及4个阈值极值/步长/冻结裁剪场景，共5,301,248像素，检查数字、操作提示、抓拍单T、共享/本地字库一致、旧设置位无效、移动高亮帧驱动及回绕。PNG来自RTL RGB仿真，**不是上板照片**。

`sim/tb_fourkey_font.sv`验证每个时钟口8192地址及12000次固定种子随机读，共646144像素，检查1拍延迟；脚本另逐字符核对仍使用的原字形像素不变。`tools/test_fourkey_ui.py`创建新英文运行目录，记录输入SHA-256及日志最终标记，结果见`reports/fourkey/ui/results.json`。

真实RISC-V八模式、APB写入、CDC整帧提交和LVDS打包回归为`sim/tb_inline_cpu8.sv`；电子纸回归为`sim/tb_inline_epd_cpu.sv`。分别执行`python -B tools/test_inline_cpu.py --test cpu8`与`python -B tools/test_inline_cpu.py --test epaper`，日志和结果在`reports/inline_threshold/cpu8`、`epaper`。CPU8测试检验真实固件与显示集成；视觉内容由独立菜单像素测试覆盖。电子纸测试采用加速SPI/等待参数，不能当作实物SPI时序或屏幕刷新验收。

<!-- INLINE_FINAL_RESULTS -->

本轮最终32项源代码/日志SHA绑定检查全部通过，证据见`reports/inline_threshold/tests.json`及`final_logs/`。每项检查都要求完整最终PASS与仿真结束标记，不把中途某个模式的PASS当成整组通过。此前中断的CPU/电子纸日志单独归档，最终验收采用重新完整运行的结果。

| 验证层级 | 实际结果 |
| --- | --- |
| 参考与RTL逐像素 | 新旧原版双实例接收同输入，7×720p共6,451,200有效像素零差异，valid/VS/HS周期一致；默认参数算法输出与原版一致，界面文字属于有意变化 |
| 动态阈值RTL | 12帧、147,456像素；Canny/红边/赛博/左右对照真实响应，极值及有效视频中编辑不跳变 |
| 四键控制RTL | 95项检查、7次参数提交；另运行原IO28消抖/临界长按/上下文完整台架 |
| 抓拍集成RTL | 实际controls+parallel+frames，4算法、16锁帧；每张2304组32位数据逐对一致，46,080次HDMI标签采样正确；后续pending修改不影响保存T和元数据 |
| UI与字库RTL | 5,301,248菜单像素、646,144字库像素；267个仍共用的旧字形逐像素保留 |
| 原功能RTL回归 | 23项全部通过，含五手势录入/识别、DDR/FIFO、摄像头通路、PiP、四帧和人脸候选；旧控制/七场景台架分别由新版95项和更强原版golden替代 |
| 真实RISC-V CPU | 完整8模式、每模式614400像素，共4,915,200像素；真实APB/CDC/帧提交/LVDS通过 |
| 真实RISC-V电子纸 | 完整30033 SPI字节、两图层、reset/BUSY和刷新期间菜单状态更新通过；台架缩短等待参数，不是硬件刷新耗时测量 |
| 综合/接口/布局布线/位流 | 当前505个生产输入与新构建绑定，map/interface/pnr/pgm全部PASS |
| 实体板卡 | 未执行；未下载SRAM、未写Flash，实际相机FPS和端到端延迟均未测量 |

原版资源是本任务开始前已经完成且已核对哈希的历史构建，本轮没有重新编译原版；新版本为本轮新鲜完整构建。

| 资源 | 原版历史构建 | 本轮新构建 | 增量 |
| --- | ---: | ---: | ---: |
| XLR | 52744 | 52399 | -345 |
| RAM块 | 184 | 184 | +0 |
| DSP | 39 | 39 | +0 |
| 全局时钟GBUF | 14 | 14 | +0 |

全局最小setup/hold分别为 **+0.298/+0.026 ns**。原像素约束13.441ns（约74.4MHz）未改；clk_pixel setup/hold为+2.949/+0.026ns。新IO34唯一异步终点已核对为`controls/c/meta~FF.D`，其后同步路径未豁免；Efinity同步器报告无警告，本轮未另外执行形式CDC或MTBF测量。

已选择当前新构建到本目录`outflow/Ti60_Demo.bit`和`.hex`，没有覆盖继承的旧outflow；旧产物已在复制后移到`reports/inline_threshold/original_outflow`，只作历史。选择记录`selected_build.json`绑定来源、生产输入和所有输出SHA。

- bit SHA-256：`fdb21780fc3224777bcf691f39baff0323c9d5252432787e0d542a19eee038d6`
- hex SHA-256：`ba872a3f27c0a380147dc0410cdaf6d134008a34b19d7f47e737158c4d711f44`

原IO28/29/35管脚逐行核对不变，唯一新管脚A9/GPIOT_N_11为IO34、1.8V输入。综合警告按各自最后一次综合段比较为399→388；不是零警告工程。新增菜单两处窄化分别在有界绘制坐标内（ty0..15、ci0..2），K1/K2未使用移除是本轮有意屏蔽；未发现新增隐式网、功能悬空、锁存器或多驱动警告。四项interface物理邻距提示仍保留，其中LVDS邻距因新增IO34而扩展，需上板观察GPIO/LVDS耦合；没有删约束或降频来获得通过。详见`build_detail_audit.json`。

本轮实际完整编译使用的英文stage为`D:\Github_Project\fpga_build\inline_threshold_20261020_final`，执行`inline_threshold_build.py prepare`、`build`、`collect`三个阶段；既有stage不可原样重建，复现须改用新路径。

仿真预览：[八模式菜单](reports/fourkey/ui/eight_modes_rtl.png)、[默认边缘画面](reports/inline_threshold/video/default_modes_rtl.png)。这些是RTL输出渲染，均不是实物屏幕照片。

<!-- /INLINE_FINAL_RESULTS -->

## 上板先看三件事

1. 模式2～5从默认T开始，IO34减、IO35加；画面与T对应，模式2/5共享，红边与赛博互不串改。
2. 长按IO34切1/4/8步长，长按IO35复位，松开不多执行一次短按；模式6改由IO34录入确认，K1/K2无动作。
3. 冻结后调T，再保存不同算法/阈值的四帧，确认图片各自绑定T，之后调参不改变旧格。

新增两键尚未指定IO，未添加悬空顶层端口。六键阶段预定键5短按上一模式，键6承担切步长/复位、手势录入确认或四帧换算法等快捷操作，管脚确定后再接入；现有四键继续兼容。
