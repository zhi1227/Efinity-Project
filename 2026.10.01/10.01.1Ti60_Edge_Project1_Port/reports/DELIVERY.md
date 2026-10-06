# 交付与验证状态

记录时间：2026-09-29T20:59:17.803454。

## 已完成

- 独立 Ti60F225/C4 工程；原项目 RTL 与参考副本逐文件核对一致。
- 本次修订：M7 肤色掩膜、圆盘低通、开运算和最大有效连通域；A/F/R 是真实面积、千分填充率、千分高宽比。默认仍为M3，K1换模式，K2在M7调肤色下限。
- Efinity 2025.1 完整综合、布局布线、位流生成通过。
- 13 组 setup、13 组 hold 全部非负；最小裕量分别为 **0.317 ns / 0.025 ns**。
- JTAG SRAM 下载：**未执行**，Ti60 ID `0x10660A79`，6 MHz；没有写 Flash。
- 下载日志：``；构建日志：`reports/build_20260929_204725.log`。

## 仿真证据

- PASS 2000 median and 2000 L2 Sobel/Prewitt random neighborhoods
- PASS 2021 independent skin RGB/threshold cases including strict R-G boundaries and valid/coordinate alignment
- PASS M3 boot default, buttons debounce, boot-held, short/long, no release duplicate, frame commit, wrap, saturation
- PASS 31 flood-fill-reference CCL frames: exact geometry, union, diagonal, ties, borders, exact 64 candidates, candidate/label/FIFO overflow, deadline, removal, class boundaries and stability
- PASS 720p CCL at 1650 clocks/line and 8250-clock frame gap: A=65524 F=999 R=1000, next empty frame clears all results
- PASS video FULL=0 frames=64 pixels=49152 RGB/DE/HS/VS exact
- PASS video FULL=1 frames=3 pixels=2764800 RGB/DE/HS/VS exact
- PASS decimal conversion, HUD skin/F/A/R labels, OVF and plus glyph; emitted RTL preview

数字转换和屏幕字符已通过 RTL 测试，仿真输出预览见 `hud_preview.png`，它不是实机 HDMI 照片。

## 资源与文件

- XLRs: 11872 / 60800 (19.53%)
- Memory Blocks: 182 / 256 (71.09%)
- DSP Blocks: 21 / 160 (13.12%)

- 位流：`outflow/Ti60_Demo.bit`（2,258,175 字节）。
- SHA256：`B771A66506D7B6430A66BD204C41D842B431DE7F183B30010A04F55F0434B52E`。
- 工程源文件、IP 和 bit 的哈希：`reports/delivery_hashes.json`。
- 定量结果：`reports/validation_summary.json`。
- 源清单保留所有实际实例化的板级模块，包括 `Sensor_Image_XYCrop.v`；未使用原 Cyclone IV SDRAM、PLL、ALTSQRT 和引脚约束。

## 实机边界

本修订下载状态：paused_by_user_before_power_off。下载是否成功以上方JTAG结果为准；尚未收到本修订的HDMI画面和按键反馈，真人三类手势的效果仍待现场观察。

旧的外接框/极值更新次数和200/300门限已停用。新分类使用F/R初始区间及连续三帧确认。真人样本尚未采集，现场校准和分类验收未完成；合成图形仿真不能证明真人准确率。见 `reports/BOARD_ACCEPTANCE.md` 和 `reports/FIELD_CALIBRATION.csv`。

## 告警核对

已核对输出引脚报告和本地核心板 V1.4 原理图第 7 页网络表：K1=N2/CSI、K2=M2/CSO，均为 1.8 V LVCMOS；K3=J5/CRESET_N，为专用硬件复位，不参与模式选择。按 K3 可能重新从 Flash 配置，需重下载本 SRAM 版本。板级工程保留未启用 CSI/DSI/LCD 接口的约束及相关工具告警；这些并非本次新增图像链路。新链路完全运行在已约束的 `clk_pixel` 域，异步按键采用两级同步与消抖。

综合中仍有底层 IP 未使用端口、常量、总线截位，以及 DSP 打包后的未用时钟使能告警；原始日志保留用于追溯。本次没有通过新增 false path 掩盖像素处理时序。映射网表核对了3540个Project1原语，2789个活动时钟连接均为clk_pixel；18个CE恒低DSP的已启用寄存级均绕过CE，见processing_clock_audit.json。
