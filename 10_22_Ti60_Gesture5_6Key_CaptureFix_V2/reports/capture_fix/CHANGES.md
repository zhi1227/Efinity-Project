# 逐文件修改清单

原版：`D:\yilingsi_fpga\Efinity_Project\2026.10.20\10_20_ding_Ti60_Gesture5_4Key_InlineThreshold`。当前工程：`D:\yilingsi_fpga\Efinity_Project\2026.10.20\10_20_ding_Ti60_Gesture5_6Key_CaptureFix`。以下行号属于最终源码；完整SHA-256见 `changed_files.json`。

| 文件 | 修改后起始行（主要差异块） | 用途 |
|---|---|---|
| `example_top.v` | 921, 983, 985, 1082, 1085, 1147 | 连接 snap_abort、主读完整帧状态；Canny菜单状态传LOW/HIGH。 |
| `rtl/menu8_renderer.v` | 6, 10, 25, 38, 40, 135, 138, 150, 167 | 显示顺序映射；LOW/HIGH选择与步长提示；抓拍实际阈值及忙/失败提示。 |
| `rtl/menu_glyph_rom.v` | 1, 4, 19, 23, 30, 36, 42, 47, 53, 59, 81, 91, 168, 185, 188, 229, 232, 240 等 | 由统一字模生成流程重新生成；保持既有压缩存储结构。 |
| `rtl/shared_glyph_rom.v` | 14, 20, 25, 28, 66, 69, 75, 79, 81, 87, 89, 92, 95, 97, 99, 111, 112, 127 等 | 由统一字模生成流程重新生成；保持既有压缩存储结构。 |
| `rtl/vision6_glyph_rom.v` | 37, 573 | 由统一字模生成流程重新生成；保持既有压缩存储结构。 |
| `rtl/vision8_base_axi.v` | 80, 110, 125, 467, 482 | 读像素计数、FIFO空读/复位忙、read_frame_good/read_frame_bad。 |
| `rtl/vision8_controls.v` | 2, 4, 9, 55, 88, 107, 124, 138, 146, 148, 152, 162, 169, 171, 174, 177 | 六键消抖/上下文；模式映射；Canny联合/独立调整和成对限幅；四帧退出清空。 |
| `rtl/vision8_ddr.v` | 3, 82, 85, 102, 113, 135, 146, 179, 183, 187, 191, 205 | snap_abort跨时钟；缺少snap_end仍能失败完成；AW/W/B安全排空；摄像头已呈现W拍保持。 |
| `rtl/vision8_frames.v` | 3, 12, 20, 23, 61, 64, 70, 77, 89, 95, 103, 139, 140, 149, 158, 160, 173, 183 等 | 持续主读；源帧/坐标/像素数校验；冻结等待、超时、取消排空；发布清空优先级；保存标签。 |
| `src/parallel/vision8_modes.vh` | 1 | 新增slot_to_mode和mode_to_slot；内部语义编号保持不变。 |
| `Ti60_Demo.pt.sdc` | 748 | 仅追加K1/K2端口至首级同步器D端的两条约束。 |

## 生成的数据文件

以下文件来自更新后的菜单/HDMI字模及压缩字库生成，不是视频帧缓存：

- `menu_font.hex`
- `menu_font_bank0.hex`
- `menu_font_bank1.hex`
- `menu_font_bank2.hex`
- `menu_font_bank3.hex`
- `menu_font_bank4.hex`
- `shared_font.hex`
- `shared_font_bank0.hex`
- `shared_font_bank1.hex`
- `shared_font_bank2.hex`
- `shared_font_bank3.hex`
- `shared_font_bank4.hex`
- `shared_font_bank5.hex`
- `shared_font_bank6.hex`
- `shared_font_bank7.hex`
- `shared_font_bank8.hex`
- `shared_font_index_bank0.hex`
- `shared_font_index_bank1.hex`
- `shared_font_index_bank2.hex`
- `shared_font_index_bank3.hex`
- `shared_font_index_bank4.hex`

## 字模源与验证工具

- `tools/generate_font.py`、`tools/hdmi_text.json`：新模式编号、K1/K2说明及LOW/HIGH字模来源。
- `tools/run_capture_fix.py`：新英文目录、带时间戳且绑定输入SHA的单项RTL仿真。
- `tools/test_capturefix_final.py`：最终30项回归。
- `tools/test_capturefix_video.py`、`tools/test_capturefix_ui.py`、`tools/test_capturefix_cpu.py`：算法一致性、UI/字库、CPU/电子纸专项。
- `tools/capture_fix_build.py`：全新英文路径完整构建并核对后收集bit/hex。
- `tools/verify_capturefix_delivery.py`：原工程保护、测试输入、日志、生产源码、位流和时序完整验收。
- `sim/tb_capturefix_*.sv`、`sim/tb_capture_exit_regression.sv`：新按键、实际DDR抓拍、取消、错误、PiP、绑定及满载测试。
- `sim/tb_vision8_ddr.sv`：仅将新增snap_abort输入绑定为0，以保留原正常路径回归。

摄像头初始化、PLL、DDR/FIFO IP、算法滤波/NMS、RISC-V固件、管脚配置XML均未修改；原有时序约束保持原文前缀。
