# 第一阶段交付说明（2026-09-24）

> 2026-09-25 后续增强请看本目录 `README_赛题增强.md`，包含 K2 DDR 冻结、14 模式、高斯与形状实验。以下是第一阶段历史证据，不是新版资源和下载状态。

> 后续更新：已增加核心板 K1 模式循环，操作与引脚复用限制见 [README_按键切换.md](README_按键切换.md)。以下“不动板级/未下载”描述为第一阶段交付时的历史记录；按键版本的验证与下载日志在 reports/key_mode_20260924/。

本次范围：不动板级，完成基线保护、两级肤色掩膜观察、参数集中、灰度/Sobel 对照以及离线样本评估工具。

**没有下载到板卡，没有写 Flash，没有提交或上传 Git。新版本的上板效果尚未验证。**

## 完成状态

| 任务 | 本次结果 |
|---|---|
| T00 基线 | 完成：33 项旧 manifest 一致；备份原源码、bit/hex 和报告；原七项仿真重新通过 |
| T01 第一小步 | 完成：模式 6/7、编译期参数集中；原默认检测行为保留 |
| T02 实拍标定 | 工具与模板完成，真实样本/标注缺失，误检漏检统计仍待完成 |
| T06 基础对照 | RTL、仿真和 Efinity 实现完成；模式 5 灰度/Sobel 同屏 |
| 后续阶段 | 未增加 tracker、候选排序、按键、形态学替换、高斯或完整滞后，也未换人脸算法 |

当前目录不是 Git 工作树；本次以 SHA256 和文件备份追溯版本。没有修改 GitHub 仓库中的另一份工程，也没有覆盖两个原始单分支工程。

## 新版怎么切换画面

仍使用原 UART RX，115200、8N1；发送 **ASCII 字符**，例如字符 `5`（0x35），不是原始数值 0x05。本阶段没有新增 TX 状态回读。

| 字符 | 显示 |
|---|---|
| 0 | 原始彩色 |
| 1 | 纯二值 Canny |
| 2 | 彩色原图＋边缘＋候选框 |
| 3 | 黑底白边＋红框，仍是默认 |
| 4 | 框内/框外不同颜色的 Canny 边缘 |
| 5 | 左半原始灰度、右半二值 Sobel，中央青色分界线 |
| 6 | 原始 YCbCr 肤色掩膜：白=通过颜色阈值 |
| 7 | 多数滤波＋腐蚀后的肤色掩膜 |
| m | 现在在 0..7 循环，7 后回 0 |
| + / - | 低阈值±8，高阈值±16；模式5的Sobel复用低阈值 |
| r | 恢复模式3、阈值40/80 |

注意：

- 尚未烧录，因此现在板上不会因为本地文件改好就自动出现新模式。
- 模式5是同一幅图左右不同处理的区域对照，**不是两份完整图各缩小一半**。右侧复用中值预滤波后的 Sobel，不重复例化算法。
- 模式6/7默认不画红框，方便观察缺口；可用编译期 `VISION_DEBUG_BOXES=1` 开启框。
- 模式6保留所有有效原始像素；模式7四周两像素填零；Canny四周四像素填零。HDMI DE始终保持完整1280×720。
- 改Canny阈值不改变人脸肤色阈值。扩展串口写人脸参数留在第二阶段。
- UART电平仍按原约束为1.8V，未改接口或管脚。

## 现在到哪里改参数

统一入口：[vision_config.vh](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/src/parallel/vision_config.vh)。

| 定义 | 默认 | 本次是否改变检测值 |
|---|---:|---|
| VISION_DEFAULT_MODE | 3 | 否 |
| VISION_CANNY_LOW / HIGH | 40 / 80 | 否 |
| VISION_SKIN_CB_MIN / MAX | 77 / 127 | 否 |
| VISION_SKIN_CR_MIN / MAX | 133 / 173 | 否 |
| VISION_SKIN_Y_MIN / MAX | 40 / 235 | 否 |
| VISION_FACE_CELL_SHIFT / MIN | 3 / 24 | 否，8×8网格 |
| VISION_FACE_MIN_W / H | 40 / 48 | 否 |
| VISION_FACE_MAX_W / H | 640 / 640 | 否 |
| VISION_FACE_MIN_AREA | 1800 | 否 |
| VISION_FACE_MIN_FILL_PERCENT | 25 | 否 |
| VISION_FACE_MIN_RATIO_X10 / MAX_RATIO_X10 | 6 / 16 | 否 |
| VISION_FACE_MAX_FACES | 8 | 否 |
| VISION_COMPARE_CANNY | 0 | 新增：0=Sobel、1=Canny作为模式5右半 |
| VISION_DEBUG_BOXES | 0 | 新增：模式6/7是否叠加框 |

这些是**编译期配置**，修改后须重新仿真/编译，不能只改文件期待现有bit或板卡立刻变化。

主工程由 parallel_video 的具名参数将肤色/几何配置传入实际模块；不要再改未参与调用的旧bbox_tracker等文件，也不要只改face_grid_regions底层默认而忽略上层覆盖。

保留原有UART步进时，建议保持低阈值为8的倍数、8..1000，高阈值为其两倍。当前默认40/80未变。任意独立阈值设置需要后续阶段的显式校验/饱和逻辑，当前没有扩展此协议。

第一阶段先不调这些检测值。以后应先观察模式6和7、准备标注样本，再分别试比例16→12、填充25→40等单因素变化；4×4网格不属于小改。

## 数据/控制延迟

| 路径 | 自 parallel_video 输入起，融合前的寄存器等效延迟 |
|---|---:|
| 原始RGB、完整DE/HS/VS/x/y、Canny | 6618 |
| 灰度与原始肤色 | 原算子1＋新增补偿6617＝6618 |
| Sobel二值与清理后肤色 | 原流水3309＋新增补偿3309＝6618 |
| 融合输出 | 再寄存1拍，总计6619 |

所有补偿包含消隐时钟。新调试数据使用9bit与2bit窄RAM打包，没有增加Canny窗口。阈值仍在输入帧边界生效，模式仍在显示帧边界生效；没有改检测框的整帧发布延迟。

## 验证结果

- 修改前七项测试全部重新通过，见 [baseline/rerun_logs](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/baseline/rerun_logs)。
- 修改后八项顶层全部通过，正式日志见 [sim_run03](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/sim_run03)。
- 新 `tb_stage1_display` 使用独立整数参考，核对8帧/65536像素：RGB565量化、灰度、肤色、形态学、Sobel、边界、帧内请求延后生效、参数透传、复位。
- `tb_720p` 保留原Canny/CCL检查，新增模式5/6/7全幅RGB/DE/HS/VS比较：2764800显示像素；Canny有效像素2716992，均匀图无伪边缘，最坏CCL仍443411拍。
- 离线参考12项单元测试通过，见 [reference_tests.log](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/reference_tests.log)。它们是合成正确性测试，**不是实拍人脸准确率**。
- `sim_run02`保留了一次新增TB声明顺序不兼容的失败日志；已修正测试声明顺序，未通过降低断言标准绕过。最终以sim_run03为准。
- Efinity 2025.1.110.5.9、Ti60F225/C4，全流程map/interface/pnr/bitstream/export通过，见 [compile_01.log](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/compile_01.log)。
- 工具日志中的pgm为**生成配置文件阶段**，不是向板卡下载。本次没有运行JTAG/Flash命令。

| 资源/时序 | 修改前 | 本次 |
|---|---:|---:|
| XLR | 13158/60800，21.64% | 13394/60800，22.03% |
| 存储块 | 151/256，58.98% | 161/256，62.89% |
| DSP | 4/160 | 4/160 |
| 最差setup | +0.317ns | +0.302ns |
| 最差hold | +0.026ns | +0.026ns |
| 像素域setup/hold | +3.326/+0.026ns | +3.654/+0.029ns |

572个受保护文件哈希不变，包含IP、摄像头、DDR、HDMI、原视觉算子、LCD时序、peri.xml和SDC。example_top、face_morph、face_grid_regions、肤色转换算子也未改算法。

原outflow错误/警告日志会追加历史内容，仍可看到9月22日旧失败记录；不要把这些当成9月24日的新失败。新编译完整日志与带日期的时序/资源报告为本次依据。既有UART截断、CCL cell_sum异步读映射逻辑等告警仍存在，没有通过放宽约束消除告警。

## 文件位置、回退与后续

- 打开工程：[Ti60_Demo.xml](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/Ti60_Demo.xml)。
- 新bit：[outflow/Ti60_Demo.bit](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/outflow/Ti60_Demo.bit)，未下载。
- 旧源文件：[baseline/files](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/baseline/files)。
- 旧bit/hex与报告：[baseline/artifacts](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/baseline/artifacts)。
- 新结果、哈希、变更/边界检查：[final](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/reports/stage1_20260924/final)。
- 实拍样本格式与分析命令：[采样与标定说明](D:/yilingsi_fpga/Efinity_Project/2026.9.22/9.22.2_ding_Ti60F225_Canny_Face_Parallel/docs/stage1_dataset/采样与标定说明.md)。

原reports目录的build_manifest/final_results/board_acceptance仍是9月22日历史记录，未覆盖；本次结果在stage1_20260924子目录。

回退时先确认没有后续用户改动，再按final/changed_files.json逐项从baseline/files恢复对应旧文件，并停用新增头文件入口；旧bit也已独立保存。不要删除整个工程、不要用递归清空或整目录覆盖当回退。回退后仍须验证，烧录需用户重新明确要求。

本次没有实拍帧/标注，因此T02尚未达到最终验收；没有新版本实物上板验证，不能宣称人脸准确率改善或赛题所有基础项实物验收已完成。
