# face 模块接口与延迟审计（Task 0）

- 日期：2026-09-21
- 审计人：FPGA RTL 工程师（自动化）
- 依据：`docs/superpowers/plans/2026-09-21-face-detection-tracking.md` 第 2、5 节
- 方法：读 RTL 端口 + XSim 实测延迟（三版 TB，见 `tb/face/audit_face_latency*_tb.v`）

---

## 1. 模块清单与复用结论

| # | 模块 | 文件 | 结论 | 理由 |
|---|---|---|---|---|
| 1 | `face_reader_720p` | `src/face/face_reader_720p.v` | **需替换** | 判据只有 `U=R-G`（10<U<90），过于粗糙；Task 1 用 `rgb565_to_ycbcr_skin` 替换，**保持同构接口** |
| 2 | `low_pass_realtime` | `src/face/low_pass_realtime.v` | **直接复用** | 7x7 圆盘多数滤波（N=29, THRESH=15），功能正确，无需改动 |
| 3 | `line_delay_bit` | 同上文件 `:125` | **直接复用** | 1bit×WIDTH 行延时，同步读延 1 拍。**被 2/4 依赖，该文件必须始终在构建里** |
| 4 | `morph_erode3x3_stream` | `src/face/morph_erode3x3_stream.v` | **直接复用（有注意事项）** | 3x3 腐蚀 / 垂直 N 开运算双路径。**见 §4.3 的 vs_in 接线约束** |
| 5 | `streaming_connected_components` | `src/face/streaming_connected_components.v` | **直接复用** | 含贴边冲刷状态机（`FLUSH_ROWS`）+ 双缓冲表 |
| 6 | `true_ccl` | `src/face/true_ccl.v` | **直接复用（已修 bugfix）** | 被 5 例化，**不要单独再例化**。本 Task 已修 Verilog-2001 前向声明问题 |
| 7 | `bbox_filter_720p` | `src/face/bbox_filter_720p.v` | **直接复用** | 5 维过滤（尺寸/紧凑度/轴比/填充率/位置），输出容量 32 |
| 8 | `bbox_overlay` | `src/face/bbox_overlay.v` | **直接复用** | 帧稳定双缓冲，VS 切换。**可直接吃 Canny 的 24bit 输出**（见 §5） |

---

## 2. 端口清单

### 2.1 `low_pass_realtime`
| 方向 | 端口 | 位宽 | 说明 |
|---|---|---|---|
| in | `clk` | 1 | |
| in | `pixel_valid` | 1 | 当 valid |
| in | `binary_input` | 1 | 二值像素 |
| in | `pixel_x` | 11 | 0..WIDTH-1 |
| in | `pixel_y` | 10 | 0..DEPTH-1 |
| out | `filtered_output` | 1 | 滤波后二值 |
| out | `output_valid` | 1 | 窗口完全覆盖才为 1 |

参数：`WIDTH=1280, DEPTH=720, RADIUS=3, THRESH=15`
**无 `rst_n` 端口**（只有 `clk`），复位靠 `pixel_valid` 与行首清零。

### 2.2 `morph_erode3x3_stream`
| 方向 | 端口 | 位宽 | 说明 |
|---|---|---|---|
| in | `clk`, `rst_n` | 1 | rst_n 异步低有效 |
| in | `vs_in` | 1 | **必须接本级自己的 VS**（见 §4.3） |
| in | `de_in` | 1 | 数据使能 |
| in | `bin_in` | 1 | 二值像素 |
| in | `break_en_i` | 1 | 0=3x3 腐蚀；1=垂直 N 开运算 |
| out | `erode_out` | 1 | 自适应输出 |
| out | `erode_valid` | 1 | 对应路径有效 |

参数：`WIDTH=1280, V_OPEN_LEN=9`（内部 `VLEN=9`）

### 2.3 `streaming_connected_components`
| 方向 | 端口 | 位宽 | 说明 |
|---|---|---|---|
| in | `clk`, `rst_n` | 1 | |
| in | `in_valid`, `in_bin` | 1 | 像素流 |
| in | `in_x`, `in_y` | 11, 10 | **接口保留，内部未使用** |
| in | `frame_start` | 1 | VS 上升沿**单拍** |
| in | `frame_end` | 1 | VS 下降沿**单拍** |
| out | `blob_count` | 6 | 上一帧 blob 数 |
| in | `raddr` | 6 | 随机读地址 1..blob_count |
| out | `r_min_x/r_max_x` | 11 | |
| out | `r_min_y/r_max_y` | 10 | |
| out | `r_valid` | 1 | |
| out | `r_area_pix` | 22 | |
| out | `break_en_o` | 1 | 上一帧是否见大块 |
| out | `led` | 1 | debug |

参数（计划规定）：`Wb=11, Hb=10, Nb=10, MAX_BLOBS=64, MIN_W=60, MIN_H=60, MIN_AREA=4000, FLUSH_ROWS=2, WIDTH=1280`

### 2.4 `bbox_filter_720p`
上游读口（接 CCL）：`in_blob_count, in_addr_out, in_bbox_min_x/max_x/min_y/max_y, in_area_pix, in_bbox_valid`
下游读口（接 tracker/overlay）：`blob_count, addr_in, bbox_min_x/max_x/min_y/max_y, bbox_valid`
另有 `vs_in, clk, rst_n, fetching_active`

### 2.5 `bbox_overlay`
| 方向 | 端口 | 位宽 |
|---|---|---|
| in | `clk`, `rst_n` | 1 |
| in | `rgb_in` | 24 |
| in | `de_in`, `vs_in`, `hs_in` | 1 |
| in | `x_in`, `y_in` | 11, 10 |
| in | `blob_count` | 6 |
| out | `addr_out` | 6 |
| in | `bbox_min_x/max_x` | 11 |
| in | `bbox_min_y/max_y` | 10 |
| in | `bbox_valid` | 1 |
| out | `rgb_out` | 24 |
| out | `de_out`, `vs_out`, `hs_out` | 1 |
| out | `pending_swap` | 1 |

参数：`WIDTH=1280, HEIGHT=720, MAX_BLOBS=16, THICKNESS=2`

---

## 3. 延迟实测结果

### 3.1 测量方法与被否定的方法

| 版本 | 方法 | 结果 | 是否采信 |
|---|---|---|---|
| v1 | 输出侧首次 `valid` 拉高的时刻 | 含 `row_ready` 饱和等待，**不是纯延迟** | ✗ |
| v2 | 脉冲块上升沿 | 脉冲被腐蚀/滤波改变形状，边沿不可靠 | ✗ |
| v3 | 同序号像素的相位差分 | 行延迟稳定复现 | **✓（行延迟）** |

**三版一致的行延迟数字**（这是接口对齐唯一需要的量）：

### 3.2 实测行延迟（可信）

| 模块 | 行延迟 | 设计预期 | 吻合 |
|---|---|---|---|
| `low_pass_realtime` | **6 行** | 6 级 `line_delay_bit` | ✓ |
| `morph_erode3x3_stream`（`break_en_i=0` 腐蚀） | **2 行** | 2 级 `line_delay_bit` | ✓ |
| `morph_erode3x3_stream`（`break_en_i=1` 开运算，`V_OPEN_LEN=9`） | **8 行**（见 §4.2 警告） | 2×(VLEN-1)=16 行 | ⚠ |
| `bbox_overlay` | **1 拍** | `de_out <= de_in` | ✓ |

### 3.3 拍残余（不可信，仅记录）

| 模块 | v1 残余 | v2 残余 | v3 残余 |
|---|---|---|---|
| `low_pass_realtime` | 9 拍 | 9 拍 | 310 拍 |
| `morph`（腐蚀） | 3 拍 | 7 拍 | 104 拍 |
| `morph`（开运算） | 1 拍 | 负值 | 2 拍 |

**结论：拍残余不可作为设计依据。** 原因：这两个模块的 `valid` 在帧首存在
过渡区（`row_ready` 未饱和期间），且行缓存的「读写同址」机制使 `de` 相位与
数据相位不同步。**接口对齐只用行延迟**，拍残余由 Task 6 端到端仿真逐像素标定。

---

## 4. 关键发现（必须遵守）

### 4.1 `low_pass_realtime` 没有 `rst_n` 端口
只有 `clk`。复位靠 `pixel_valid=0` 与行首（`pixel_x==0`）清零。
→ 顶层例化时**不要传 `rst_n`**，否则编译报端口不存在。

### 4.2 ⚠ `morph` 开运算路径的实测延迟依赖输入内容
`V_OPEN_LEN=9` 理论行延迟 16（上游 8 + 下游 8），但全 1 输入下实测 8 行。
根因：`out_v_open = erode_v_d | vtap_ero[*]`——当输入全 1 时 `erode_v_d` 恒 1，
OR 一出来就是 1，**下游行延时未填满就已经输出**。

**影响**：真实人脸块（非全 1）下延迟更接近 16 行，且**逐像素取决于局部内容**。
**处置**：Task 6 端到端对齐时，不要假设开运算路径的固定拍数；
**先让 `break_en_i=0`（只走 3x3 腐蚀，2 行延迟，确定）**，把链路跑通，
再把 `break_en` 打开做对比。计划 Task 2 用 `V_OPEN_LEN=9` 的建议保留，
但延迟补偿以腐蚀路径为准。

### 4.3 ⚠ `morph` 的 `vs_in` 必须接本级自己的 VS（计划未说明，接口缺口）
`morph_erode3x3_stream` 用 `vs_rise` 在**流水线中段**清 `col_cnt3`（`:45`）、
`row_ready3`（`:95`）、`row_ready_v`（`:112`）、`col_cnt_v`（`:155`）。
它不是纯流式模块，**必须拿到一路与自身延迟匹配的 VS**。

同理 `bbox_filter_720p`（`:94`）与 `bbox_overlay`（`:44`）也在用 `vs_rise`。

**方案**：新增模块 `frame_sync_gen.v`，产出一组**逐级延迟的 VS 副本**；
每级用对应的副本，而不是全部接同一根 `lcd_vs`。
`bbox_overlay` 的 `vs_in` 应与其 `de_in` 同相位（即与 `rgb_in` 同拍），
因为它的 `vs_out <= vs_in` 要直接驱动 TMDS。

### 4.4 `streaming_connected_components` 的 `frame_end` 必须是单拍脉冲
计划提示词已提到。本审计确认：内部状态机 `flush_start = frame_end`
在 `ST_RUN` 里只在**上升沿那一拍**触发跳转。接电平会导致状态机反复重入。
→ 顶层用 `lcd_vs` 下降沿打一拍生成。

### 4.5 已修 bugfix：`true_ccl.v` 前向声明
原文件将 20 余个 `wire` 声明写在**使用之后**，Efinity 宽松接受，Vivado 报错
（`VRFC 10-3380` / `VRFC 10-3703`）。本 Task 已修：
- 增加前向声明块（`Start/End/EnEnd/RealNEn/oaRealNEn/CurY/PreY/CurXStart/`
  `CurXEnd/PreXStart/PreXEnd/BottomLineXMax/CurCount/bCount/bXMin/bXMax/`
  `bBottomLineXMax/bYMin/bYMax/iaCount/iaXMin/iaXMax/iaYMin/iaYMax`）
- 17 处 `wire xxx = 表达式;` 改为 `assign xxx = 表达式;`（否则二次声明）

验证：`xvlog ERROR=0`、`xelab ERROR=0`、snapshot 生成成功。

---

## 5. `bbox_overlay` 能否直接吃 Canny 的 24bit 输出？

**可以，直接复用，无需改接口。** 理由：

1. 端口格式匹配：`rgb_in[23:0]` ← `canny_rgb_out[23:0]`（都是 RGB888，R 在最高字节）
2. 时序：`bbox_overlay` 的 `de_out <= de_in`（1 拍），`rgb_out` 与 `de_out` 同拍。
   只要 `de_in/vs_in/hs_in/x_in/y_in` 与 `rgb_in` 同相位即可。
3. **`x_in/y_in` 必须与 `rgb_in` 同拍** —— 计划 Task 6 的接线正确：
   接 `hysteresis_local` 的 `x_o/y_o`（当前在顶层悬空）再多打 1 拍。
4. 该模块内建 bbox 表双缓冲（A/B bank）与 VS 切换，**不需要外部再缓存**。

**唯一注意**：`MAX_BLOBS=16` 而 `bbox_filter_720p` 输出容量 32。
若过滤后 blob 数 >16，`bbox_overlay` 只画前 16 个。对单目标跟踪无影响。

---

## 6. 对计划的接口修正建议

| 计划原文 | 修正 |
|---|---|
| `morph` 例化只给 `vs_in(lpf_vs)` | 应为 `vs_in` 接**延迟后的 VS 副本**（`lpf_vs_d`），见 §4.3 |
| `bbox_filter` / `bbox_overlay` 的 `vs_in` 都接 `lcd_vs` | 应各接同相位副本 |
| Task 2 用 `V_OPEN_LEN=9` | 保留，但先跑 `break_en=0` 腐蚀路径验证链路（§4.2） |
| `frame_sync_gen.v` 只产 `frame_start/frame_end` | 扩充为产 `frame_start`、`frame_end` 及**各级 VS 副本** |
| 未提及 `low_pass_realtime` 无 `rst_n` | 例化时不要传 `rst_n`（§4.1） |

---

## 7. 遗留问题

1. **开运算路径的逐像素延迟不确定**（§4.2）→ Task 6 端到端逐像素标定后回填。
2. **`morph` 的 `vs_in` 精确相位未定** → 需在 Task 6 用「VS 副本级数扫描」实验确定
   哪一级能让 `row_ready` 恰好在帧首正确清零。候选方案见 §4.3。
3. `bbox_filter_720p` 与 `bbox_overlay` 的随机读握手时序未做 TB 级验证
   → Task 3 / Task 5 覆盖。

---

## 8. ★ 环境级阻塞：`efx_map.exe` 无法独立于 GUI 运行（Task 1 期间发现）

### 现象

Task 1 完成 RTL + TB 全绿后，尝试跑 `work_syn/run_efx_map.sh` 做综合资源/时序检查，
**`efx_map.exe` 立即段错误**（exit 139）：

```
INFO     : Efinix FPGA Synthesis.
INFO     : Version: 2025.1.110.5.9
INFO     : Copyright (C) 2013 - 2025 Efinix, Inc. All rights reserved.

ERROR    : EXCEPTION_ACCESS_VIOLATION reading memory at (nil)
ERROR    : ******** STACK TRACE BEGIN ********
ERROR    :       7ff7462c003e: in efx_map.exe + 000000000001003e
...
```

崩溃点 `efx_map.exe+0x1003e` 在**打印版权横幅之后、读取任何源文件之前**。

### 排除项（都实测过）

| 假设 | 实验 | 结果 |
|---|---|---|
| 新模块 `rgb565_to_ycbcr_skin.v` 语法有问题 | 用**原始备份 XML**（不含新模块）跑 | **同样 SEGV** |
| 参数集太长/`--I` 路径错误 | 最小参数集（只留 project/project-xml/root/work-dir） | **同样 SEGV** |
| `efx_map.exe` 二进制损坏 | `efx_map --help` | **正常输出帮助** |
| XML 格式损坏 | Python `ElementTree` 解析 | **解析成功** |
| 目录不可写 | 向 `D:/Efinity`、`~/.efinity` 写测试文件 | **都可写** |
| 按 GUI 原始命令（`RUNMAP_Ti60_Demo`） | 逐字复刻参数（含 `--veri_options` 复数形式 + 相对 `--I=ip/...`） | **同样 SEGV** |

### 根因

`~/.efinity/log/20260921T051013/efxpgm.log` 末行给出直接证据：

```
[2026-09-21 13:49:10] [INFO] Efinity not reachable at port 62844. Exiting...
```

`Efinity` GUI 在运行时会拉起一个 **gRPC 守护进程（端口 62844）**，
`efx_map.exe` 依赖它来解析 IP 核（`BlockRam90x1024` / `FIFO36x512` 等 `efx:ip_info` 条目）。
GUI 一关闭，守护进程消失，`efx_map` 在初始化 IP 解析阶段拿不到句柄 → 空指针崩溃。

旁证：`~/.efinity/log/20260921T051013/` 整个目录里只有 `efxIP_grpc.log` 在持续刷
`GET_LIST_OF_IPS`，即 IP 解析完全走 gRPC；`outflow/` 里 13:10–13:12 那次**成功**的构建，
正是 GUI 开着的时段。

### 影响与对策

- **影响**：在没有 GUI 的纯命令行环境下，**无法**完成综合资源增量与 `clk_pixel` slack 的实测。
  Task 6 的「综合后资源增量/时序」验收项因此无法在本轮交付中给出实测值。
- **对策 A（推荐）**：跑综合前让用户**打开 Efinity GUI** 并加载 `Ti60_Demo.xml`，
  保持 GUI 开着，再执行 `work_syn/run_efx_map.sh`。
- **对策 B**：直接用 GUI 的 GUI-Flow（Synthesis → Place & Route → Bitstream），
  从 GUI 的 Report 面板读取资源与 slack。
- **不要**把此 SEGV 误判为 RTL 编译错误 —— 它发生在解析任何 `.v` 之前。

### 硬约束补充（写给后续会话）

> 本项目所有 `efx_map` / `efx_pnr` / `efx_run` 命令行调用，
> **必须在 Efinity GUI 已启动的前提下执行**，否则会以 SEGV 退出且无任何有用日志。
> 这与约束 6（改 XML 前要关 GUI）**不矛盾**：
> 改 XML → 关 GUI 改 → 开 GUI → 再跑命令行综合。

