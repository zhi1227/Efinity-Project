# Ti60F225 实时 Sobel 边缘检测项目

## 项目简介

本项目将 GitHub FPGA_Sobel 工程的 Sobel 算法移植到易灵思 Ti60F225 开发板，使用 OV5640 摄像头采集图像，经 DDR3 缓存后进行实时边缘检测，通过 HDMI 输出 1280×720 画面。

图像处理流程：摄像头采集 → DDR3 缓存 → RGB 转灰度 → Sobel 梯度计算 → 黑白或赛博配色 → HDMI 显示。

原始 GitHub 工程面向 Altera EP4CE10，不能直接用于易灵思。本工程保留其加权灰度转换和 Sobel 梯度幅值显示思路，适配了易灵思行缓存，并使用已有 Ti60F225 工程的摄像头、DDR3 和 HDMI 通路。它是移植修改版，不是未经修改的官方 Demo。

## 硬件与软件

- 开发板：易灵思 Ti60F225。
- 摄像头：OV5640，连接 DVP Sensor 接口。
- 显示器：连接开发板 HDMI 输出。
- 下载器：FT232H，当前使用 libusb-win32 驱动。
- 开发软件：Efinity 2025.1。

## 按键操作

使用小核心板上丝印为 **K1** 的按键，每按下并松开一次，切换一次模式：

| 模式 | 显示效果 |
| --- | --- |
| 黑白边缘（默认） | 强边缘为白色，弱边缘为灰色，平坦区域较黑 |
| 赛博边缘 | 黑色背景，根据边缘强度显示蓝、青、紫、粉色 |

赛博模式是边缘强度的伪彩色显示，不是摄像头原始彩色画面。按键已加入约 20 ms 消抖，长按只切换一次，显示模式在场同步期间更新。

K1 对应 GPIOL_P_02（封装 N2）。本版本将该引脚从并行 LCD 的 DE 输出改为按键输入，因此不要同时使用并行 LCD。K2 未配置显示切换功能；**K3 是硬件配置复位键，不要把它当作切换键。**

## 如何编译与下载

1. 在 Efinity 中打开本目录的 `Ti60_Demo.xml`。
2. 执行完整编译，确认综合、接口检查、布局布线和位流生成通过。
3. 打开 Efinity Programmer，选择 FT232H 下载器，下载模式选择 JTAG。
4. 选择 `outflow/Ti60_Demo.bit`，开始下载。
5. 查看 HDMI 画面，短按核心板 K1 测试两种模式切换。

也可在本工程目录打开 PowerShell，执行：

```powershell
# 编译
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj --flow compile

# 临时下载到 FPGA
& 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo.xml --flow program --pgm_opts mode=jtag
```

当前使用 JTAG 下载到 SRAM，断电后不会保留本次程序；重新上电可能加载 Flash 中原有程序，需要重新下载本工程。

## 主要文件

| 文件或目录 | 作用 |
| --- | --- |
| `Ti60_Demo.xml` | Efinity 工程入口 |
| `Ti60_Demo.peri.xml` | 引脚及接口配置 |
| `example_top.v` | 顶层模块，连接摄像头、缓存、算法和显示 |
| `src/sobel/github_sobel_stream_720p.v` | 灰度转换、Sobel 算法和双模式配色 |
| `src/sobel/sobel_line_delay.v` | 图像行缓存 |
| `src/sobel/edge_mode_button.v` | K1 同步、消抖及模式切换 |
| `reference_quartus/` | 原始 Quartus 算法参考文件 |
| `outflow/Ti60_Demo.bit` | 编译生成的 JTAG 下载文件 |
| `backup_before_cyber_20260921/` | 加入双模式前的源码、约束和可下载位流备份 |

## 当前验证情况

2026-09-21，双模式版本已通过完整编译并成功通过 JTAG 下载。像素时钟约 74.399 MHz，建立时间余量 +5.520 ns，保持时间余量 +0.035 ns。实际按键切换和显示效果仍需现场观察确认。

当前实现的是 Sobel 边缘检测与配色显示，不包含 Canny、人脸识别或低功耗实测功能。
