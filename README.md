# Efinity FPGA 图像处理工程

易灵思赛题四：基于 FPGA 的实时图像边缘检测系统。平台：**Ti60F225＋OV5640 DVP＋DDR3＋720p HDMI**。

## 最新主工程：9.27.1

请进入 [9.27.1_ding_Ti60F225_Canny_Face_Parallel](9.27.1_ding_Ti60F225_Canny_Face_Parallel/)，在 Efinity 中打开 `Ti60_Demo.xml`。旧日期工程保留历史，不要混用旧源码、bit 和新版报告。

本版在 9.25.1 基础上**分三轮精简显示模式**（先删 11/12，再删 2/4/8/9，最后删 6/7），由 14 模式收敛为 6 个有效模式（0/1/3/5/10/13，默认 3），并新增电子纸＋Flash 外设底板规划文档。

- [模式精简过程与当前操作](9.27.1_ding_Ti60F225_Canny_Face_Parallel/README_模式精简.md)
- [最新验证/位流目录 remove_modes67_20260926](9.27.1_ding_Ti60F225_Canny_Face_Parallel/reports/remove_modes67_20260926/)（`verification.json`、`build_manifest.json`、`build/Ti60_Demo.bit`）
- [电子纸/Flash 底板接线方案](9.27.1_ding_Ti60F225_Canny_Face_Parallel/reports/epaper_flash_carrier_20260926/底板原理图接线方案.md)
- [电子纸＋RISC-V 评估](9.27.1_ding_Ti60F225_Canny_Face_Parallel/reports/vision_riscv_epaper_assessment_20260926/评估.md)

**注意：** `outflow/Ti60_Demo.bit` 仍是 9.25.1 旧位流（SHA256 `78f227…`）；本版最新位流为 `reports/remove_modes67_20260926/build/Ti60_Demo.bit`（SHA256 `ff1451…`）。**新位流尚未 JTAG 下载、未写 Flash**，实物效果待确认；9.25.1 的板卡运行记录不代表本版已上板。

## 按键与显示（9.27.1 有效模式）

- 默认模式 **3**，屏幕显示 `M:03 LIVE`。
- **K1**：每按下并松开一次，按 **0→1→3→5→10→13→0** 循环，共 6 个模式，编号不重排。
- **K2**：冻结当前 DDR 显示帧，显示 HOLD；再按恢复 LIVE。冻结时可以切模式比较同一原图。
- 约 20ms 消抖，长按不连跳；开机按住须先释放。**K3 是配置复位，不是功能键。**

| 模式 | 功能 |
|---|---|
| 0 | 原始彩色 |
| 1 | Canny 黑白边缘，不画候选框 |
| 3（默认） | 黑底白色 Canny＋红色肤色候选框 |
| 5 | **左灰度／右中值后的二值 Sobel**，青色分界线，基础验收模式 |
| 10 | **原彩色＋红色 Sobel 边缘**，彩色叠加验收模式 |
| 13 | 中值后的 Sobel 幅值灰度 |

已删除模式的检测链路**仍在运行**：肤色提取、形态学清理、CCL 和候选框生成保留（模式 3 依赖）；原始 Sobel 二值边缘保留（模式 10 依赖）。删除的仅是显示分支与延迟缓存，不是删除整条检测链路。模式 5 是同幅图左右区域对照。UART 保留 115200 8N1：`0/1/3/5` 选同编号模式，`a/d` 选 10/13，`m` 下一模式，`r` 恢复默认，`+/-` 阈值仍有效；`2/4/6/7/8/9/b/c` 忽略。不要将 3.3V/5V 裸串口直接接到 1.8V IO。

K1 = N2 / GPIOL_P_02，K2 = M2 / GPIOL_N_02，均 1.8V、低有效。原闲置并行 LCD DE/时钟引脚用于按键，**不得同时连接并行 LCD**；HDMI、相机和 DDR 引脚保持原配置。

## 实际算法与完成边界（9.27.1）

```text
OV5640 → DDR3 四帧缓冲/冻结 → 同一显示像素流
  ├─ 灰度 → Sobel → 二值边缘（模式10红边）
  ├─ 灰度 → 3×3 中值 → Sobel → 二值 / 幅值灰度
  ├─ 灰度 → 3×3 高斯 → Sobel → NMS → 双阈值 → 局部滞后
  └─ YCbCr 肤色 → 多数/腐蚀 → 网格连通域 → 候选框
                      对齐融合 → 状态文字 → 1280×720 HDMI
```

- 灰度 `(77R+150G+29B)>>8` 使用移位加法；Sobel 为 `|Gx|+|Gy|`。
- 中值为 3×3 比较网络；高斯核为 `[1 2 1;2 4 2;1 2 1]/16`，加 8 后右移 4。
- Canny 仍为**局部八邻域滞后**，不能递归连接任意长度弱边链，不是完整标准 Canny。
- 人脸部分仍为**肤色候选**，不是身份识别或精准脸部语义轮廓；尚未合并独立 Haar。手、脖子和暖色背景可能误检，真实标定尚未完成。
- 形状识别（原模式12）已随模式精简移除；电子纸/Flash 底板仅完成接线规划，未改 RTL 或管脚约束。
- 冻结锁定 DDR 读槽，采集继续使用其他槽；在帧边界生效，不停止 HDMI 时钟。

| 赛题项目 | 当前状态 |
|---|---|
| 摄像头、灰度、行缓存、二值 Sobel、HDMI 分屏 | 代码/仿真已有；补实物稳定性与演示 |
| 中值去噪、DDR 缓存/冻结、原彩色边缘叠加 | 已实现并通过对应仿真，现场效果待验 |
| 按键实时阈值 | 按本阶段要求暂缓 |
| Canny 升级 | 已补高斯；完整递归滞后尚未实现 |
| 人脸准确率、源帧统计、无丢帧、长运行、新版脱机启动 | 尚不能宣称完成 |

DDR 使用 Efinity `DdrCtrl`，生成层次含 `efx_ddr3_soft_controller`。赛题“DDR 硬核控制器”措辞应向老师/赛方如实确认，不将软件生成控制器宣传为物理硬核。

## 本版资源与验证

| 指标 | 2026-09-26 构建结果（删除模式6/7后） | 9.25.1 对照 |
|---|---:|---:|
| XLR | 14,279 / 60,800（23.49%） | 16,172（26.60%） |
| RAM | 169 / 256（66.02%） | 186（72.66%） |
| DSP | 4 / 160（2.50%） | 14（8.75%） |
| 最差 setup / hold | +0.307 / +0.026 ns | +0.302 / +0.026 ns |
| 时钟关系 | 13 条 setup、13 条 hold 均通过 | 同 |

累计相对 14 模式版本释放 1,893 XLR、17 RAM、10 DSP。候选框模块仍占用 34 RAM 块和 4 DSP，不能把删除显示模式当作删除整条人脸候选检测链路。

本轮 12 项 XSim 回归全部通过（含新增 `tb_face_display` 模式3端到端检查：16,384 像素及 992 个红框像素）；720p 逐像素检查覆盖 2,764,800 显示像素。503 项源码/位流 SHA256 清单已核对，见 `remove_modes67_20260926/verification.json` 与 `build_manifest.json`。

最新位流 SHA256：`ff1451127fc094adee2caf8ba5cd0f49eb4980c4a7b50e598d2c5521aca364d3`。**新位流尚未下载板卡、未写 Flash**；9.25.1 的 JTAG 下载记录（`0x10660A79`）不适用于本版。

## 编译与团队协作

进入最新工程目录后运行：

```powershell
.\tools\run_parallel_tests.ps1 -OutputDir reports\my_new_run\sim
& 'C:\Efinity\2025.1\bin\python3.bat' 'C:\Efinity\2025.1\scripts\efx_run.py' Ti60_Demo.xml --flow compile
```

综合/实现使用 Efinity 2025.1；脚本中的 Vivado 2018.3 XSim 仅用于 RTL 仿真。新机器需安装工具并调整本机路径。默认参数在 `src/parallel/vision_config.vh`，顶层显式启用高斯和状态文字；修改后必须重新验证，不用旧日志给新 bit 背书。

- `ding`：丁组员完成或主要维护；`liu`：刘组员完成或主要维护。
- [Sobel 移植参考](Ti60F225_GitHub_FPGA_Sobel_Port/)：灰度幅值/赛博配色参考。
- [9.25.1 上一版主线](9.25.1_ding_Ti60F225_Canny_Face_Parallel/)、[9.22.2 历史主线](9.22.2_ding_Ti60F225_Canny_Face_Parallel/)、[9.22.1 HLS 思路工程](9.22.1_ding_Ti60F225_OV5640_HLS_Canny/)：保留历史，不是最新入口。
- [FPGA_Sobel](FPGA_Sobel/) 与 [DOUDIU Canny 子模块](Hardware-Implementation-of-the-Canny-Edge-Detection-Algorithm/) 保留原来源；子模块用 `git submodule update --init --recursive` 获取。
- 本次发布范围为 9.27.1 与 README。其他未跟踪旧目录、外设资料和本地总体规划不混入本次提交。
- 源码/IP、测试、当前 bit/hex、资源/时序保留；各轮验证清单与关键构建产物入仓，约 99MB/轮的 build/work 缓存、旧 Flash 备份和历史快照仅本地保留，详见 [发布说明](9.27.1_ding_Ti60F225_Canny_Face_Parallel/REPOSITORY_RELEASE.md)。

## 更新记录

- **2026-09-27**：发布 9.27.1；分三轮删除显示模式 11/12、2/4/8/9、6/7，收敛为 6 模式（0/1/3/5/10/13）；新增 `tb_face_display` 端到端回归与电子纸/Flash 底板规划文档；累计释放 1,893 XLR、17 RAM、10 DSP；12 项回归通过，新位流未上板、未写 Flash。
- **2026-09-25**：发布 9.25.1 增强版；14 模式、K2 冻结、高斯路径、Sobel 细节/赛博/彩色叠加、形状实验；12 项回归与 JTAG 下载有记录，Flash 未更新。
- **2026-09-24**：K1 八模式、观察功能和旧版 Flash 固化，不代表新版已固化。
- **2026-09-22**：Canny/肤色候选双分支基线。
- **2026-09-21**：Sobel 灰度/伪彩双模式。
