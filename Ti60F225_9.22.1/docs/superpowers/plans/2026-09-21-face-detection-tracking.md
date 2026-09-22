# 人脸检测 + 矩形框跟随 实施计划（Ti60F225 / OV5640 / 纯 RTL）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Canny 边缘检测 demo 的显示通路上，并联一条「YCbCr 肤色分割 → 形态学清理 → 连通域 → bbox 时序滤波」的纯 RTL 人脸检测支路，输出稳定 bbox，并在 HDMI 输出上用矩形框跟随人脸（可选：框内人脸边缘高亮）。

**Architecture:** 分三阶段落地（v2：采用 Haar-like 路线，非 CNN）。阶段1 复用 `src/face/` 下 7 个从未接线的模块（肤色二值化、7x7 多数滤波、3x3 腐蚀/开运算、流式连通域 CCL、bbox 过滤、矩形框叠加）+ 新增 3 个模块（精确 YCbCr 肤色分割、bbox 时序跟踪、帧同步脉冲），先拿到「框能跟随」；阶段2 在候选框上开 64x64 ROI，用局部积分图 + 单级 Haar-like 强分类器做真假判别；阶段3 升级为 3~5 级小级联，把误检清干净。整条支路挂在 `clk_pixel` 域，与 Canny 链路共享同一路 `lcd_data`/`lcd_vs`/`lcd_de`，不新增 DDR 带宽、不触碰 DDR 控制器域、**不做整帧积分图**。

**Tech Stack:** Verilog-2001 / Efinix Efinity 2025.1（efx_map→efx_pnr→efx_pt→efx_bit）/ XSim 仿真 / 器件 Ti60F225（Titanium C4）

**Spec:** 本文件第 1~4 节（需求、约束、接口、验收标准）即 spec；执行前先读第 5 节「接口事实清单」。

---

## 1. 需求与成功标准

| 编号 | 需求 | 成功标准 |
|---|---|---|
| R1 | 检出画面中的人脸区域 | 单人正脸、0.3~1.5 m、室内常见光照下，帧级检出率 ≥ 90% |
| R2 | 用矩形框标出人脸 | 矩形框紧贴人脸（宽高比 0.65~1.6，面积占比 1%~40%），框线宽 2 px |
| R3 | 跟随人脸移动 | 人缓慢移动时框跟随；框中心抖动 ≤ 2 px（静止 3 s 内峰峰值） |
| R4 | 短时丢失不闪断 | 丢失后保持最后位置 ≤ 15 帧（0.25 s），期间重新检出立即续上 |
| R5 | 不破坏现有 Canny demo | Canny 边缘图仍正常输出；帧率仍为 720p60；`clk_pixel` setup slack > 0 |
| R6 | 资源可控 | 阶段1 增量 ≤ +25 个 RAM10、+4000 LUT4、+2500 FF；阶段2/3 完成后 RAM10 总量 ≤ 140/256 块、XLR 总量 ≤ 25,000/60,800（当前 62 块、7,466 XLR） |
| R7 | 用结构特征（Haar-like）压掉误检 | 阶段2/3 完成后，木桌/手臂/墙面等类肤色干扰造成的误检下降 ≥80%，正脸检出率不低于阶段1 |

**明确不做（YAGNI）：** 多人脸同时跟踪（第一版只跟 1 个）、人眼/五官定位、身份识别（不是 recognition）、神经网络推理、上位机参与。

## 2. 全局约束（Global Constraints）

- 器件/工具：Ti60F225；`D:/Efinity`；构建脚本 `work_syn/*.sh`（`efx_map --project Ti60_Demo --root example_top`）。
- 时钟：`clk_pixel` = 74.25 MHz（SDC 约束 74.399 MHz）、`clk_sys` = 96 MHz、`cmos_pclk` = 100 MHz。
- **新增逻辑只允许挂在 `clk_pixel` 域**；**禁止改动 DDR3 控制器域**（该域最紧 setup slack 仅 +0.317 ns、hold +0.023 ns，任何改动都可能打破收敛）。
- `clk_pixel` 域余量：setup slack +4.523 ns（约束 13.441 ns）→ 单级组合逻辑 ≤ 约 18 ns。
- 分辨率固定 1280x720@60；数据面为 RGB565（`lcd_data[15:11]=R, [10:5]=G, [4:0]=B`）。
- 位宽约定：x 用 `[10:0]`（0..1279），y 用 `[9:0]`（0..719）。
- RTL 风格：`timescale 1ns/1ps`；时序逻辑 `always @(posedge clk or negedge rst_n)`；模块间统一「点进点出 + valid/x/y 同步透传 1 拍」；窗口类模块统一「窗进点出」。
- 每个新增/修改的模块必须有 XSim testbench：≥ 10 组定向用例 + 100000 组随机用例、0 错误；TB 风格参照 `tb/vision/*_tb.v`（参考模型必须与 RTL 用不同实现路径）。
- 修改 `Ti60_Demo.xml` 前**必须确认 Efinity GUI 已关闭**（GUI 会用内部状态覆盖该文件）。
- 编译报错排查：`outflow/Ti60_Demo.err.log` 是**累积追加**的，必须按日期过滤，勿把 9/16 旧错误当本次失败。
- 每阶段收尾必做：更新 `.workbuddy/memory/YYYY-MM-DD.md`；重跑综合确认资源/时序；改动前备份 `example_top.v.bak-<feature>`。

## 3. 开放决策（默认值已选定，开工前请确认）

| 决策点 | 默认（本计划采用） | 备选 |
|---|---|---|
| 显示形态 | **A：底色 = Canny 边缘图（暗灰），人脸 bbox 内边缘提亮，外框白色 2 px** | B：原始彩色图 + 白框；C：只加白框，边缘图不动 |
| 检测原理 | 阶段1：肤色 + 形态学 + 连通域（纯阈值、无需训练）；阶段2/3：肤色出候选 + 候选 ROI 上做局部积分图 + Haar-like 级联判别 | 纯 CNN（Ti60 无 NPU、Efinity 无 CNN IP，已放弃）；**全图 Haar 扫描（720p 积分图需 3.2MB，片内只有 320KB，否决）** |
| 目标数 | 单目标（面积最大的合法 blob） | 多目标（`bbox_overlay` 原生支持 64 blob，后续可开） |
| bbox 更新时机 | 每帧算完、**下一帧**生效（1 帧延迟 ≈16.7 ms，肉眼无感） | 同帧生效（需要整帧缓存，否决） |

## 4. 验收标准（端到端）

1. **仿真**：新模块 TB 全 PASS；端到端 TB 用静态图（离线生成 1280x720 RGB565 激励）验证 bbox 与 Python 参考模型误差 ≤ ±1 px。
2. **上板**：720p60 输出不断流；人脸框稳定跟随；`outflow/Ti60_Demo.timing.rpt` 中 `clk_pixel` setup slack > 0；无新增 hold 违例。
3. **资源**：满足 R6。
4. **回归**：Canny 边缘图与改动前逐帧一致（用同一段录像对比，允许因框叠加产生的差异）。

## 5. 接口事实清单（已核实，实现时直接引用）

| 模块 | 文件 | 关键端口 | 备注 |
|---|---|---|---|
| `face_reader_720p` | `src/face/face_reader_720p.v` | `image_in_R/G/B[7:0]`, `pixel_x[10:0]`, `pixel_y[10:0]`, `pixel_valid` → `binary_output`, `output_valid` | 现版只用 `U=R-G`（10<U<90）判肤色，过粗，Task 2 用新模块替换，保持同接口 |
| `low_pass_realtime` | `src/face/low_pass_realtime.v` | `pixel_valid`, `binary_input`, `pixel_x/y` → `filtered_output`, `output_valid` | 7x7 多数滤波，`THRESH=15`；内部例化 6 个 `line_delay_bit` |
| `line_delay_bit` | 同上文件 125 行起 | `we`, `addr[10:0]`, `din` → `dout`（同步读延 1 拍） | **被多个 face 模块依赖，该文件必须始终在构建里** |
| `morph_erode3x3_stream` | `src/face/morph_erode3x3_stream.v` | `vs_in`, `de_in`, `bin_in`, `break_en_i` → `erode_out`, `erode_valid` | `break_en_i=0` 走 3x3 腐蚀；`=1` 走垂直 N 开运算（`V_OPEN_LEN`） |
| `streaming_connected_components` | `src/face/streaming_connected_components.v` | `in_valid/in_bin/in_x/in_y`, `frame_start`, `frame_end` → `blob_count`, 随机读表 `raddr`→`r_min_x/r_max_x/r_min_y/r_max_y/r_area_pix/r_valid`, `break_en_o` | 内部例化 `true_ccl`；帧尾自动冲刷 `FLUSH_ROWS` 行；参数 `MIN_W=40, MIN_H=40, MIN_AREA=2500, MAX_BLOBS=64` |
| `true_ccl` | `src/face/true_ccl.v` | CCAL 流式 CCL 核，输出 `XMin/XMax/YMin/YMax/RealN` | 已有 Verilog-2001 前向声明修复；被 `streaming_connected_components` 例化，不要单独再例化一次 |
| `bbox_filter_720p` | `src/face/bbox_filter_720p.v` | `vs_in`, `in_blob_count`, `in_addr_out`+`in_bbox_*`（随机读） → `blob_count`+`bbox_min_x/max_x/min_y/max_y/bbox_valid`（随机读口） | 逐帧挑合法 blob |
| `bbox_overlay` | `src/face/bbox_overlay.v` | `rgb_in[23:0]`, `de_in/vs_in/hs_in`, `x_in[10:0]`, `y_in[9:0]`, bbox 表 → `rgb_out/de_out/vs_out/hs_out`, `pending_swap` | 已内建 bbox 表双缓冲，VS 切换 |
| Canny 链现状 | `example_top.v:1091-1344` | 输入 `lcd_data/lcd_request/lcd_xpos/lcd_ypos`，输出 `canny_rgb_out[23:0]` + `canny_de_out/vs_out/hs_out` | `CANNY_LATENCY=16`；`hysteresis_local` 的 `x_o/y_o` 当前**未接**（`.x_o(), .y_o()`），它们与 `edge_o` 同拍，Task 6 直接接出使用 |

## 6. 文件结构（改动地图）

```
新增：
  src/face/rgb565_to_ycbcr_skin.v     肤色分割（替换 face_reader_720p 的判据）
  src/face/bbox_tracker.v             时序滤波/跟随（IoU 门限 + 指数平滑 + 丢失保持）
  src/face/frame_sync_gen.v           由 lcd_vs 生成 frame_start / frame_end 单拍脉冲（可合入 example_top）
  tb/face/rgb565_to_ycbcr_skin_tb.v
  tb/face/bbox_tracker_tb.v
  tb/face/face_chain_e2e_tb.v         端到端静态图回归（对标 Python 参考模型）
  tools/ref_face_bbox.py              离线参考模型（numpy，生成激励 + 期望 bbox）

阶段2/3 新增（Haar-like 判别）：
  src/face/candidate_roi_extract.v    候选框 → 64x64 ROI 采样缓冲（下一帧边流边填，双缓冲）
  src/face/integral_roi.v             局部积分图（65x65，单块 RAM 串行复用）
  src/face/haar_single_stage.v        单级 Haar-like 强分类器（纯加减 + ROM 查表）
  src/face/haar_cascade.v             3~5 级小级联 + 候选打分排序
  tb/face/candidate_roi_extract_tb.v
  tb/face/integral_roi_tb.v
  tb/face/haar_classifier_tb.v
  tools/haar_xml_to_rom.py            OpenCV cascade XML → 定点化 ROM + 黄金向量
  tools/ref_haar_eval.py              定点参考模型（与 RTL 逐窗口对拍）
修改：
  example_top.v                       例化整条 face 支路 + 叠加 + 调试开关
  Ti60_Demo.xml                       登记新增 3 个 .v（改前确认 GUI 已关闭）
  docs/superpowers/plans/2026-09-21-face-detection-tracking.md  本文件（勾选进度）
不动：
  src/axi/*（DDR 域）、src/vision/*（Canny 链）、src/face/ 下 7 个既有模块（除必要 bugfix）
```

---

# 实施任务（按序执行，每个 Task 结束必须可独立验证）

### Task 0: 既有 face 模块接口与延迟审计（只读）

**Files:**
- Read: `src/face/face_reader_720p.v`, `src/face/low_pass_realtime.v`, `src/face/morph_erode3x3_stream.v`, `src/face/true_ccl.v`, `src/face/streaming_connected_components.v`, `src/face/bbox_filter_720p.v`, `src/face/bbox_overlay.v`
- Create: `docs/notes/face_module_audit.md`（接口表 + 延迟表 + 复用结论）
- Modify: `.workbuddy/memory/2026-09-21.md`（追加审计结论）

**Interfaces:**
- Consumes: 无（只读）
- Produces: 一份「模块 → 输入/输出/延迟/复位语义/可否复用」表，供后续 Task 直接引用

- [ ] **Step 1:** 逐文件读端口与 always 块，记录每个模块的信号流、复位方式（同步/异步）、valid 语义
- [ ] **Step 2:** 为 5 个模块各写一个最小 TB（`tb/face/audit_<module>_tb.v`），只喂一行/一帧合成数据，用 DE 上升沿差值测出**每级精确延迟拍数**
- [ ] **Step 3:** 用 `xsim` 跑 Step 2 的 TB，把实测延迟填入审计表
- [ ] **Step 4:** 确认 `line_delay_bit` 是否只定义在 `low_pass_realtime.v` 内（是则任何依赖它的模块都要求该文件参与编译）
- [ ] **Step 5:** 写 `docs/notes/face_module_audit.md`，给出「直接复用 / 需改接口 / 需重写」三档结论
- [ ] **Step 6:** 提交

**Acceptance:** 审计表覆盖 7 个模块；5 个实测延迟已填；明确 `bbox_overlay` 是否可直接吃 Canny 的 24bit 输出。

---

### Task 1: 肤色分割模块 `rgb565_to_ycbcr_skin`（新建 + TDD）

**Files:**
- Create: `src/face/rgb565_to_ycbcr_skin.v`
- Create: `tb/face/rgb565_to_ycbcr_skin_tb.v`
- Modify: `Ti60_Demo.xml`（**确认 Efinity GUI 已关闭**后登记新文件）

**Interfaces:**
- Consumes: `lcd_data[15:0]`（RGB565）、`lcd_request`（当 valid）、`lcd_xpos`、`lcd_ypos`
- Produces: 与 `face_reader_720p` 同构的像素流，供 Task 2 直接使用

```verilog
module rgb565_to_ycbcr_skin #(
    parameter AWIDTH = 11
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                de_i,
    input  wire [AWIDTH-1:0]   x_i,
    input  wire [9:0]          y_i,
    input  wire [15:0]         rgb565_i,
    // 运行时可调阈值（默认 77/127/133/173/40，见 parameter 默认值）
    input  wire [7:0]          cb_min_i, cb_max_i,   // 77, 127
    input  wire [7:0]          cr_min_i, cr_max_i,   // 133, 173
    input  wire [7:0]          y_min_i,  y_max_i,    // 40, 235
    output reg                 skin_o,
    output reg                 de_o,
    output reg  [AWIDTH-1:0]   x_o,
    output reg  [9:0]          y_o
);
```

- [ ] **Step 1: 写失败的 TB**

```verilog
// tb/face/rgb565_to_ycbcr_skin_tb.v —— 关键片段
task check(input [15:0] px, input exp);
  begin
    @(negedge clk); rgb565_i = px; de_i = 1'b1; x_i = x_i + 1;
    @(negedge clk);                       // 等 1 拍流水
    if (skin_o !== exp) begin
      $display("FAIL px=%h exp=%b got=%b", px, exp, skin_o); err = err + 1;
    end
  end
endtask
// 定向用例（期望值用 Python/手算的 Cb/Cr 真值表，不与 RTL 同路径）
initial begin
  check(16'hFBE4, 1'b1);  // 230,180,150 典型肤色
  check(16'hCBC8, 1'b1);  // 200,150,120 偏深肤色
  check(16'hFFFF, 1'b0);  // 白
  check(16'h0000, 1'b0);  // 黑
  check(16'h8410, 1'b0);  // 灰（R=G=B）
  check(16'h07E0, 1'b0);  // 纯绿
  check(16'h001F, 1'b0);  // 纯蓝
  check(16'hF800, 1'b1);  // 纯红：Cr 高但 Cb 低 → 需按真值表确认
  // ... 共 ≥10 组定向，覆盖暗部(Y<40)、过曝(Y>235)、边界值
  // 再跑 100000 组随机，参考模型用 $sin 无关的纯整数公式独立实现
end
```

- [ ] **Step 2: 跑测试确认失败** —— Run: `sim/run_xsim.sh tb/face/rgb565_to_ycbcr_skin_tb.v`；Expected: `FAIL`（模块未实现）
- [ ] **Step 3: 实现最小 RTL**，只允许移位-加法，禁止 `*` `/`：

```verilog
// 通道扩展（与 rgb565_to_gray 一致的 MSB 复制）
wire [7:0] r8 = {r5, r5[4:2]}, g8 = {g6, g6[5:4]}, b8 = {b5, b5[4:2]};
// Y = (77R + 150G + 29B) >> 8   —— 直接复用 rgb565_to_gray 的移位加法写法
// Cb = 128 + (-43R - 85G + 128B) >> 8   （43=32+8+2+1, 85=64+16+4+1）
// Cr = 128 + ( 128R - 107G - 21B) >> 8  （107=64+32+8+2+1, 21=16+4+1）
wire signed [15:0] cb_sum = -((r8<<5)+(r8<<3)+(r8<<1)+r8)
                         - ((g8<<6)+(g8<<4)+(g8<<2)+g8)
                         + (b8<<7);
wire signed [15:0] cr_sum =  (r8<<7)
                         - ((g8<<6)+(g8<<5)+(g8<<3)+(g8<<1)+g8)
                         - ((b8<<4)+(b8<<2)+b8);
wire [7:0] cb = 8'd128 + cb_sum[15:8];   // 算术右移 8 位
wire [7:0] cr = 8'd128 + cr_sum[15:8];
wire y_ok  = (y8 >= y_min_i)  && (y8 <= y_max_i);
wire cb_ok = (cb >= cb_min_i) && (cb <= cb_max_i);
wire cr_ok = (cr >= cr_min_i) && (cr <= cr_max_i);
wire skin_d = y_ok & cb_ok & cr_ok;
```

- [ ] **Step 4: 跑测试确认通过** —— Expected: `PASS: 1000xx cases, 0 errors`
- [ ] **Step 5: 上板单点验证**：把 `skin_o` 直接当显示输出（白=肤色），确认实拍时人脸是白块、背景基本黑。**留证据截图**（EXIF 无要求，存 `_analysis/face_mask_check.png`）
- [ ] **Step 6: 提交**

**Acceptance:** TB 0 错误；实拍肤色块可见且桌面/墙不误判为大面积白块。

---

### Task 2: 形态学清理（复用 `low_pass_realtime` + `morph_erode3x3_stream`）

**Files:**
- Read: `src/face/low_pass_realtime.v`（含 `line_delay_bit`）、`src/face/morph_erode3x3_stream.v`
- Create: `tb/face/face_morph_tb.v`（合成二值图回归）
- Modify: 仅在必要 bugfix 时改上述两个文件（否则不动）

**Interfaces:**
- Consumes: Task 1 的 `skin_o/de_o/x_o/y_o`
- Produces: 清理后的 1bit mask 流 `mask_o`（供 Task 3 的 CCL）

- [ ] **Step 1: 写 TB**：构造 1280x720 二值帧，含 (a) 200x150 实心矩形（模拟人脸）、(b) 椒盐噪声（每 1000 像素随机 1 个）、(c) 5x5 小方块若干、(d) 一条 3x200 细长条
- [ ] **Step 2: 跑 TB 确认噪声下失败**：断言「小方块与椒盐全部消失，200x150 矩形只剩 ≥ 190x140」
- [ ] **Step 3: 串联 module**：

```verilog
low_pass_realtime #(.WIDTH(1280), .DEPTH(720), .THRESH(15))
  u_face_lpf (.clk(clk_pixel), .pixel_valid(skin_de), .binary_input(skin_o),
              .pixel_x(skin_x), .pixel_y(skin_y),
              .filtered_output(lpf_out), .output_valid(lpf_valid));

morph_erode3x3_stream #(.WIDTH(1280), .V_OPEN_LEN(9))
  u_face_morph (.clk(clk_pixel), .rst_n(rstn_pixel), .vs_in(lpf_vs),
                .de_in(lpf_valid), .bin_in(lpf_out),
                .break_en_i(break_en), .erode_out(mask_o), .erode_valid(mask_de));
```

- [ ] **Step 4: 跑 TB 确认通过**，记录实测延迟（行数 + 拍数），写入审计表
- [ ] **Step 5: 提交**

**Acceptance:** 噪声全清、人脸块保留 ≥95% 面积；记录延迟可供 end-to-end 对齐。

---

### Task 3: 连通域 + 每帧 bbox 表（复用 `streaming_connected_components` / `true_ccl`）

**Files:**
- Create: `src/face/frame_sync_gen.v`（由 `lcd_vs` 生成 `frame_start`/`frame_end` 单拍脉冲）
- Create: `tb/face/face_ccl_tb.v`
- Modify: `Ti60_Demo.xml`（登记 `frame_sync_gen.v`）

**Interfaces:**
- Consumes: Task 2 的 `mask_o/mask_de` + `frame_start/frame_end`
- Produces: `blob_count[5:0]`、随机读表口（`raddr` → `r_min_x/r_max_x/r_min_y/r_max_y/r_area_pix/r_valid`）

```verilog
streaming_connected_components #(
  .Wb(11), .Hb(10), .Nb(10), .MAX_BLOBS(64),
  .MIN_W(60), .MIN_H(60), .MIN_AREA(4000),   // 人脸最小尺寸：1.5m 处约 120x160
  .FLUSH_ROWS(2), .WIDTH(1280)
) u_face_ccl (
  .clk(clk_pixel), .rst_n(rstn_pixel),
  .in_valid(mask_de), .in_bin(mask_o), .in_x(mask_x), .in_y(mask_y),
  .frame_start(lcd_vs_rise), .frame_end(lcd_vs_fall),
  .blob_count(ccl_blob_count), .raddr(ccl_raddr),
  .r_min_x(ccl_min_x), .r_max_x(ccl_max_x), .r_min_y(ccl_min_y), .r_max_y(ccl_max_y),
  .r_valid(ccl_valid), .r_area_pix(ccl_area), .break_en_o(break_en), .led()
);
```

- [ ] **Step 1: 写 TB**：合成帧含 3 个 blob（大方块 200x160、细长条 20x400、贴右边界的 150x150 方块），断言：`blob_count`、每个 blob 的 bbox 误差 ≤1 px、**贴边 blob 因 `FLUSH_ROWS` 被 finalize 而不是丢失**
- [ ] **Step 2: 跑 TB 确认失败**（未例化时无输出）
- [ ] **Step 3: 例化并跑通 TB**
- [ ] **Step 4: 上板单次验证**：把 `blob_count` 接到 LED（`led_o[7:0]` 空闲位），实拍时人脸出现 → 计数 >0
- [ ] **Step 5: 提交**

**Acceptance:** TB 0 错误；上板 LED 能反映 blob 存在。

---

### Task 4: bbox 选择 + 时序跟踪 `bbox_tracker`（新建 + TDD）

**Files:**
- Create: `src/face/bbox_tracker.v`
- Create: `tb/face/bbox_tracker_tb.v`
- Modify: `Ti60_Demo.xml`

**Interfaces:**
- Consumes: Task 3 的 CCL 表（或 Task 0 审计后确认的 `bbox_filter_720p` 输出）
- Produces: 平滑后的 bbox（供 Task 6 的 `bbox_overlay` 直接使用）

```verilog
module bbox_tracker #(
    parameter AWIDTH = 11,
    parameter HB     = 10,
    parameter IOU_NUM_SHIFT = 4,   // 门限 1/16
    parameter SMOOTH_SHIFT  = 3,   // 每帧向目标靠拢 1/8
    parameter HOLD_FRAMES   = 15,  // 丢失保持帧数
    parameter MIN_AR_X10    = 6,   // 宽高比下限 0.6
    parameter MAX_AR_X10    = 16   // 宽高比上限 1.6
)(
    input  wire                clk, rst_n,
    input  wire                frame_end,          // 帧末单拍
    input  wire [5:0]          in_blob_count,
    output reg  [5:0]          in_addr,
    input  wire [AWIDTH-1:0]   in_min_x, in_max_x,
    input  wire [HB-1:0]       in_min_y, in_max_y,
    input  wire                in_valid,
    output reg  [AWIDTH-1:0]   out_min_x, out_max_x,
    output reg  [HB-1:0]       out_min_y, out_max_y,
    output reg                 out_valid,
    output reg  [1:0]          dbg_state         // 0=IDLE 1=SCAN 2=TRACK 3=HOLD
);
```

- [ ] **Step 1: 写 TB**：注入 6 段序列并断言行为

| 段 | 输入序列 | 期望 |
|---|---|---|
| S1 | 静止人脸 10 帧 | `out_valid=1`，框稳定（抖动 0） |
| S2 | 中心每帧右移 2 px，共 40 帧 | 框平滑跟随，每帧位移 ≈2 px |
| S3 | 单帧噪声框（面积突变 / 位置跳 300 px） | 被拒绝，沿用上一帧 |
| S4 | 连续 10 帧无 blob | 保持最后位置，`out_valid` 仍为 1 |
| S5 | 连续 20 帧无 blob | 第 16 帧起 `out_valid=0` |
| S6 | 丢失 20 帧后重新出现 | 立即重新捕获（`out_valid=1`，无平滑拖尾） |

- [ ] **Step 2: 跑 TB 确认失败**
- [ ] **Step 3: 实现 RTL**（无除法：IoU 用移位近似或「中心距 + 宽高比」近似判据；平滑用 `cur += (tgt - cur) >>> SMOOTH_SHIFT`，注意有符号处理）
- [ ] **Step 4: 跑 TB 确认 6 段全通过**
- [ ] **Step 5: 提交**

**Acceptance:** S1~S6 全部通过；框抖动 ≤2 px；重建捕获 ≤1 帧。

---

### Task 5: 矩形框叠加（复用 `bbox_overlay`）+ 可选框内提亮

**Files:**
- Read: `src/face/bbox_overlay.v`
- Modify: `src/face/bbox_overlay.v`（仅当要做「框外压暗」时，加 `parameter DIM_OUTSIDE`，默认 0 = 行为不变）
- Create: `tb/face/bbox_overlay_tb.v`

**Interfaces:**
- Consumes: Task 4 的 `out_min_x/max_x/min_y/max_y/out_valid/blob_count` + Canny 对齐后的 `rgb/de/vs/hs/x/y`
- Produces: 最终 HDMI 像素流 `rgb_out/de_out/vs_out/hs_out`

- [ ] **Step 1: 写 TB**：1280x720 全黑底 + 一个 bbox(300,200)-(500,400)，断言框四条边像素为白、框宽 2 px、框外为黑、`de/vs/hs` 与输入同相位
- [ ] **Step 2: 跑 TB 确认失败**
- [ ] **Step 3: 例化并跑通**（例化代码放 Task 6 的 `example_top.v`，TB 里先单独验证模块）
- [ ] **Step 4: 边界用例**：bbox 贴到 (0,0)-(1279,719)、bbox 宽/高为 0、`out_valid=0` → 断言不画出任何东西且不产生 X
- [ ] **Step 5: 提交**

**Acceptance:** 框位置误差 0 px；边界用例无 X、无越界。

---

### Task 6: `example_top.v` 集成 + 端到端仿真

**Files:**
- Modify: `example_top.v`（在 Canny 链之后插入；**不要改 Canny 内部与 DDR 域**）
- Create: `tb/face/face_chain_e2e_tb.v`
- Create: `tools/ref_face_bbox.py`
- Modify: `Ti60_Demo.xml`

**Interfaces:**
- Consumes: `lcd_data/lcd_request/lcd_xpos/lcd_ypos/lcd_de/lcd_vs/lcd_hs` + Task 1~5 的模块
- Produces: 带框的 HDMI 输出

- [ ] **Step 1: 接线（关键：坐标来源）**

```verilog
// 肤色支路（clk_pixel 域，与 Canny 共用同一路 lcd_data）
rgb565_to_ycbcr_skin u_face_skin (... .de_i(lcd_request_d), .x_i(lcd_x_d[10:0]), .y_i(lcd_y_d[9:0]),
                                     .rgb565_i(lcd_data_d), .skin_o(skin_o), .de_o(skin_de), ...);
low_pass_realtime  u_face_lpf (...);
morph_erode3x3_stream u_face_morph (...);
streaming_connected_components u_face_ccl (..., .frame_start(lcd_vs_rise), .frame_end(lcd_vs_fall), ...);
bbox_tracker u_face_track (..., .frame_end(lcd_vs_fall), .out_min_x(bbox_min_x), ...);

// 叠加：x/y 必须与 canny_rgb_out 同拍 —— 直接接 hysteresis 已对齐的 x_o/y_o
hysteresis_local u_canny_hysteresis ( ... .x_o(hys_x), .y_o(hys_y) );   // 原来这两个口是空的
bbox_overlay u_face_box (
  .clk(clk_pixel), .rst_n(rstn_pixel),
  .rgb_in(canny_rgb_out), .de_in(canny_de_out), .vs_in(canny_vs_out), .hs_in(canny_hs_out),
  .x_in(hys_x_d), .y_in(hys_y_d),        // 与 canny_rgb_out 同拍（hys_x/hys_y 再多打 1 拍）
  .blob_count(track_blob_count), .addr_out(...),
  .bbox_min_x(bbox_min_x), .bbox_max_x(bbox_max_x),
  .bbox_min_y(bbox_min_y), .bbox_max_y(bbox_max_y), .bbox_valid(bbox_valid),
  .rgb_out(hdmi_rgb), .de_out(hdmi_de), .vs_out(hdmi_vs), .hs_out(hdmi_hs), .pending_swap()
);
rgb2dvi u_rgb2dvi ( ... .vid_pVSync(hdmi_vs), .vid_pHSync(hdmi_hs), .vid_pVDE(hdmi_de), .vid_pData(hdmi_rgb) );
```

- [ ] **Step 2: Python 参考模型** `tools/ref_face_bbox.py`：读一张 RGB565 图 → YCbCr 阈值 → 7x7 多数滤波 → 3x3 腐蚀 → 形态学开运算 → 连通域（scipy.ndimage.label）→ 最大 blob bbox（±1 px 容差）
- [ ] **Step 3: 端到端 TB**：把参考模型的输入帧喂给 RTL，比对 RTL 输出的 bbox 与 Python 结果（`$readmemh` 加载激励与期望值）
- [ ] **Step 4: 跑 TB**，修正对齐（先用静态图，避免运动因素）
- [ ] **Step 5: 综合 + 布局布线**：`work_syn/*.sh` → 检查 `outflow/Ti60_Demo.res.csv` 资源增量是否满足 R6、`outflow/Ti60_Demo.timing.rpt` 中 `clk_pixel` slack > 0
- [ ] **Step 6: 备份 `example_top.v.bak-before-face`** 并提交

**Acceptance:** 端到端 TB PASS（bbox 误差 ≤1 px）；时序/资源达标；既有 Canny 输出回归一致。

---

### Task 7: 上板联调 + 在线调参

**Files:**
- Modify: `example_top.v`（阈值寄存器化 + 调试显示选择）
- Modify: `src/uart/*`（如需，例化仓库中已有但悬空的 `uart_receiver.v` / `uart_transfer.v`）
- Create: `docs/notes/face_tuning_guide.md`

**Interfaces:**
- Consumes: Task 6 的完整链路
- Produces: 可现场调参的 demo + 调参手册

- [ ] **Step 1: 阈值寄存器化**：把 `cb_min_i/cb_max_i/cr_min_i/cr_max_i/y_min_i/y_max_i`、`THRESH`、`MIN_AREA`、`SMOOTH_SHIFT`、`HOLD_FRAMES` 挂到寄存器组；寄存器源二选一：复用现有 `r_axi_addr/r_axi_wdata` 桥，或例化 `src/uart` 里现成的 UART 模块（`uart_rx_i/uart_tx_o` 端口目前已悬空）
- [ ] **Step 2: 调试显示开关**（2bit `dbg_mode`）：`00` = Canny+框（正式）、`01` = 原始彩图+框、`10` = 肤色 mask、`11` = 形态学后 mask；用板载按键或寄存器切换
- [ ] **Step 3: 调参流程**（写入 `docs/notes/face_tuning_guide.md`）：
  1. 先切 `dbg_mode=10`，看肤色 mask 是否覆盖人脸、背景是否干净；
  2. 再切 `11`，看噪声是否被清掉、人脸块是否还在；
  3. 调 `MIN_AREA/MIN_W/MIN_H` 到「背景不误检、人脸不丢」；
  4. 最后调 `SMOOTH_SHIFT`（3 → 4 更稳但更迟钝）与 `HOLD_FRAMES`（15 → 25 更抗闪断）；
  5. 记录最终参数到日志。
- [ ] **Step 4: 验收测试表**（每项留截图/录像证据）：正脸 0.5m/1m/1.5m、侧脸 30°/60°、走动跟随、暗光、逆光、离开画面 3s 再进入、两人同框
- [ ] **Step 5: 更新 `.workbuddy/memory/2026-09-21.md`**（记录最终参数 + 已知问题）
- [ ] **Step 6: 提交**

**Acceptance:** 满足 R1~R4；调参手册可让第二个人复现调参过程。

---

### Task 8（可选，第二阶段）: 人脸轮廓细化

**Files:**
- Create: `src/face/face_outline_gate.v`
- Create: `tb/face/face_outline_gate_tb.v`

**Interfaces:**
- Consumes: `canny_edge`（Canny 链）+ 上一帧 bbox（来自 Task 4）
- Produces: 只在 bbox 内通过的人脸轮廓边缘；框外边缘压暗

- [ ] **Step 1: TB**：输入 Canny 二值 + bbox，断言 bbox 内边缘保留、bbox 外边缘被压暗
- [ ] **Step 2: 实现门控**（纯比较，无 BRAM）
- [ ] **Step 3: 上板对比「框内高亮」与「全屏边缘」的观感**，决定是否作为默认显示
- [ ] **Step 4: 提交**

**Acceptance:** 人脸轮廓在框内清晰可见，背景边缘不抢戏。

---

## Review Focus（最可能被忽略、必须有测试兜住的场景）

1. **暗光/逆光下人脸变成低 Y 暗块** → 肤色判据 `Y ≥ 40` 会直接判为非肤色，框会突然消失。期望：不出现乱框；丢失时按 `HOLD_FRAMES` 保持再清除（Task 4 S4/S5 覆盖）。
2. **木色桌面、手臂、墙面等类肤色背景** → 大面积误检。期望：靠宽高比 + 最小/最大面积 + 时序门限抑制（Task 3 MIN_* + Task 4 S3/S6 覆盖）。
3. **人快速转头/走出画面** → 单帧或连续多帧无 blob。期望：≤15 帧保持、超时清除、回来立即重建（Task 4 S4/S5/S6 覆盖）。
4. **两人同时入画** → 只跟最大 blob 时可能在两人之间来回跳。期望：加 IoU 门限，跳变被拒（Task 4 S3 覆盖）。
5. **摄像头对着显示器自拍（无限镜反馈，已在 9/21 录像中确认）** → 画中画里的人脸可能被误检并锁定。期望：不崩溃、可恢复；调参文档中明确此场景不作为验收条件。

---

## 执行顺序与依赖

```
Task 0（审计，只读）
  └─ Task 1（肤色分割）──┐
       └─ Task 2（形态学）┤
            └─ Task 3（CCL）┘
                 └─ Task 4（跟踪）
                      └─ Task 5（画框）
                           └─ Task 6（集成 + e2e + 综合）
                                └─ Task 7（上板调参）
                                     └─ Task 8（可选：轮廓细化）
                                          └─ Task 9 （候选 ROI 采样缓冲）      ┐
                                               └─ Task 10（XML→定点 ROM 工具）  ├ 阶段2
                                                    └─ Task 11（积分图+单级 Haar）┘
                                                         └─ Task 12（3~5 级级联）← 阶段3
```
Task 1 / 2 / 3 / 4 相互独立可并行开发（接口已冻结：见第 5 节），合并点在 Task 6。

预计工作量：
- **阶段1（Task 0~7）≈ 7.5 天**，产出「肤色框跟随」可演示版本（不含 Task 8 轮廓细化）。
- **阶段2（Task 9~11）≈ 5 天**，产出「候选框 + 单级 Haar 判别」，误检开始下降。
- **阶段3（Task 12）≈ 4 天**，产出「3~5 级小级联」，误检基本清干净。
- **总计 ≈ 16.5 天**（若阶段1 实测已满足需求，可随时停在阶段1）。

---

# 提示词（复制即用）

> 用法：**每次新开会话先贴「提示词 0」**，再贴对应 Task 的提示词。提示词 0 承载全部项目约束，不要省略。

## 提示词 0 —— 项目上下文（每次必贴）

````text
你是 FPGA RTL 工程师。工作目录：
D:\Efinity_Project\Efinity_Project\Ti60F225_OV5640_Face_Reproduction

【开工前必做】
1. 先读 .workbuddy/memory/ 下最新的工作日志（2026-09-20.md、2026-09-21.md），了解已有决策与踩坑。
2. 再读本任务的计划文件 docs/superpowers/plans/2026-09-21-face-detection-tracking.md 的
   「Global Constraints」「接口事实清单」两节，按其中的接口与约定工作。

【项目事实】
- 器件 Ti60F225（Titanium C4），工具链 D:/Efinity，构建脚本 work_syn/*.sh。
- 数据流：OV5640(MIPI CSI-2, 1280x720 RGB565) → Sensor_Image_XYCrop → axi4_ctrl(DDR3 四缓冲帧缓存,
  写 8bit/拍、读 16bit RGB565) → lcd_driver(720p60) → 输出两路：
  (a) Canny 边缘检测链（clk_pixel 域，16 拍延迟，CANNY_LATENCY=16），
  (b) 本次要并联的人脸检测支路。
- 时钟：clk_pixel=74.25MHz（约束 74.399）、clk_sys=96MHz、cmos_pclk=100MHz、DDR core_clk=192MHz。
- 现有 Canny 链：rgb565_to_gray → line_buffer_3x3 → median3x3 → line_buffer_3x3 → sobel3x3 →
  line_buffer_3x3 → nms3x3 → canny_threshold(160/80) → line_buffer_3x3 → hysteresis_local → 黑白图。
- src/face/ 下已有 7 个从未接线的模块（face_reader_720p、low_pass_realtime 含 line_delay_bit、
  morph_erode3x3_stream、true_ccl、streaming_connected_components、bbox_filter_720p、bbox_overlay），
  本次任务优先复用它们。

【硬约束（违反即返工）】
1. 新增逻辑只允许挂在 clk_pixel 域；禁止改动 DDR3 控制器域（该域最紧 setup slack 仅 +0.317ns、
   hold +0.023ns）。禁止改 src/axi/* 与 src/vision/* 的行为。
2. 分辨率固定 1280x720@60，数据面固定 RGB565：lcd_data[15:11]=R、[10:5]=G、[4:0]=B。
3. 位宽约定：x 用 [10:0]（0..1279），y 用 [9:0]（0..719）。
4. RTL 风格：timescale 1ns/1ps；时序逻辑 always @(posedge clk or negedge rst_n)；
   模块间统一「点进点出 + valid/x/y 同步透传 1 拍」；不要用 * / 运算符，改用移位加法。
5. 每个新增/修改模块必须有 XSim testbench：≥10 组定向用例 + 100000 组随机用例，0 错误；
   参考模型必须与 RTL 用不同实现路径（防 RTL 与参考同错）。
6. 修改 Ti60_Demo.xml 前必须确认 Efinity GUI 已关闭（GUI 会用内部状态覆盖该文件）。
7. 排查编译错误时，outflow/Ti60_Demo.err.log 是累积追加的，必须按日期过滤，勿把 9/16 旧错误当本次失败。
8. 改动 example_top.v 前先备份为 example_top.v.bak-<feature>。
9. 不要重构无关代码；不要引入新的 IP 核；不要动 SDC 约束。

【交付格式】
- 列出：改动/新增的文件（绝对路径）、每个 TB 的实测结果（用例数/错误数）、
  仿真延迟实测值、综合后的资源增量与 clk_pixel setup slack 数值。
- 最后更新 .workbuddy/memory/YYYY-MM-DD.md（追加本次结论与遗留问题）。
- 没有实测证据不要声称"通过/完成"。
````

## 提示词 1 —— Task 0：既有 face 模块审计

````text
（先贴提示词 0）

任务：审计 src/face/ 下 7 个既有模块，产出一份可直接指导集成的接口与延迟表。

要求：
1. 逐文件读端口、always 块、复位语义、valid 语义，输出表格：
   模块名 | 文件 | 输入(位宽/含义) | 输出(位宽/含义) | 复位方式 | 实测延迟(拍/行) | 能否直接复用
2. 为 face_reader_720p、low_pass_realtime、morph_erode3x3_stream、bbox_filter_720p、bbox_overlay
   各写一个最小 TB（tb/face/audit_<module>_tb.v），只喂一行或一帧合成数据，
   用 DE 上升沿差值测出该模块的精确延迟拍数，并把实测值填进表格。
3. 确认 line_delay_bit 是否只定义在 low_pass_realtime.v 里，列出所有依赖它的模块。
4. 确认 bbox_overlay 能否直接吃 Canny 链输出的 24bit 黑白图（rgb_in[23:0]）与
   canny_de_out/canny_vs_out/canny_hs_out，若要改接口请给出最小改动方案。
5. 结论必须明确写出：哪些模块「直接复用」、哪些「需改接口」、哪些「需重写」。

产出：docs/notes/face_module_audit.md + 5 个 audit TB + 日志更新。
不要修改任何 RTL 行为（本任务只读 + 加 TB）。
````

## 提示词 2 —— Task 1：肤色分割模块

````text
（先贴提示词 0）

任务：新建 src/face/rgb565_to_ycbcr_skin.v —— 用精确 YCbCr 判据替换 face_reader_720p 里过粗的
「U=R-G ∈ (10,90)」判据。

接口（固定，不要改）：
module rgb565_to_ycbcr_skin #(parameter AWIDTH = 11)(
  input clk, rst_n,
  input de_i, input [AWIDTH-1:0] x_i, input [9:0] y_i, input [15:0] rgb565_i,
  input [7:0] cb_min_i, cb_max_i, cr_min_i, cr_max_i, y_min_i, y_max_i,
  output reg skin_o, output reg de_o, output reg [AWIDTH-1:0] x_o, output reg [9:0] y_o
);

算法（只用移位加法，禁止乘除）：
  R8={r5,r5[4:2]}  G8={g6,g6[5:4]}  B8={b5,b5[4:2]}      // 与 rgb565_to_gray 一致的 MSB 复制
  Y  = (77R8 + 150G8 + 29B8) >> 8                          // 直接复用 rgb565_to_gray 的写法
  Cb = 128 + (-43R8 - 85G8 + 128B8) >> 8                   // 43=32+8+2+1, 85=64+16+4+1
  Cr = 128 + ( 128R8 - 107G8 - 21B8) >> 8                  // 107=64+32+8+2+1, 21=16+4+1
  skin = (Y 在 [y_min,y_max]) && (Cb 在 [cb_min,cb_max]) && (Cr 在 [cr_min,cr_max])
  默认阈值：Cb 77~127、Cr 133~173、Y 40~235（全部来自 input，运行时可调）
有符号运算请显式 $signed + 零扩展，右移用算术移位（注意 cb_sum[15:8] 的符号位处理）。

测试：tb/face/rgb565_to_ycbcr_skin_tb.v
- ≥10 组定向：典型浅肤色/深肤色/白/黑/灰/纯绿/纯蓝/纯红/暗部(Y<40)/过曝(Y>235)/阈值边界值；
  期望值用独立公式（Python 或手算真值表）算出，不得复用 RTL 写法。
- 100000 组随机 RGB565，用独立整数参考模型比对。
- 同时校验 de_o/x_o/y_o 与 skin_o 同拍（1 拍流水）。

验收：TB 0 错误；把 skin_o 直接当显示输出上板实测，人脸为白块、桌面墙面不出现大面积白块，
留截图证据。完成后更新日志并使 Ti60_Demo.xml 在 GUI 关闭状态下登记该文件。
````

## 提示词 3 —— Task 2：形态学清理

````text
（先贴提示词 0）

任务：把 Task 1 的肤色二值流清理成干净的人脸 mask，复用 low_pass_realtime（7x7 多数滤波）与
morph_erode3x3_stream（3x3 腐蚀 / 垂直 N 开运算）。

要求：
1. 新建 tb/face/face_morph_tb.v，构造 1280x720 合成二值帧，包含：
   (a) 200x150 实心矩形（模拟人脸）；(b) 椒盐噪声（约每 1000 像素 1 个）；(c) 若干 5x5 小方块；
   (d) 一条 3x200 细长条。
2. 串联两个模块（THRESH=15，V_OPEN_LEN=9），断言：小方块与椒盐全部消失、细长条消失、
   200x150 矩形剩余面积 ≥95% 且 bbox 误差 ≤2 px。
3. 记录两级的实测延迟（行数 + 拍数），填进 docs/notes/face_module_audit.md。
4. 注意 morph_erode3x3_stream 内部自己维护列计数 col_cnt3，必须让 de_in 与整行严格对齐
   （行首行尾不能多/少拍），否则会出现斜切伪影；在 TB 里专门加一条「行边界」用例验证。
5. 若必须修改这两个既有模块，只做最小 bugfix 并说明原因，同时保留原行为（加 parameter 默认关闭）。

验收：TB 0 错误；延迟已记录；不改变模块默认行为。
````

## 提示词 4 —— Task 3：连通域 + 每帧 bbox 表

````text
（先贴提示词 0）

任务：例化 streaming_connected_components（内部已含 true_ccl）得到每帧每个 blob 的 bbox 表，
并新建 src/face/frame_sync_gen.v 由 lcd_vs 生成 frame_start（上升沿单拍）与 frame_end（下降沿单拍）。

参数起步值：Wb=11, Hb=10, Nb=10, MAX_BLOBS=64, MIN_W=60, MIN_H=60, MIN_AREA=4000,
FLUSH_ROWS=2, WIDTH=1280（人脸在 1.5m 处约 120x160 px，若实拍偏小再下调）。

输入：Task 2 输出的 mask_o/mask_de（以及 x/y 透传），frame_start/frame_end。
输出：blob_count[5:0] + 随机读表口（raddr → r_min_x/r_max_x/r_min_y/r_max_y/r_area_pix/r_valid）。

要求：
1. tb/face/face_ccl_tb.v：合成一帧含 3 个 blob —— 大方块 200x160、细长条 20x400、
   贴右边界的 150x150 方块。断言：blob_count 正确；每个 blob 的 bbox 误差 ≤1 px；
   细长条被 MIN_W/MIN_H 过滤；贴边方块因 FLUSH_ROWS 被 finalize 而不是丢失。
2. 注意 true_ccl 的 `define DL 3 要求两行使能之间有足够间隔，确认 lcd 消隐期满足；
   若不满足请在 frame_sync_gen.v 里给出说明与对策。
3. 上板快速验证：把 blob_count 的低位接到 led_o 的空闲位，人脸出现时计数 >0 即说明 CCL 在工作。

验收：TB 0 错误；LED 能反映 blob 存在；延迟与时序已记录。
````

## 提示词 5 —— Task 4：bbox 时序跟踪（跟随的核心）

````text
（先贴提示词 0）

任务：新建 src/face/bbox_tracker.v，把每帧的 CCL bbox 变成「稳定跟随」的 bbox。
核心行为：筛选合法 blob → IoU/连续性门限拒跳变 → 指数平滑去抖 → 丢失保持 → 超时清除。

接口（固定）：
module bbox_tracker #(
  parameter AWIDTH=11, HB=10,
  parameter IOU_NUM_SHIFT=4,   // 门限 1/16
  parameter SMOOTH_SHIFT=3,    // 每帧靠拢 1/8
  parameter HOLD_FRAMES=15,    // 丢失保持帧数
  parameter MIN_AR_X10=6, MAX_AR_X10=16
)(
  input clk, rst_n, input frame_end,
  input [5:0] in_blob_count, output reg [5:0] in_addr,
  input [AWIDTH-1:0] in_min_x, in_max_x, input [HB-1:0] in_min_y, in_max_y, input in_valid,
  output reg [AWIDTH-1:0] out_min_x, out_max_x, output reg [HB-1:0] out_min_y, out_max_y,
  output reg out_valid, output reg [1:0] dbg_state
);

实现约束：
- 禁止除法：IoU 用移位近似，或退化为「中心距 < 上一帧宽度/2 且宽高比变化 < 25%」的连续性判据。
- 平滑：cur += (tgt - cur) >>> SMOOTH_SHIFT（注意有符号减法与向下取整不产生偏置）。
- 状态机：IDLE → SCAN（frame_end 后逐拍扫 64 个 blob）→ TRACK / HOLD。

测试 tb/face/bbox_tracker_tb.v 必须覆盖：
S1 静止 10 帧 → out_valid=1、框抖动 0；
S2 每帧右移 2px 共 40 帧 → 平滑跟随；
S3 单帧噪声框（面积突变或位置跳 300px）→ 被拒绝，沿用上一帧；
S4 连续 10 帧无 blob → 保持最后位置且 out_valid=1；
S5 连续 20 帧无 blob → 第 16 帧起 out_valid=0；
S6 丢失 20 帧后重新出现 → 立即重建（无平滑拖尾）。

验收：S1~S6 全通过；框抖动 ≤2 px；重建 ≤1 帧。
````

## 提示词 6 —— Task 5+6：画框与顶层集成

````text
（先贴提示词 0）

任务：在 example_top.v 里把整个人脸支路并联到 Canny 链路旁，并用 bbox_overlay 画出跟随人脸的 2px 白框。

关键接线要求：
1. 肤色支路的输入必须用与 Canny 相同的 lcd_data（DDR 读回的 RGB565）与同一套 lcd_request/xpos/ypos。
2. 叠加级的 x/y 必须与 canny_rgb_out 同拍：把 hysteresis_local 原本悬空的 .x_o/.y_o 接出来使用
   （它们与 edge_o 同拍），必要时再打 1 拍对齐，不要自己另起计数器。
3. bbox_overlay 的 de_in/vs_in/hs_in 接 canny_de_out/canny_vs_out/canny_hs_out，
   rgb_in 接 canny_rgb_out；rgb_out/de_out/vs_out/hs_out 直接送 rgb2dvi。
4. bbox 表来自 bbox_tracker（上一帧结果），即框有 1 帧延迟 —— 这是设计选择，不要试图消除。
5. 备份 example_top.v 为 example_top.v.bak-before-face；不要改 Canny 内部与 DDR 域的任何逻辑。

还要做：
- 新建 tools/ref_face_bbox.py（numpy+scipy）：YCbCr 阈值 → 7x7 多数滤波 → 3x3 腐蚀 → 开运算 →
  连通域 → 最大 blob bbox，作为端到端参考模型。
- 新建 tb/face/face_chain_e2e_tb.v：用静态 1280x720 图（$readmemh 加载激励与期望 bbox）
  跑完整链路，断言 RTL bbox 与 Python 参考误差 ≤1 px。
- 跑综合：检查 outflow/Ti60_Demo.res.csv 的资源增量（目标 ≤ +25 RAM10、+4000 LUT4、+2500 FF）
  与 outflow/Ti60_Demo.timing.rpt 中 clk_pixel setup slack > 0。
- 回归：确认 Canny 边缘图与改动前一致（同一段录像对比，允许框叠加造成的差异）。

验收：e2e TB PASS；资源/时序达标；Canny 无回归。
````

## 提示词 7 —— 上板调参

````text
（先贴提示词 0）

任务：把 demo 变成可现场调参、可现场看中间结果的版本，并完成验收测试表。

要求：
1. 阈值寄存器化：cb_min/cb_max/cr_min/cr_max/y_min/y_max、THRESH、MIN_AREA、SMOOTH_SHIFT、
   HOLD_FRAMES 全部改为寄存器可写。寄存器源二选一：复用现有 r_axi_addr/r_axi_wdata 桥，
   或例化仓库里已有但当前悬空的 src/uart/uart_receiver.v + uart_transfer.v
   （uart_rx_i/uart_tx_o 端口现已存在但未接线）。
2. 调试显示开关 dbg_mode[1:0]：00=Canny+框（正式）、01=原始彩图+框、10=肤色 mask、11=形态学后 mask。
3. 写 docs/notes/face_tuning_guide.md：给出五步调参流程（先看 mask、再调面积门限、
   再调平滑/保持、最后定稿），以及每个参数「调大/调小的现象」。
4. 完成验收测试表并留证据（截图/录像）：正脸 0.5m/1m/1.5m、侧脸 30°/60°、走动跟随、
   暗光、逆光、离开画面 3s 再进入、两人同框、相机对屏自拍（已知物理反馈，不作为通过条件）。
5. 记录最终参数与已知问题到 .workbuddy/memory/。

验收：单人正脸检出率 ≥90%、框抖动 ≤2 px、丢失 ≤15 帧不闪断、720p60 不断流。
````

## 提示词 8 —— 排障 / 现象诊断

````text
（先贴提示词 0）

现象：<把看到的现象写在这里，例如"框一直不动"、"框乱跳"、"人移动时框跟不上"、"框完全不出来"、"画面出现斜切条纹">

请按下面的顺序定位，每步给出实测证据，不要跳步下结论：
1. 先分层定位：把 dbg_mode 依次切到 10（肤色 mask）→ 11（形态学后），判断问题出在
   「肤色分割」还是「形态学/CCL/跟踪」层。
2. 若 mask 层就错：检查 YCbCr 阈值是否适配当前光照（暗光 Y<40 会整片判非肤色；
   白平衡漂移会让 Cr 偏移），用寄存器扫描阈值并记录边界。
3. 若 mask 正确但 blob 不对：检查 MIN_W/MIN_H/MIN_AREA 是否把脸过滤掉了，
   以及 frame_start/frame_end 是否与 lcd_vs 沿严格对齐（用 ILA/引 LED 观察）。
4. 若 blob 正确但框乱跳或不动：检查 bbox_tracker 的连续性门限与 HOLD_FRAMES；
   确认 out_valid 与 dbg_state 的行为符合 S1~S6 的预期。
5. 若框位置整体偏移：检查叠加级 x/y 是否与 canny_rgb_out 同拍（差 1 拍=整框偏 1 像素；
   若接到未延迟的 lcd_xpos 会偏 16 像素）。
6. 若画面有条纹/斜切：优先怀疑 morph/CCL 的列计数与 de 行边界不对齐，或 line_buffer 读地址越界。

最后给出：根因、最小修复、以及能复现该问题的 TB 用例（必须补进回归）。
````

## 提示词 9 —— 阶段收尾（每个 Task 完成后贴）

````text
（先贴提示词 0）

任务：收尾本阶段。
1. 备份改动过的顶层文件为 example_top.v.bak-<feature>（如涉及）。
2. 重跑综合+布局布线（work_syn/*.sh），汇报：
   - outflow/Ti60_Demo.res.csv 的资源增量（RAM10 / LUT4 / FF / SRL）
   - outflow/Ti60_Demo.timing.rpt 中 clk_pixel 的 setup slack，以及全设计最小 slack
   - 确认无新增 hold 违例
3. 更新 .workbuddy/memory/YYYY-MM-DD.md：本阶段做了什么、实测数据、踩坑、遗留问题、下一步。
4. 回报时只用实测数字，不要用"应该/大概/预期"。
````

---

# 阶段2/3：Haar-like 判别路线（v2 增补，采用「肤色出候选 + Haar 判别」）

> **为什么不做全图 Haar 扫描**：720p 整帧积分图需 1281x721x28bit = **3.2 MB**，而 Ti60F225 片内总共只有 **320 KB**（256 块 RAM10 x 10 Kbit）；即使降到 320x240 也要 241 KB，会把剩余 BRAM 吃光。所以走「候选 ROI 局部积分图」：65x65x25bit = **13 KB**，代价低两个数量级，而效果损失很小。
> **为什么复用肤色链**：肤色链已经能把人脸位置缩到 1~4 个候选框，Haar 只在候选上做「是不是人脸」的结构判别，不需要多尺度全图扫描。

### Task 9: 候选 ROI 采样缓冲 `candidate_roi_extract.v`

**Files:**
- Create: `src/face/candidate_roi_extract.v`
- Create: `tb/face/candidate_roi_extract_tb.v`
- Modify: `Ti60_Demo.xml`（GUI 关闭状态下登记）

**Interfaces:**
- Consumes: 上一帧候选 bbox 表（来自 Task 3/4，最多 `K=4` 个候选）+ 本帧灰度像素流（`gray_w/gray_de/gray_x/gray_y`，来自 `rgb565_to_gray`）
- Produces: `K` 组 64x64x8bit ROI 缓冲（双缓冲 A/B）+ 每组 `roi_valid` + 对应候选坐标

```verilog
module candidate_roi_extract #(
    parameter integer K       = 4,      // 候选数
    parameter integer ROI_W   = 64,
    parameter integer ROI_H   = 64,
    parameter integer AWIDTH  = 11
)(
    input  wire                clk, rst_n,
    // 候选表（帧末更新）
    input  wire                cand_load,              // 帧末单拍：把候选表锁存进工作组
    input  wire [K*11-1:0]     cand_min_x, cand_max_x,
    input  wire [K*10-1:0]     cand_min_y, cand_max_y,
    input  wire [K-1:0]        cand_valid,
    // 下一帧像素流
    input  wire                pix_de,
    input  wire [AWIDTH-1:0]   pix_x,
    input  wire [9:0]          pix_y,
    input  wire [7:0]          pix_gray,
    // 输出：bank_sel 选中的那一组 ROI（供 Task 11 逐行读）
    input  wire                rd_en,
    input  wire [11:0]         rd_addr,                // 0..4095
    output reg  [7:0]          rd_data,
    output reg  [K-1:0]        roi_ready,              // 该组已填满
    output wire [K-1:0]        roi_active             // 该候选本次是否命中过像素
);
```

- [ ] **Step 1: 写失败的 TB**

```verilog
// 关键断言：把候选框指向一张已知图案的方块，检查 64x64 ROI 内容
// 图案：源图 120x160 区域每像素 = (x + y) & 8'hFF，便于定位采样错位
initial begin
  gen_frame();                                  // 生成 1280x720 测试帧
  load_candidates(120,200, 240,360);            // 一个 120x160 的候选框
  stream_frame();
  compare_roi_to_reference(64,64);              // 参考模型：最近邻缩放 + 边界裁剪
  if (mismatch > 2) $display("FAIL roi mismatch=%0d", mismatch);   // 容差 2 像素
end
```

- [ ] **Step 2: 跑 TB 确认失败** —— Expected: `FAIL roi mismatch=...`（模块未实现）
- [ ] **Step 3: 实现 RTL**（要点：**不要回读 DDR**，用「下一帧边流边填」）

```verilog
// 采样缩放：Bresenham 累加器，禁用除法
// 目标列 tx (0..63) 对应源列 = min_x + (tx * src_w) / 64
wire [11:0] step_x = {src_w, 6'b0} + ...;   // 用累加器实现 tx*src_w/64
always @(posedge clk) if (pix_de) begin
    for (i = 0; i < K; i = i + 1)
        if (cand_valid[i] && pix_y >= min_y[i] && pix_y <= max_y[i]
                          && pix_x >= min_x[i] && pix_x <= max_x[i]
                          && x_acc[i][11:6] == tx_cnt[i]) begin
            roi_mem[i][wr_addr] <= pix_gray;
            x_acc[i] <= x_acc[i] + src_w[i];
        end
end
```

- [ ] **Step 4: 跑 TB 确认通过**
- [ ] **Step 5: 边界用例**：候选框 <64x64（放大采样）、贴到画面边缘（越界裁剪）、4 个候选同时命中、候选框宽或高为 0 → 断言不产生 X、不写坏相邻缓冲
- [ ] **Step 6: 提交**

**Acceptance:** ROI 内容与参考模型误差 ≤2 灰度；边界用例无 X；资源 ≤ 20 个 RAM10（4 组 x 64x64x8bit = 16 KB）。

---

### Task 10: PC 端定点化工具 + 参考模型（**最高风险项，先做**）

**Files:**
- Create: `tools/haar_xml_to_rom.py`
- Create: `tools/ref_haar_eval.py`
- Create: `rom/face_stage*.mem`、`rom/face_cascade_params.vh`（脚本生成，不要手改）

**Interfaces:**
- Consumes: OpenCV cascade XML（`haarcascade_frontalface_default.xml`，或自训练产物）
- Produces: `$readmemh` 格式的特征 ROM + 参数头文件 + 黄金测试向量

- [ ] **Step 1: 解析 XML**：每级（stage）包含若干 weak classifier，每个含 1 个 Haar 特征（2~3 个矩形 rect: x,y,w,h,weight）+ 特征阈值/left/right value + stage threshold

```python
# tools/haar_xml_to_rom.py 关键片段
rects = [(r.x, r.y, r.w, r.h, int(round(r.weight * 256))) for r in feature.rects]  # Q8 权重
# 特征值（定点，与 RTL 完全一致）：
#   sum_rect = II[x+w][y+h] - II[x][y+h] - II[x+w][y] + II[x][y]
#   feat     = (sum(rect.weight_q8 * sum_rect)) >> 8
```

- [ ] **Step 2: 写死定点化规则并写进文件头注释**（RTL 必须逐条照做）：
  - 权重 Q8（x256 取整），特征值 = `(Σ w_q8 * sum_rect) >> 8`
  - 积分图位宽：64x64 ROI 最大和 = 255x4096 = 1,044,480 → **21 bit 足够，取 25 bit 留裕量**
  - **第一版不做窗口方差归一化**（OpenCV 原版做）；用 stage threshold 补偿。若实测精度不够，阶段3 再用现成的 `efx_integer_square_root` IP
- [ ] **Step 3: 实现定点参考模型** `tools/ref_haar_eval.py`：输入 64x64 灰度窗口 → 输出「第几级被拒 / 全部通过」

```python
def eval_window(img64):
    ii = integral(img64)
    for si, stage in enumerate(stages):
        if stage_eval(ii, stage) < stage.threshold: return si   # early reject
    return -1                                                    # 通过全部级
```

- [ ] **Step 4: 生成黄金向量**：≥1000 个窗口（人脸样本从 demo 录像裁、非人脸样本从桌面/墙面裁），存 `tb/face/vectors/haar_golden.txt`（每行：64x64 像素 hex + 期望级号）
- [ ] **Step 5: 自测**：用录像裁出的人脸窗口应通过、桌面/手臂窗口应在前 2 级被拒。**对不上的话先修定点化规则，不要动阶段1 的任何代码**
- [ ] **Step 6: 提交**

**Acceptance:** 定点参考模型与浮点 OpenCV 版判定差异 <5%；黄金向量覆盖 ≥1000 窗口；`rom/*.mem` 与 `.vh` 生成完毕。

---

### Task 11: 局部积分图 + 单级 Haar 强分类器（阶段2 里程碑）

**Files:**
- Create: `src/face/integral_roi.v`、`src/face/haar_single_stage.v`
- Create: `tb/face/integral_roi_tb.v`、`tb/face/haar_classifier_tb.v`
- Modify: `Ti60_Demo.xml`

**Interfaces:**

```verilog
module integral_roi #(parameter integer W = 64, parameter integer H = 64,
                      parameter integer IW = 25, parameter integer AW = 13)(
    input  wire clk, rst_n,
    input  wire start,                       // 开始算一个 ROI
    input  wire [AW-1:0] rd_addr, output reg [7:0] rd_data,   // 读 ROI 像素
    output reg  [AW-1:0] iiwr_addr, output wire [IW-1:0] iiwr_data,
    output reg  iiwr_en, output reg done,
    input  wire [AW-1:0] iird_addr, output reg [IW-1:0] iird_data   // 积分图读口
);

module haar_single_stage #(parameter integer NF = 3, parameter integer IW = 25)(
    input  wire clk, rst_n, input wire start,
    output reg  [AW-1:0] ii_addr, input wire [IW-1:0] ii_data,      // 读积分图
    output reg  [AW-1:0] rom_addr, input wire [63:0] rom_data,      // 读特征 ROM
    output reg  signed [31:0] score, output reg pass, output reg done
);
```

- [ ] **Step 1: 写 TB**：用 Task 10 的黄金向量里的**单级**子集对拍（≥1000 窗口），断言 `pass` 完全一致
- [ ] **Step 2: 跑 TB 确认失败**
- [ ] **Step 3: 实现积分图**：行内前缀和 + 行方向累加；65x65x25bit = 105,625 bit → **约 15 个 RAM10**；**串行复用一块**（4 个候选排队算，不并行开 4 块）
- [ ] **Step 4: 实现单级分类器**：每特征 4 次积分图读 → 矩形和 → Q8 加权累加 → 与 stage threshold 比较；3 个特征约 30~60 拍/窗口
- [ ] **Step 5: 跑 TB 确认通过**（与黄金向量 100% 一致）
- [ ] **Step 6: 上板先做「只判别不让它影响显示」的旁路验证**：把 pass 引到 LED，对真人脸/桌面各测 20 次，记录命中率
- [ ] **Step 7: 提交**

**Acceptance:** 与黄金向量判定 100% 一致；资源增量 ≤ 20 个 RAM10 + 1500 XLR；LED 旁路验证人脸命中率 >80%。

---

### Task 12: 3~5 级小级联 + 候选打分排序（阶段3 里程碑）

**Files:**
- Create: `src/face/haar_cascade.v`、`tb/face/haar_cascade_tb.v`
- Modify: `example_top.v`（把 `bbox_tracker` 的输入从「最大 blob」换成「通过 Haar 的最高分候选」）
- Modify: `rom/face_stage*.mem`（扩展到 stage0~4）

**Interfaces:**

```verilog
module haar_cascade #(parameter integer K = 4, parameter integer MAX_STAGE = 5)(
    input  wire clk, rst_n,
    input  wire start,                                  // 帧末启动
    input  wire [K-1:0] cand_valid,
    output reg  [$clog2(K)-1:0] cand_idx,               // 当前判别到哪个候选
    output reg  [2:0] cur_stage,
    // 与 Task 11 的积分图/单级分类器相连
    output reg  score_rd, input wire [31:0] stage_score,
    output reg  [K-1:0] cand_pass, output reg [K*32-1:0] cand_total_score,
    output reg  done, output reg [$clog2(K)-1:0] best_idx, output reg best_valid
);
```

- [ ] **Step 1: 写 TB**：注入 4 个候选（1 个真脸 + 3 个桌面/手臂），断言：真脸 `pass=1` 且被选为 `best_idx`；三个干扰前 2 级内被拒
- [ ] **Step 2: 跑 TB 确认失败**
- [ ] **Step 3: 实现级联**：候选串行、每级 early-reject、level-0 不过立即换下一个候选；ROM 按需扩展到 stage0~4（约 50~100 个特征 → **4~8 个 RAM10**；若将来上满 25 级，全表约 80 个 RAM10，仍在 194 块余量内）
- [ ] **Step 4: 跑 TB 确认通过**
- [ ] **Step 5: 顶层集成**：`bbox_tracker` 的输入改为 Haar 通过的最高分候选；**未通过任何候选时喂「无效」**（让跟踪器进入 HOLD，而不是乱跳）

```verilog
// example_top.v 集成要点
assign track_in_valid = best_valid;                 // 不再直接用最大 blob
assign track_in_min_x = cand_min_x[best_idx];       // 通过 Haar 的候选坐标
assign track_in_max_x = cand_max_x[best_idx];
```

- [ ] **Step 6: 综合 + 时序 + 资源**：确认 RAM10 总量 ≤ 256（预估 62 现有 + 22 肤色链 + 16 ROI + 15 积分图 + 8 ROM ≈ 123 块，约 48%）、`clk_pixel` slack > 0
- [ ] **Step 7: 上板验收**：同一场景对比「阶段1 只有肤色」与「阶段3 含 Haar」的误检次数
- [ ] **Step 8: 提交**

**Acceptance:** 满足 R7（类肤色干扰误检下降 ≥80%）；帧率仍 720p60（4 候选 x 5 级串行约 2000 拍 = 13 us @150MHz，远小于 16.7 ms/帧）；资源满足 R6。

---

### Task 13（可选）: 多人脸

**Files:** Modify `src/face/haar_cascade.v`（多个通过候选各占一个 tracker 槽位）、`example_top.v`、`src/face/bbox_overlay.v`（支持多框）

- [ ] **Step 1:** TB 注入 2 张人脸 + 2 个干扰，断言输出两个框
- [ ] **Step 2:** 实现多槽位跟踪（每槽位独立 IoU/平滑/保持）
- [ ] **Step 3:** 上板验证两人同框场景
- [ ] **Step 4:** 提交

## Review Focus 增补（Haar 专属，最容易翻车的 5 条）

1. **定点化与 OpenCV 浮点不一致** → 同一张脸在 PC 上通过、在 RTL 上被拒。必须用 Task 10 的黄金向量对拍，判定差异 >5% 就不许进 Task 11。
2. **跳过方差归一化** → 暗光/强光下同一张脸判定翻转。若实拍误判多，接 `efx_integer_square_root` IP 补上（Efinity 自带，不用手写）。
3. **候选框漏检**（肤色阶段没框住脸）→ Haar 再强也救不回来。这要求阶段1 的检出率 ≥90%（R1 必须先达标）。
4. **ROI 缩放几何失真** → 非 64x64 的候选框在采样时变形，导致 Haar 误判。Task 9 的 TB 必须覆盖「候选框宽高差异大」「贴边裁剪」两类用例。
5. **级联表 ROM 扩容把 BRAM 吃紧** → 每扩一级都要重算「现有 62 + 肤色链 22 + ROI 16 + 积分图 15 + ROM」总量，Task 12 Step 6 已把它列为必做项。

---

# 提示词（阶段2/3 追加）

## 提示词 10 —— Task 9：候选 ROI 采样缓冲

````text
（先贴提示词 0）

任务：新建 src/face/candidate_roi_extract.v —— 把上一帧的候选框（最多 4 个）在本帧像素流过的时候就填进
64x64 的灰度 ROI 缓冲，**不允许回读 DDR**。

背景：候选框是帧末才知道的，所以采样发生在「下一帧」；填充用的像素流直接取 rgb565_to_gray 的
gray_w/gray_de/gray_x/gray_y。这一级是 Haar 判别的图像源。

接口见计划文件 Task 9。实现要点：
1. 缩放用 Bresenham 累加器（x_acc += src_w; 当 x_acc[11:6] 前进一档就写一个采样点），
   禁止除法/乘法。
2. 4 个候选各自独立的累加器与写地址；命中判据 = 像素坐标落在候选框内且行采样命中。
3. 双缓冲：A 组本帧填，B 组同时供 Task 11 判别；帧末切换。
4. 每组 = 64x64x8bit = 4 KB，4 组共 16 KB（约 16 个 RAM10）。

测试 tb/face/candidate_roi_extract_tb.v：
- 生成 1280x720 测试帧，图案用 pix = (x + y) & 0xFF 便于定位错位；
- 候选框 120x160 → 断言 ROI 内容与「最近邻缩放参考模型」误差 ≤2 灰度；
- 边界用例：候选框 <64x64（放大）、贴画面边缘（越界裁剪）、4 候选同时、候选宽高为 0。

验收：TB 0 错误；边界用例无 X；资源 ≤20 个 RAM10。
````

## 提示词 11 —— Task 10：Haar 定点化工具 + 参考模型（最高风险，先做）

````text
（先贴提示词 0）

任务：写 PC 端工具，把 OpenCV 的 Haar cascade XML 转成 RTL 能吃的定点 ROM，并生成黄金测试向量。
这是整条 Haar 路线里最容易翻车的一步，必须先做、必须做扎实。

交付：
1. tools/haar_xml_to_rom.py
   - 解析 haarcascade_frontalface_default.xml（或用户自训练的同格式文件）；
   - 每级：weak classifier 数、每个特征的 2~3 个矩形 (x,y,w,h,weight)、特征阈值/left/right、
     级阈值；
   - 定点化规则（写进脚本头部注释，RTL 必须逐条照做）：
       * 矩形权重 Q8 = round(weight * 256)
       * 特征值 = (Σ w_q8 * 矩形和) >> 8
       * 积分图位宽 25 bit（64x64 最大和 1,044,480 只需 21 bit，留裕量）
       * 第一版不做窗口方差归一化，用级阈值补偿（若精度不够，后续接 Efinity 自带的
         efx_integer_square_root IP）
   - 输出 rom/face_stage{N}.mem（$readmemh）与 rom/face_cascade_params.vh。
2. tools/ref_haar_eval.py：整数定点参考实现，输入一个 64x64 灰度窗口，输出「在第几级被拒 / 全部通过」。
3. tb/face/vectors/haar_golden.txt：≥1000 个窗口（人脸样本从 _analysis/video_frames 裁，
   非人脸从桌面/墙面/手臂裁），每行 = 64x64 像素 hex + 期望级号。

自测要求：录像里裁出的人脸窗口应通过、桌面与手臂窗口应在前 2 级被拒；
定点模型与浮点 OpenCV 版判定差异必须 <5%，否则先修定点化规则，不要动阶段1 代码。

验收：脚本可重复运行（幂等）；黄金向量生成；rom/*.mem 与 .vh 生成完毕；差异 <5% 有数据证明。
````

## 提示词 12 —— Task 11：局部积分图 + 单级 Haar 分类器

````text
（先贴提示词 0）

任务：新建 src/face/integral_roi.v 与 src/face/haar_single_stage.v，先把「单级判别」的数据通路跑通。

接口见计划文件 Task 11。实现要点：
1. 积分图只做 64x64 的局部 ROI（65x65x25bit = 105,625 bit ≈ 15 个 RAM10），
   4 个候选**串行复用一块 RAM**，不要并行开 4 份。
2. 矩形和统一用四点法：S = II[x+w][y+h] - II[x][y+h] - II[x+w][y] + II[x][y]。
3. 特征值 = (Σ weight_q8 × S) >> 8，全部有符号运算，注意零扩展与算术右移。
4. 单级用 cascade 的 stage0（3 个特征）先跑；每个窗口约 30~60 拍。

测试：
- tb/face/integral_roi_tb.v：随机 64x64 窗口，积分图与 numpy 参考逐点比对（0 误差）；
- tb/face/haar_classifier_tb.v：用 Task 10 黄金向量的单级子集（≥1000 窗口），
  断言 pass 与参考模型 100% 一致。

上板旁路验证：把 pass 接 LED，对真人脸/桌面各测 20 次并记录命中率，先不要影响显示。

验收：判定 100% 一致；资源 ≤20 个 RAM10 + 1500 XLR；LED 命中率数据已记录。
````

## 提示词 13 —— Task 12：3~5 级级联 + 候选排序

````text
（先贴提示词 0）

任务：新建 src/face/haar_cascade.v，把单级升级为 stage0~4 的小级联，并把「通过 Haar 的最高分候选」
送到 bbox_tracker；同时把 example_top.v 的跟踪输入从「最大 blob」换成「Haar 通过的候选」。

要求：
1. 候选串行评估（最多 4 个），每级 early-reject（不过就立刻换下一个候选）。
2. ROM 扩展到 stage0~4（约 50~100 个特征 → 4~8 个 RAM10）；若将来要上满 25 级，
   全表约 80 个 RAM10，必须先重算总资源。
3. **没有任何候选通过时，必须喂「无效」给跟踪器**，让它进入 HOLD 保持上一帧位置，
   而不是乱跳到别的 blob。
4. example_top.v 改动前备份为 example_top.v.bak-haar-cascade。

测试 tb/face/haar_cascade_tb.v：4 个候选（1 真脸 + 3 干扰），断言真脸被选为 best_idx、
3 个干扰在前 2 级被拒。

综合与验收：
- 资源总量核算：现有 62 + 肤色链 ~22 + ROI 16 + 积分图 15 + ROM 8 ≈ 123 块 RAM10（约 48%），
  必须实测确认；clk_pixel setup slack 必须 >0；
- 上板对比「只有肤色（阶段1）」与「含 Haar（阶段3）」在同一场景的误检次数，
  目标误检下降 ≥80%；
- 帧率必须仍为 720p60（4 候选 x 5 级串行约 2000 拍 ≈13us，远小于 16.7ms）。

验收：R7 达标（误检下降 ≥80%）、检出率不低于阶段1；资源与时序有实测数字。
````
