# 六键 CaptureFix：四帧保存、退出清零与 Canny 双阈值

本说明已按 2026-10-21 核查报告修订。**本轮验收入口为 `reports/capture_review/selected_evidence.json` 和 `delivery.json`**；交付文件生成前，不能把在跑测试当作完成。`reports/capture_fix`、根目录 `reports/build_verified.json` 及 `reports/vision8` 是历史证据，不用于判断本轮通过。修订前说明保存在 `reports/capture_review/README_before_audit.md`。

## 打开及下载文件

Efinity 打开本目录 `Ti60_Demo.xml`：

`D:\yilingsi_fpga\Efinity_Project\2026.10.20\10_20_ding_Ti60_Gesture5_6Key_CaptureFix\Ti60_Demo.xml`

器件 Ti60F225 / C4，工程 Efinity 2025.1.110.5.9，1280×720，像素时钟约 74.4 MHz。没有改变分辨率、PLL、摄像头初始化、DDR IP、管脚映射或 Canny 算法。

只使用本轮重新构建并收集到 `outflow/Ti60_Demo.bit` 的位流，哈希以 `reports/capture_review/selected_build.json` 为准；对应 Flash 格式为 `Ti60_Demo.hex`。**未执行 JTAG 下载、Flash 写入或上板实测。** 根目录 XML 记录的旧 pass 状态也不能替代本轮构建日志。

## 模式与六键

1 原图 → 2 Canny → 3 红边 → 4 赛博 → 5 彩边对照 → **6 四帧** → 7 五类手势 → 8 人脸候选。内部编号保持原语义，显示编号由 `vision8_modes.vh` 转换；该头文件实际被 `vision8_controls`、`menu8_renderer` 两个模块引用。

| 按钮 | 短按 | 长按约2秒 |
|---|---|---|
| IO28 | 下一模式；四帧中清空并进入手势 | 无动作 |
| IO29 | 普通模式冻结/恢复；四帧保存一张 | 四帧清空、抓拍算法回RAW、保持四帧模式；其他模式无动作 |
| IO34 | 边缘模式减阈值；手势确认；四帧换抓拍算法 | 边缘步长1→4→8→1；手势进入/重新录入 |
| IO35 | 边缘模式加阈值 | 恢复当前算法默认阈值 |
| 板载K1 | 模式2、3、4开关画中画 | 无动作 |
| 板载K2 | 模式2、5轮换 联合→仅HIGH→仅LOW→联合 | 无动作 |

六键低有效，双级同步、约20ms消抖，上电按住须先释放。长按释放不补短按，切模式、切调节对象及手势学习状态变化取消旧按键动作。四帧忙时忽略IO34换算法；手势录入时IO29不冻结。

K1=`key_mode_n`，N2/GPIOL_P_02_CSI；K2=`key_freeze_n`，M2/GPIOL_N_02_CSO。它们是原有配置复用管脚，本轮没有改映射。上电配置期间不要按住K1/K2，是否影响启动仍需对照板卡原理图及实物确认；RTL的启动按住保护只处理配置成功后的逻辑操作。

## Canny调节

默认LOW=40、HIGH=80；模式2、5共享数值，进入时选择联合。基础步长d为1/4/8。

- 联合：LOW±d、HIGH±2d。40/80加一次成为41/82。
- 单独：选中值±d，另一值不变；始终保证1≤LOW<HIGH≤2040。
- 联合接近边界时成对限幅，不只移动一个值；独立调整后不强制2:1数值比例。
- IO35长按恢复40/80和联合选择，步长保留。
- 红边默认40，范围1～2040；赛博默认24，范围1～255，各自独立。
- `vision8_controls.low/high` 是待提交参数，`low_active/high_active` 在输入帧边界原子更新；`version` 仅在实际参数改变的提交时递增。冻结时仍可调参数。
- UART数字0～7按显示顺序选模式，`+/-` 调当前边缘算法；四帧中作用于所选算法；原图等非边缘算法忽略。`r`恢复全部默认参数与原复位行为。维护命令`p/g/c/t`进入对应维护支路时解除冻结、重置选择对象。

Canny仍为高斯→Sobel L1→方向NMS→双阈值→一次局部8邻域连接，后者不等于任意长度连通追踪。本轮没有移植自适应阈值或跨帧叠加。

## 四帧操作与这轮修正

进入第6模式，IO34选择RAW/Canny/红边/赛博；IO29短按保存。保存等待冻结应答和完整有效帧，保存时绑定参数、源帧号和版本；四次填满，第五次替换最早一格。

四帧中IO28短按或UART切到其他模式：清空四格有效标志、元数据、待发布项与保存序号，算法回RAW，释放抓拍专用冻结。IO28随后进入手势。其他算法阈值保留。清空是目录失效，不擦写整片DDR；已呈现的AXI写事务必须安全排空，后台忙结束前不能再保存。DDR永久无应答时不能强行伪造完成。

此前已修正的核心包括独立取消握手`snap_abort`、完整主读帧检查`read_frame_good/read_frame_bad`、逐像素坐标/数量/源帧号校验、抓拍失败不发布，以及四帧模式持续主读。

**按本次核查新增的修正：**

1. `vision8_frames`：修正384位标签的填充长度，恢复BUSY、CAPTURE FAILED、EMPTY、FACE的首字符；人脸计数/饱和标记位置同步修正。
2. `done_wait`：完成事件同步后额外等待两个像素周期，再采样已同步的`snap_ok`，降低独立CDC先到事件、后到状态的风险；完成状态须保持至下一次完成。
3. `example_top.capture_freeze_req`：将用户冻结与抓拍锁的OR先在像素域寄存，再送入DDR现有同步链，新增一拍请求延迟，仍等待真实冻结应答。
4. 状态6在超时、退出或清空同拍不允许旋转临时槽/保存指针或发布成功，避免取消边界污染下一次保存。
5. 顶层信号声明移至首次使用前，兼容实际顶层的XSim编译；顶层和frames恢复LF，SDC以字节核对原约束前缀，未放宽视频约束。

HDMI的BUSY/失败信息只显示在空格中；四格全满时没有全屏忙/失败浮层。四帧页没有所选算法当前阈值的实时数字，UART调参后要通过新保存标签确认；LVDS不显示版本号。这些界面限制保留，没有把它们描述成已实现功能。

## 验证范围与复现

所有新日志采用新英文构建目录和时间戳目录。当前验收明确选择每个测试的报告路径和测试名，不自动寻找“最新结果”。一组批量编译可能包含多份独立测试；重跑某一夹具时，其他已通过根模块只核对其实际测试源码及全部生产/配置/参考/运行器输入，不把未展开的另一个测试当作其输入。开发中的FAIL/ERROR保留，不选为该测试的交付结果。

在本工程目录运行：

```powershell
$py='C:\Users\Lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -X utf8 -B tools/capture_review_test.py tb_review_controls tb_review_hdmi_text tb_review_done_cdc tb_review_top
& $py -X utf8 -B tools/capture_review_test.py tb_capturefix_chain tb_capturefix_abort tb_capturefix_faults tb_capturefix_binding tb_capturefix_cancel_boundary
& $py -X utf8 -B tools/capture_review_test.py tb_review_video_defaults tb_inline_video_dynamic
& $py -X utf8 -B tools/capture_review_test.py tb_capturefix_720p_pressure tb_capturefix_full_load
& $py -X utf8 -B tools/capture_review_test.py tb_fourkey_font tb_capturefix_menu tb_inline_cpu8 tb_inline_epd_cpu
& $py -X utf8 -B tools/verify_capture_review.py --evidence reports/capture_review/selected_evidence.json
```

旧`run_capture_fix.py`及`test_capturefix_*.py`仍会写历史目录，不要用它们重跑本轮；采用上面的新运行器。旧`verify_capturefix_delivery.py`入口已改为只读兼容入口，其原实现另存历史。

最后一条默认只读，不改写交付报告。完整保留回归的全部测试名列于`selected_evidence.json`；逐项覆盖映射见验收器`COVERAGE`及`delivery.json`。

- `tb_review_top`编译真实顶层和逻辑模块，保留HUD_ENABLE=1、SHARED_FONT=1、SOURCE_TAGGED=1、真实K1/K2端口、源帧号33位CDC、冻结独立双级同步、640位菜单通道。仅DDR PHY为端口头模型，物理DDR边界采用随机应答存储模型，相机在裁剪后注入、健康字由模型驱动；128×96参数仅限仿真。它验证连线和逻辑，不能证明物理传感器、PLL、DDR电气或全尺寸顶层性能。SDC由PNR检查，XSim不执行SDC。
- `tb_review_controls`补齐启动按住、K1三模式、K2模式5、UART减号、IO29长按清空/RAW、busy忽略IO34、步长回绕、阈值上下限和版本只随实际提交改变。
- `tb_review_hdmi_text`逐字符和逐像素检查真实HDMI文字路径；`tb_review_done_cdc`故意令状态晚于完成事件并检查超时/完成同拍。
- `tb_capturefix_chain`在128×96实际四算法保存/回读；第五张替换采用独立的预期格号及未改动其他格检查，不只依赖DUT指针。
- `tb_review_video_defaults`以指定4Key前版的真实`parallel_video`和overlay为参考，仅重命名模块；叶模块原版/当前哈希比较。七场景720p逐像素对比。旧inline_reference参考不再作为本轮默认对比依据。
- `tb_inline_video_dynamic`包括LOW=27/HIGH=80的非2:1参数，LOW/HIGH均检查帧内恒定。
- 720p压力使用RAW延迟流水。空目录到四次保存检查稳态；满四格再替换测试先预置仿真DDR并force有效目录，这个夹具不能代替四次真实保存。DDR模型固定种子0x9126acd8，不能完整建模刷新、换向、校准和实际带宽。
- CPU8的4,915,200像素检查是LVDS打包/帧结构一致性，**没有独立图像golden**。电子纸另验证实际固件/SPI/BUSY。
- 像素看门狗生产值4×1650×750拍；DDR生产值134,217,727拍。压力测试DDR缩为8,000,000拍，错误测试更短；未直接仿真生产1.4秒完整等待时长。

历史三组替代关系：旧`tb_vision8_controls/tb_inline_controls`由六键测试替代；旧`tb_vision8_frames`由真实链路/PiP/取消与错误测试替代；`tb_vision6`由实际4Key七场景默认对比替代。原日志保留，不能把旧FAIL/RUNNING或旧bit当作当前证据。

Efinity重新构建需新英文目录：

```powershell
& $py -X utf8 -B tools/capture_review_build.py prepare D:/Github_Project/fpga_build/review_MY_NEW_RUN
& $py -X utf8 -B tools/capture_review_build.py build D:/Github_Project/fpga_build/review_MY_NEW_RUN
& $py -X utf8 -B tools/capture_review_build.py collect D:/Github_Project/fpga_build/review_MY_NEW_RUN
```

收集器拒绝覆盖已有outflow/本轮build证据；重建前应完整另存当前证据。构建验收保留XLR≤60000、RAM≤230及setup/hold非负；不能仅凭全局最小slack声称像素逻辑余量改善。逐时钟域结果与警告差异另见`reports/capture_review/build_analysis.json`。

## 保护与回退

本轮写入前完整备份8764文件，逐文件SHA-256核对，位置：

`D:\yilingsi_fpga\Efinity_Project\2026.10.20\_backups\CaptureFix6Key_before_audit_20261021T041525Z`

清单`reports/capture_review/backup.json`。原4Key目录保持不动，验收核对原文件集合与哈希。回退本轮修正可直接打开该完整备份的`Ti60_Demo.xml`；其包含本轮修正前源码及旧位流。需要回到更早4Key功能时，打开原`10_20_ding_Ti60_Gesture5_4Key_InlineThreshold/Ti60_Demo.xml`。不要只换源码而继续下载不对应的位流。

## 上板观察

1. 第6模式依次保存四算法，检查真实图片、LOW/HIGH/T、第五张替换位置。
2. 保存等待或过程中按IO28，检查退出到手势、重入四帧为空、后续模式更新正常。
3. Canny默认40/80，K2循环选择、联合加一次41/82；独立LOW/HIGH与K1画中画按表工作。

上述仍待实物确认；仿真和Efinity通过不能证明板上灰屏已消失。


## 本轮已完成的新构建（2026-10-21）

英文构建目录：`D:\Github_Project\fpga_build\capture_review_20261021_final1`。map/interface/pnr/pgm均PASS；506个生产输入与本工程匹配，47个生成文件已收集并核对哈希。

| 项目 | 整改前六键版本 | 本轮修正后新构建 |
|---|---:|---:|
| XLR | 55,047 | 53,710 |
| RAM块 | 184 | 184 |
| DSP块 | 38 | 38 |
| 全局最小setup | 0.302 ns | 0.326 ns |
| 全局最小hold | 0.026 ns | 0.026 ns |

这只是两次实际构建的资源与时序结果，不代表算法吞吐提升。整改前列来自保留的、此前已完成的构建，本轮没有重新编译它。

| 时钟域 | 整改前setup | 当前setup | 整改前hold | 当前hold |
|---|---:|---:|---:|---:|
| clk_sys | 2.356 | 2.205 | 0.028 | 0.027 |
| clk_pixel | 2.710 | 2.473 | 0.026 | 0.026 |
| clk_lvds_1x | 5.761 | 6.472 | 0.034 | 0.030 |
| cmos_pclk | 1.468 | 1.408 | 0.029 | 0.098 |

单位ns，同域存在多个边沿关系时取最小值。全局setup增加，但像素域、系统域等余量有所减小，不能称所有路径改善。详细跨域与边沿关系保存在`build_analysis.json`。

```text
outflow/Ti60_Demo.bit SHA-256
44ae0517fc83ffe771707199628a7c0f33fe25eb25baa1002b00b13b665181b3
outflow/Ti60_Demo.hex SHA-256
b564a22df1b2a6d5b7474e46783dd20a39055d7c853f59e366e0916bded32ae7
```

当前综合警告日志仍保留，标签392→384截断已移除。相对4Key原版，控制器选择宽度、菜单坐标等有新增缩位记录，不能统称继承；相对整改前六键版本的具体新增/移除组见`build_analysis.json`。无通过删约束、降频或忽略时序失败换取通过。


## 建议的实物操作顺序（尚未执行）

1. 上电配置期间松开K1/K2。在Efinity Programmer中选择本目录新`outflow/Ti60_Demo.bit`做SRAM临时下载；核对上方哈希，先不写Flash。
2. 从上电原图模式短按IO28五次，进入“06 四帧”。普通短按可按约0.1～0.5秒后松开，避免误成长按。
3. 先保存RAW：IO29短按后松开，等待保存结束。出现失败提示时，不要把空格当作成功图片；记录提示和复现步骤。
4. 空闲时IO34换到Canny，再IO29保存；依次换红边、赛博保存。第五次保存应替换第一格，其他三格不变。保存时的LOW/HIGH/T应保持在各格标签里。
5. 再启动一次保存，在等待或传输中短按IO28。应进入“07 手势”，返回四帧后为空格；后台排空未结束时暂不能再保存。此项用于实物确认退出后其他模式不受损。
6. 回到Canny，默认40/80、联合步长1时，IO35短按应得到41/82。IO35长按恢复40/80；K2一次选仅HIGH，IO35一次应为40/81；K2再一次选仅LOW，IO34一次应为39/81；K2再一次选联合，IO35一次应为40/83。最后长按IO35恢复40/80。
7. 在模式2、3、4分别试K1画中画；IO28长按应无动作。IO29长按在四帧中应清空并回RAW，仍停留四帧。

这些是交付后的上板验收步骤，不表示已在实体板卡执行。SRAM临时下载掉电会丢失，Flash保存本轮未执行。


## 本轮最终验证结果

`reports/capture_review/delivery.json`实际验收为 **PASS，44项选定RTL测试全部通过**。9项负向验收测试也全部通过：缺少顶层/保留测试、输入哈希变化、失败测试、日志变化、缺少结束标记、SDC换行/前缀修改、构建数字修改均被拒绝。只读行为另有`readonly_check.json`记录。

| 验证层级 | 实际结果 |
|---|---|
| 实际顶层 | PASS；128×96逻辑集成，物理边界模型范围如前文 |
| 六键、阈值、抓拍/取消/错误与保留回归 | PASS；完整名单44项见选择表，逐项日志绑定SHA-256 |
| 指定4Key默认算法RTL对比 | 6,451,200像素一致；本轮以实际前版源码为参考 |
| 动态阈值 | 147,456像素；包括27/80、LOW/HIGH帧内恒定 |
| 720p空目录四次保存 | PASS；稳态未新增AUX欠载 |
| 720p预置满四格替换 | PASS；监控8个完整帧，有效区未见主读空读/FIFO复位/AUX失效 |
| 菜单与字库 | 5,301,248UI像素检查，646,144字库像素精确比对 |
| 实际CPU菜单 | 4,915,200像素的LVDS打包/帧结构检查；没有独立图像golden |
| 电子纸实际固件 | 30,033SPI字节、两图层、复位和BUSY检查PASS |
| 综合、接口、布局布线、时序、位流生成 | PASS；53710 XLR / 184 RAM / 38 DSP；全局setup/hold=0.326/0.026ns |
| Python/OpenCV算法参考 | 本轮未新增；采用实际前版RTL对比 |
| 上板、JTAG、Flash | **未执行** |

验收实际核对了原4Key工程7683文件、474个与原版一致的生产文件，以及500个IP/vendor/image依赖及配置文件。完整备份8764文件另已重新核对。模式、K1/K2、双阈值控制按本文操作表；最终物理灰屏结论必须等待实物观察。

本轮有一份批量视频报告保留ERROR：原因是编译后修正了未用于其他根模块的旧菜单夹具。菜单已单独重跑通过。交付选择表与`delivery.json.batch_selection`明确列出选中的通过根、排除的旧失败根及原因，未把原始批次状态改成PASS。

负向验收复现：

```powershell
& $py -X utf8 -B tools/test_capture_review_verifier.py --evidence reports/capture_review/selected_evidence.json
```

若确需生成另一份验收报告，必须显式指定新文件名；原文件存在时拒绝覆盖：

```powershell
& $py -X utf8 -B tools/verify_capture_review.py --evidence reports/capture_review/selected_evidence.json --publish --output reports/capture_review/delivery_MY_NEW_CHECK.json
```
