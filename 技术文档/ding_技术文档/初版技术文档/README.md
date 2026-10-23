# 技术文档 · 打包说明（发给 ChatGPT 用）

**打包时间**：2026-10-12
**主题**：FPGA（易灵思 Ti60F225）实时图像边缘检测系统 —— 技术文档结构分析、写作指南与改写计划

---

## 一、这个包讲的是什么

三段工作，按时间顺序：

1. **分析四份参考文档** → 提炼竞赛技术文档的官方模板骨架、篇幅配比、图表规范与常见缺陷，产出写作指南与可填写的 DOCX 模板。
2. **对比用户自有文档** → 用户已有一份 26 页《Ti60 实时图像边缘检测系统技术文档》，逐项对比其与写作指南/模板的差距。
3. **基于最新代码制定改写计划** → 从 GitHub 拉取 `10.11 guo Canny_threshold_full_project`（127 个源文件已收入本包），给出逐节改写清单与数值对照表。

---

## 二、目录结构

```
技术文档/
├── README.md                        ← 本文件
├── 外部参考文档清单.md                ← 未复制进包的原始文档（体积大）的路径与说明
├── 01_交付物/                        ← 主要成果
│   ├── 技术文档可视化写作指南.md                        ★ 核心：模板骨架 + 逐章模板 + 自查清单
│   ├── 技术文档模板骨架-边缘检测系统（竞赛四部分+工程深化）.docx   ★ 23 页可填写骨架，61 张表
│   ├── 对比分析-你的文档vs我的建议.md                    ★ 与用户自有文档的逐项对比
│   ├── 改写计划-Ti60文档升级到10.11.md                   ★ 基于最新代码的改写清单
│   ├── 对比-结构对照.png                               两种文档结构的并排对照图
│   ├── fig1-文档结构对比.png / .svg                    四份参考文档结构对比
│   └── fig2-项目流程与文档映射.png / .svg               七阶段流程 → 文档章节映射
├── 02_分析报告/                      ← 中间产物：提取文本与深度分析
│   ├── analysis-农作物.md                              《农作物》结构分析（含 LLM 章节写法模板）
│   ├── analysis-AF1游戏机.md                           《AF1 游戏机》结构分析（含模块七件套）
│   ├── analysis-FPGA赛报告.md                          《四探针测试仪》官方模板还原与图表清单
│   ├── 最终版本农作物.docx.txt 等 3 份 .txt            三份 DOCX 的段落级全文提取
│   ├── *.docx.stats.json / outline.txt                  样式、标题层级、表格图片统计
│   ├── user-report-brief.txt / user-report.stats.json    用户自有 Ti60 文档的提取与统计
│   └── docx-check.json                                 DOCX 模板骨架的结构校验结果
├── 03_项目代码_10.11/                ← GitHub 仓库 10.11 工程源码（127 文件 / 0.9 MB）
│   ├── README.md                                       ★ 该版本变更说明（阈值按键调节）
│   ├── example_top.v                                   顶层
│   ├── rtl\                                            新增：canny_threshold_panel.v、canny_ui_glyph_rom.v、gesture_* 等
│   ├── src\vision\                                     灰度/中值/高斯/Sobel/NMS/双阈值/局部连接
│   ├── src\parallel\                                   parallel_video.v、parallel_overlay.v、uart_params.v、vision_config.vh
│   ├── src\face\  src\axi\  src\uart\                  肤色、连通域、DDR 帧缓存、串口
│   ├── reports\                                        ★ 构建/时序/回归证据（build_verified.json 等）
│   ├── tools\                                          test_threshold.ps1、build_fpga.ps1 等
│   └── firmware\                                       RISC-V 菜单固件
└── 04_对话记录/
    └── 对话记录-完整版.md              ★ 四轮对话全过程（含路径打通过程与全部结论）
```

---

## 三、如果要让 ChatGPT 快速上手，建议按这个顺序喂

1. `04_对话记录/对话记录-完整版.md` —— 先让它知道来龙去脉（含末尾"给 ChatGPT 的上下文摘要"可直接复制）。
2. `01_交付物/技术文档可视化写作指南.md` —— 写作规则与模板。
3. `01_交付物/对比分析-你的文档vs我的建议.md` —— 现状差距。
4. `01_交付物/改写计划-Ti60文档升级到10.11.md` —— 待执行的改写清单。
5. 需要核对代码细节时再查 `03_项目代码_10.11/` 对应文件。

---

## 四、关键数据速查（均可在 `03_项目代码_10.11/reports/` 复核）

| 项目 | 数值 | 来源文件 |
|---|---|---|
| 器件 / 工具链 | Ti60F225 / Efinity 2025.1（构建环境为另一台 CI） | `reports/efinity_build.log` |
| XLR | 36,054 / 60,800 = **59.31%** | `reports/build_verified.json` |
| 存储块 | 248 / 256 = **96.88%**（逼近上限） | 同上 |
| DSP | 37 / 160 = **23.13%** | 同上 |
| 最差 setup / hold | **+0.302 ns / +0.026 ns** | 同上 |
| 位流 SHA256 | `809fd251efe5dcbcd3482d1b6fc2ff8902497e64b18fd6de13ebbab97af723d2` | 同上 |
| 算法融合延迟 | **6619 拍 ≈ 88.97 µs** @ 74.399 MHz（`DELAY=4*(H_TOTAL+1)+14=6618` + 1 拍寄存） | `src/parallel/parallel_video.v` |
| 显示刷新率 | **60.12 Hz**（推算：74.399 MHz ÷ 1650×750） | `src/lcd_para.v` / 文档 |
| 阈值范围 | **1 ≤ 低 < 高 ≤ 4095**，步长 ±8，帧边界提交 | `rtl/canny_threshold_panel.v`、`src/parallel/uart_params.v` |
| 显示模式 | 16 种（0–15），模式 15 = 手势互动 | `src/parallel/parallel_overlay.v`、`parallel_video.v` |
| 工程文件核对 | 144 项检查、0 缺失 | `reports/project_files_verified.json` |
| 实物板验证 | **未进行**（`physical_board_test: not performed`） | 三份报告一致声明 |

---

## 五、说明

- 本包内所有分析结论均可在 `03_项目代码_10.11/` 的源码或报告中找到依据；改写计划中每个数值都标注了证据文件。
- 为让 ChatGPT 可读，三份参考 DOCX 与 PDF 的**文本提取**已放入 `02_分析报告/`；原始文件因体积过大未复制，路径见 `外部参考文档清单.md`。
- 记录中涉及的 hosts 修改：本机原将 27 条 GitHub 域名指向 127.0.0.1，为读取仓库已注释并写入真实 IP，备份文件为 `C:\Windows\System32\drivers\etc\hosts.bak-20261012-204326` 等 6 份。
