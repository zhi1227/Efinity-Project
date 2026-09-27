# 模式精简（2026-09-26）

## 当前版本：继续删除模式6、7

已删除6（原始肤色掩膜）和7（清理后肤色掩膜）的显示入口及专用延迟数据。保留肤色提取、形态学清理和连通区域检测，模式3仍显示红色肤色候选框。候选框检测不等于身份识别，四类表情模式14仍未实现。

| 模式 | 显示 |
|---|---|
| 0 | 原始彩色 |
| 1 | Canny黑白边缘 |
| 3 | 黑底白色Canny＋红色肤色候选框，默认 |
| 5 | 左灰度／右中值后二值Sobel |
| 10 | 原始彩色＋红色二值Sobel |
| 13 | 中值后的Sobel幅值灰度 |

- K1或UART `m`按 **0→1→3→5→10→13→0** 循环，共6个模式，编号不重排。
- UART `0/1/3/5`选择同编号模式，`a/d`选择10/13；`2/4/6/7/8/9/b/c`忽略，同时发生的K1事件仍有效。
- K2冻结、阈值`+/-`、恢复默认`r`保留。`e`仍忽略。
- 灰度显示延迟由9位缩为8位，中值Sobel显示延迟由10位缩为9位；检测链路和视频流水延迟不变。

Efinity完整构建通过，13条setup及13条hold关系均为正：最差setup +0.307ns，hold +0.026ns。

| 资源 | 删除6/7前 | 删除6/7后 | 本轮释放 |
|---|---:|---:|---:|
| XLR | 14363 | 14279 / 60800（23.49%） | 84 |
| RAM块 | 170 | 169 / 256（66.02%） | 1 |
| DSP | 4 | 4 / 160（2.50%） | 0 |

剩余46521 XLR、87 RAM块和156 DSP。候选框模块仍使用34 RAM块和4 DSP，不能把删除显示模式当作删除整条人脸候选检测链路。

本轮12项XSim回归全部通过，验证和位流目录为 `reports/remove_modes67_20260926/`，摘要及503项源码/位流SHA256清单见 `verification.json`、`build_manifest.json`。新增模式3端到端回归通过16384个像素及992个红框像素检查，覆盖候选框生成、显示及空帧清除；肤色/形态学内部参考检查和720p的2764800个显示像素检查均通过。新位流尚未下载，Flash未改。

```powershell
& ./tools/run_parallel_tests.ps1 -VivadoBin 'D:/Vivado/Vivado/2019.2/bin' -OutputDir reports/remove_modes67_20260926/sim
& 'D:/Efinity/bin/python3.bat' 'D:/Efinity/scripts/efx_run.py' Ti60_Demo.xml --flow compile --output_dir reports/remove_modes67_20260926/build --work_dir reports/remove_modes67_20260926/work
```

## 历史版本：删除模式2、4、8、9

在已删除11、12的基础上，继续移除2（彩色Canny与候选框叠加）、4（框内外区别显示Canny）、8（原始Sobel幅值灰度）、9（原始Sobel伪彩色）。模式编号不重排，默认仍为3。

| 模式 | 显示 |
|---|---|
| 0 | 原始彩色 |
| 1 | Canny黑白边缘 |
| 3 | 黑底白色Canny＋红色肤色候选框，默认 |
| 5 | 左灰度／右中值后二值Sobel |
| 6 | 原始肤色掩膜 |
| 7 | 清理后肤色掩膜 |
| 10 | 原始彩色＋红色二值Sobel |
| 13 | 中值后的Sobel幅值灰度 |

- K1或UART `m`按 **0→1→3→5→6→7→10→13→0** 循环，共8个有效模式。
- UART `0/1/3/5/6/7`选择同编号模式，`a/d`选择10/13；`2/4/8/9/b/c`忽略，且不吞掉同时发生的K1事件。
- K2冻结、阈值`+/-`和恢复默认`r`保留。表情模式14尚未实现，`e`仍忽略。
- 已去掉原始Sobel幅值显示接口、8位饱和显示数据、伪彩色色表以及模式2/4使用的框内外颜色选择。原始Sobel仍供模式10使用，其延迟缓存现在只保存1位二值边缘；中值路径仍供5/13使用。
- 新一轮测试和构建在 `reports/remove_modes2489_20260926/`；新位流为其 `build/Ti60_Demo.bit`。不下载板卡、不写Flash。
- `reports/remove_modes89_20260926/`是追加删除2/4之前被中断的过程记录，不是最终验证结果。

本轮11项XSim回归和Efinity完整构建全部通过，13条setup和13条hold关系均为正：最差setup +0.317ns，hold +0.026ns。模式10在低阈值40/80/160下通过独立图像参考；720p检查覆盖2764800个显示像素。

| 资源 | 本轮前（已删11/12） | 本轮后 | 本轮释放 |
|---|---:|---:|---:|
| XLR | 14382 | 14363 / 60800 | 19 |
| RAM块 | 178 | 170 / 256 | 8 |
| DSP | 4 | 4 / 160 | 0 |

相对最初14模式版本，累计释放1809 XLR、16 RAM块、10 DSP。目前剩余86 RAM块和156 DSP。原始Sobel运算仍供模式10使用，删除8/9不会把这条共享运算路径全部移除。

本轮验证摘要和源码/位流SHA256清单分别位于 `reports/remove_modes2489_20260926/verification.json`、`build_manifest.json`。新位流尚未下载，Flash未改。

复现本轮验证：

```powershell
& ./tools/run_parallel_tests.ps1 -VivadoBin 'D:/Vivado/Vivado/2019.2/bin' -OutputDir reports/remove_modes2489_20260926/sim
& 'D:/Efinity/bin/python3.bat' 'D:/Efinity/scripts/efx_run.py' Ti60_Demo.xml --flow compile --output_dir reports/remove_modes2489_20260926/build --work_dir reports/remove_modes2489_20260926/work
```

## 历史版本：仅删除11和12

以下操作、资源和验证描述的是第一轮版本，当前操作请以最上方6模式列表为准。

当前源码移除模式11（左灰度/右中值灰度）和模式12（中央ROI圆形/矩形识别）。其他模式保持原编号，仍默认模式3。

## 操作

- K1和UART `m`：3→4→5→6→7→8→9→10→13→0→1→2→3，共12个有效模式。
- UART `0`～`9`选择同编号模式，`a`选择10，`d`选择13；`b`、`c`不改变模式，也不会吞掉同时发生的K1事件。
- K2冻结/恢复，`+/-`阈值调整和`r`恢复默认保持原有行为。
- 模式13仍为中值后的Sobel幅值灰度。模式5仍为左灰度/右中值后二值Sobel。
- 表情模式14是后续计划，本次没有增加模型或开放入口，UART `e`仍被忽略。

## 电路变化

- 删除 `edge_shape_roi` 源码、顶层例化、工程XML引用及专用 `tb_shape` 测试。
- 删除模式12的ROI边框、形状框和RECT/CIRC/NONE文字；HUD保留模式号和LIVE/HOLD。
- 删除模式11的中值灰度输出接口；`u_raw_preview_delay`由17位缩至9位，仅保留原始Sobel幅值和二值边缘。流水延迟保持不变。
- 保留共享的中值滤波和Sobel，因为模式5、13仍依赖它们。
- 没有修改摄像头、DDR、HDMI、引脚或时序约束。

## 验证

当前回归入口为 `tools/run_parallel_tests.ps1`，共11项测试。更新控制测试覆盖跳过11/12、忽略b/c、按键与UART同时发生的仲裁；显示参考继续覆盖8帧65536像素，包含保留的Sobel、Canny及原图路径。

11项XSim 2019.2回归全部通过；Efinity 2025.1.110.5.9完成综合、接口、布局布线、位流生成和导出。720p精确比较覆盖2764800个显示像素；增强模式参考覆盖65536像素。

| 项目 | 删除前 | 删除后 | 释放 |
|---|---:|---:|---:|
| XLR | 16172 | 14382 / 60800 | 1790 |
| RAM块 | 186 | 178 / 256 | 8 |
| DSP | 14 | 4 / 160 | 10 |

最差setup余量+0.247ns，最差hold余量+0.010ns；13条setup、13条hold关系均为正。约束、引脚、厂商IP和板级顶层哈希未变。构建保留工具及既有闲置接口告警，不宣称零告警。

新位流：`reports/remove_modes_20260926/build/Ti60_Demo.bit`。验证摘要和文件哈希分别保存为该报告目录下的`verification.json`、`build_manifest.json`。

本轮独立输出目录：`reports/remove_modes_20260926/`。最终验证结果以此目录的记录为准；9月25日的PASS、资源、位流及清单均为历史证据。

复现仿真：

```powershell
& ./tools/run_parallel_tests.ps1 -VivadoBin 'D:/Vivado/Vivado/2019.2/bin' -OutputDir reports/remove_modes_20260926/sim
```

复现构建（生成配置文件，不下载硬件）：

```powershell
& 'D:/Efinity/bin/python3.bat' 'D:/Efinity/scripts/efx_run.py' Ti60_Demo.xml --flow compile --output_dir reports/remove_modes_20260926/build --work_dir reports/remove_modes_20260926/work
```

本轮没有JTAG下载或Flash写入，板上仍运行原有配置。
