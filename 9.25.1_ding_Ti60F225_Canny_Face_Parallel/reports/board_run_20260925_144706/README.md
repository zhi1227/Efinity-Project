# 2026-09-25 板卡运行记录

用户要求运行本目录工程，确认板卡已经连接。2026-09-25 14:47:48 已完成 JTAG 临时配置；未写 Flash。

- 实际工程：`D:\yilingsi_fpga\Efinity_Project\2026.9.25\9.25.1_ding_Ti60F225_Canny_Face_Parallel`。
- 下载器：FT232H / Single RS232-HS，`0403:6014`。
- 链上恰有一个 Ti60，ID `0x10660A79`。
- 下载文件：`reports/contest_20260925/final/Ti60_Demo.bit`。
- SHA256：`78f227940dfc785eb368d5c685917adbb78da4abcdacce6e4be5d601a463eeb0`。
- 505 项文件逐项核对一致，`outflow` 的 bit 与冻结 bit 相同；本轮未修改 RTL，未重跑已经通过的构建。
- 复核已有 12 项仿真日志均包含 PASS 和正常结束，没有失败标记；Efinity map/interface/pnr/pgm 通过。
- 13 条 setup 和 13 条 hold 关系均为正；最小余量分别为 +0.302 ns、+0.026 ns。
- JTAG 以 6 MHz 完成，程序退出码 0；见 `jtag_detect.log`、`jtag_program.log` 与 `verification.json`。

## 现场确认

尚待用户观察；成功下载不等于 HDMI 与按键实测完成。

1. 初始 `M:03 LIVE`：黑底白色 Canny 边缘。
2. 按 K1 两次到 `M:05`：左侧灰度，右侧白色 Sobel 边缘。
3. 按 K2 后显示 HOLD，移动物体时图像保持；再次按 K2 恢复 LIVE 和实时画面。

本工程的人脸框仍为肤色候选区域；此轮没有合并独立 Haar 工程。此记录只验证当前工程的下载，不继承其他版本的实物效果结论。
