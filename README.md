# Efinity FPGA 图像处理工程

最后更新：**2026-09-22（北京时间，UTC+8）**

本仓库用于整理易灵思 Ti60F225 开发板的学习例程和实时图像处理工程，当前重点是全国大学生嵌入式芯片与系统设计竞赛 2026 易灵思方向的赛题四“基于 FPGA 的实时图像边缘检测系统”。

主要硬件链路为：

~~~text
OV5640 摄像头 → FPGA 图像处理 → DDR3 帧缓存 → HDMI 1280×720
~~~

## 组员命名规则

- 目录名包含 **ding**：丁组员完成或主要维护。
- 目录名包含 **liu**：刘组员完成或主要维护。
- 目录名没有组员标记：公共工程、历史工程或尚未标注负责人。

新增工程请尽量采用“日期_组员_项目名称”的格式，例如：

~~~text
9.22.1_ding_Ti60F225_OV5640_HLS_Canny
9.23.1_liu_Ti60F225_OV5640_Median_Sobel
~~~

## 重点工程

| 目录 | 负责人 | 说明 | 状态 |
| --- | --- | --- | --- |
| **Ti60F225_GitHub_FPGA_Sobel_Port/** | 公共 | OV5640、DDR3、Sobel、HDMI 720p；K1 切换灰度边缘与赛博伪彩边缘 | 已完成编译和 JTAG 实机下载 |
| **9.22.1_ding_Ti60F225_OV5640_HLS_Canny/** | 丁组员 | 将 HLS Canny 思路改写为 Ti60F225 原生流式 RTL，包含高斯、Sobel、NMS、双阈值和局部滞后连接 | 已通过编译、时序和 JTAG 下载 |
| **9.21.1_Ti60F225_OV5640_Face_Reproduction/** | 未标注 | 彩色人脸候选分析、流式 Canny、候选框稳定和 HDMI 叠加 | 已提供说明、仿真与发布位流 |
| **Ti60F225_9.22.1/** | 未标注 | 9 月 22 日同步的 Ti60F225 图像处理集成工程，包含设计文档与 Efinity 工程 | 开发中 |
| **Ti60F225_OV5640_Face_Reproduction/** | 公共/历史 | 早期 OV5640 人脸候选复现工程 | 历史参考 |

## 参考工程

| 目录 | 用途 |
| --- | --- |
| **FPGA_Sobel/** | 原始 GitHub Sobel 工程，面向 Altera/Quartus，不能直接下载到 Ti60F225 |
| **Hardware-Implementation-of-the-Canny-Edge-Detection-Algorithm/** | 第三方 Canny RTL、C++ 模型和仿真参考；以 Git 子模块保存，来源为 DOUDIU 的开源仓库 |

克隆仓库时若需要同时取得 Canny 参考工程，请使用：

~~~bash
git clone --recurse-submodules https://github.com/zhi1227/Efinity-Project.git
~~~

已有普通克隆可执行：

~~~bash
git submodule update --init --recursive
~~~

## 赛题四当前进度

当前 Sobel 工程已经实现：

- OV5640 摄像头采集；
- 1280×720 HDMI 稳定显示；
- 移位加法加权灰度；
- 3×3 Sobel 的 Gx、Gy 和 |Gx| + |Gy|；
- 两行 Line Buffer；
- DDR3 帧缓存；
- 实时灰度梯度和伪彩边缘显示。

正式提交赛题四前仍需优先补齐：

- 参数化的二值化阈值；
- 原图与边缘分屏、画中画或彩色叠加；
- 按键实时增减阈值；
- 建议加入 3×3 中值滤波；
- 演示视频和测试说明。

Canny 属于赛题四的高阶挑战，不替代上述基础要求。推荐先完善稳定的 Sobel 赛题版本，再加入 Sobel/Canny 对比模式。

## 打开与编译

工程主要使用 Efinity 2025.1。进入具体项目目录后打开 **Ti60_Demo.xml**，或在 PowerShell 中运行：

~~~powershell
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj -f compile
~~~

临时 JTAG 下载：

~~~powershell
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj -f program --pgm_opts mode=jtag
~~~

JTAG 下载写入易失 SRAM，断电后需要重新下载。写入 SPI Flash 前应确认工程、目标器件和启动模式。

## 仓库维护约定

- 提交 RTL、Efinity 工程文件、约束、README、必要 IP 配置和已验证发布位流。
- 不提交 work_syn、work_pnr、仿真数据库和完整 outflow 等可重新生成的缓存。
- 已验证位流优先放在项目的 bitstream/ 或 release_日期/ 目录。
- 第三方完整仓库优先使用 Git 子模块，并在 README 中注明来源。
- 提交信息应说明日期、负责人、目标板卡和主要功能。

## 更新记录

### 2026-09-22

- 同步远程主分支的最新工程。
- 增加丁组员的 Ti60F225 HLS Canny 移植工程。
- 增加 OV5640 人脸候选与 Canny 集成工程。
- 增加第三方 Canny RTL 参考仓库。
- 更新项目索引、组员命名规则、赛题四进度和仓库清理规则。

### 2026-09-21

- 完成 Ti60F225 Sobel 黑白/赛博双模式工程。
- 完成编译和 JTAG 下载验证。
