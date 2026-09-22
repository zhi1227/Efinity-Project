# Ti60F225 OV5640 + HDMI Canny 工程

本目录是针对易灵思 Ti60F225 开发板制作的可直接编译工程。摄像头初始化、DDR3 帧缓存、720p 时序及 HDMI 发送沿用官方 Demo；在 DDR3 读出与 HDMI 发送之间加入了流式 Canny 流水线。

## 图像链路

OV5640 -> RGB565 采集 -> DDR3 帧缓存 -> RGB888 -> Canny -> HDMI 1280x720

Canny 流水线每个像素时钟处理一个像素，包含：

1. RGB 转灰度；
2. 5x5 可分离高斯滤波，核系数为 [1 4 6 4 1]；
3. 3x3 Sobel，使用 |Gx| + |Gy|；
4. 四方向非极大值抑制；
5. 双阈值分类；
6. 3x3 滞后边缘连接。

默认低阈值为 40，高阈值为 80，可在 example_top.v 中修改 LOW_THRESHOLD 和 HIGH_THRESHOLD。

## 资源与时序（Efinity 2025.1，C4）

- XLR：7058 / 60800（11.61%）
- RAM10：87 / 256（33.98%）
- DSP：0 / 160
- Canny 模块：约 502 LUT、370 FF、41 RAM10
- clk_pixel 周期约束：13.441 ns（74.4 MHz）
- clk_pixel 最差建立裕量：+6.765 ns
- 全设计最差建立裕量：+0.186 ns
- 全设计最差保持裕量：+0.026 ns

资源足够且布局布线无时序违例。整机最紧路径位于官方 DDR3 控制器，不在 Canny 像素流水线中。

## 编译

在本目录运行：

    & 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj -f compile

生成文件位于 outflow，常用文件是 Ti60_Demo.bit 和 Ti60_Demo.hex。

## JTAG 下载

    & 'C:\Efinity\2025.1\bin\efx_run.bat' Ti60_Demo --prj -f program --pgm_opts mode=jtag

本次实机下载识别到的器件 ID 为 0x10660A79。

## 显示效果与调节

正常输出为黑底白色边缘。若边缘过多、噪点明显，提高两个阈值；若边缘断裂或太少，降低阈值。建议保持高阈值大约为低阈值的 2 倍，例如 40/80、50/100。

JTAG 下载掉电后会失效；需要掉电保存时，请使用 Efinity Programmer 将 Ti60_Demo.hex 写入板载 SPI Flash。

## 主要修改文件

- example_top.v：把 Canny 接到官方 LCD 时序和 HDMI 发送器之间；
- src/hls_canny/hls_canny_stream_720p.v：Canny 像素流水线；
- src/hls_canny/active_delay_ram.v：行缓存；
- Ti60_Demo.xml：工程源文件和 IP 配置。

原仓库的 HLS 参考源码也修复了函数声明大小写/参数不一致、错误的数组分区变量名，以及滞后连接把黑像素误判为强边缘邻居的问题。
