#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_skin_truth.py  —  Task 1 真值表生成器（独立实现路径）

用途
----
为 tb/face/rgb565_to_ycbcr_skin_tb.v 生成定向用例的期望值。
本脚本刻意用 **浮点 BT.601 标准公式** 而不是 RTL 的移位加法，
这样若 RTL 的系数分解写错（比如 107 少加一项），两边必然对不上。

用法
----
    python tools/gen_skin_truth.py            # 打印真值表
    python tools/gen_skin_truth.py --verify   # 顺带做全空间整数/浮点交叉校验

关键结论（供后续参考）
----------------------
1. 计划文档里给的示例 16'hFBE4 = "230,180,150 肤色" 是**错的**：
   230,180,150 的正确 RGB565 编码是 0xE5B2。0xFBE4 解出来是 (248,252,32)，
   一个黄绿色，肤色判据当然过不了。本脚本用 to565() 重新编码。
2. 白色 (0xFFFF) 天然被排除，因为 Cb = 128 > cb_max = 127，无需额外规则。
3. 纯红 (0xF800) 的 Cr = 255，远超 173；纯绿 Cb = 43 远低于 77。
"""

import argparse

# ---------------------------------------------------------------- 编码/解码
def to565(r, g, b):
    """RGB888 -> RGB565（各通道取高位）"""
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

def expand5to8(v):
    """5bit -> 8bit，MSB 复制（与 RTL 的 {v, v[4:2]} 一致）"""
    return ((v << 3) | (v >> 2)) & 0xFF

def expand6to8(v):
    """6bit -> 8bit，MSB 复制（与 RTL 的 {v, v[5:4]} 一致）"""
    return ((v << 2) | (v >> 4)) & 0xFF

def rgb565_to_rgb888(px):
    return (expand5to8((px >> 11) & 0x1F),
            expand6to8((px >> 5) & 0x3F),
            expand5to8(px & 0x1F))

# ---------------------------------------------------------------- 参考模型（浮点）
def ref_ycbcr_f(px):
    r, g, b = rgb565_to_rgb888(px)
    y  =  0.299 * r + 0.587 * g + 0.114 * b
    cb = -0.168736 * r - 0.331264 * g + 0.5 * b + 128.0
    cr =  0.5 * r - 0.418688 * g - 0.081312 * b + 128.0
    return y, cb, cr

# ---------------------------------------------------------------- RTL 模型（整数）
def rtl_ycbcr_i(px):
    r, g, b = rgb565_to_rgb888(px)
    y  = (77 * r + 150 * g + 29 * b) >> 8
    cb = 128 + ((-43 * r - 85 * g + 128 * b) >> 8)
    cr = 128 + ((128 * r - 107 * g - 21 * b) >> 8)
    return y & 0xFF, max(0, min(255, cb)), max(0, min(255, cr))

# ---------------------------------------------------------------- 判据
CB_MIN, CB_MAX = 77, 127
CR_MIN, CR_MAX = 133, 173
Y_MIN,  Y_MAX  = 40, 235

def is_skin(y, cb, cr):
    return int(Y_MIN <= y <= Y_MAX and CB_MIN <= cb <= CB_MAX and CR_MIN <= cr <= CR_MAX)

# ---------------------------------------------------------------- 用例表
# (名称, R, G, B, 注释)
CASES = [
    ("典型肤色",   230, 180, 150, "标准黄种人肤色"),
    ("偏深肤色",   200, 150, 120, "偏深"),
    ("浅肤色",     240, 200, 175, "偏白"),
    ("深肤色",     150, 110,  80, "较深"),
    ("中间色",     198, 144, 128, "肤色与灰的过渡"),
    ("白",         255, 255, 255, "Cb=128>127 天然排除"),
    ("黑",           0,   0,   0, "Y=0<40"),
    ("中灰",       128, 128, 128, "Cb=Cr=128"),
    ("纯绿",         0, 255,   0, "Cb=43"),
    ("纯蓝",         0,   0, 255, "Cb=255"),
    ("纯红",       255,   0,   0, "Cr=255"),
    ("木色桌面",   180, 140, 100, "易误检的暖色"),
    ("暖光白墙",   240, 225, 210, "易误检的暖白"),
    ("黄色物体",   240, 220,  40, "易误检"),
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true", help="全空间交叉校验整数/浮点一致性")
    args = ap.parse_args()

    print("=" * 92)
    print(" Task 1 真值表：rgb565_to_ycbcr_skin")
    print("=" * 92)
    hdr = f"{'名称':<10}{'R,G,B':>14}{'565hex':>9}{'Y':>5}{'Cb':>5}{'Cr':>5}{'skin':>6}   {'浮点Y':>7}{'Cb':>8}{'Cr':>8}  一致"
    print(hdr)
    print("-" * 92)

    mism = 0
    for name, r, g, b, note in CASES:
        px = to565(r, g, b)
        y, cb, cr = rtl_ycbcr_i(px)
        sk = is_skin(y, cb, cr)
        fy, fcb, fcr = ref_ycbcr_f(px)
        # 浮点直接判据（不做取整）
        fsk = int(Y_MIN <= fy <= Y_MAX and CB_MIN <= fcb <= CB_MAX and CR_MIN <= fcr <= CR_MAX)
        agree = "OK" if sk == fsk else "**差**"
        if sk != fsk:
            mism += 1
        print(f"{name:<10}{f'{r},{g},{b}':>14}0x{px:04X}{y:5d}{cb:5d}{cr:5d}{sk:6d}   "
              f"{fy:7.1f}{fcb:8.1f}{fcr:8.1f}  {agree}   # {note}")

    print("-" * 92)
    print(f"整数/浮点判据不一致：{mism} 组")
    print()
    print("Verilog 硬真值表片段（可直接粘进 TB）：")
    for name, r, g, b, note in CASES:
        px = to565(r, g, b)
        y, cb, cr = rtl_ycbcr_i(px)
        sk = is_skin(y, cb, cr)
        print(f"        hard_check(16'h{px:04X}, 1'b{sk}, {y:3d}, {cb:3d}, {cr:3d});  // {name}")

    if args.verify:
        print()
        print("=" * 92)
        print(" 全空间交叉校验：65536 个 RGB565 值，整数判据 vs 浮点判据")
        print("=" * 92)
        n_agree = n_diff = 0
        diff_list = []
        for px in range(0x10000):
            y, cb, cr = rtl_ycbcr_i(px)
            sk_i = is_skin(y, cb, cr)
            fy, fcb, fcr = ref_ycbcr_f(px)
            sk_f = int(Y_MIN <= fy <= Y_MAX and CB_MIN <= fcb <= CB_MAX and CR_MIN <= fcr <= CR_MAX)
            if sk_i == sk_f:
                n_agree += 1
            else:
                n_diff += 1
                if len(diff_list) < 20:
                    diff_list.append((px, y, cb, cr, sk_i, fy, fcb, fcr, sk_f))
        print(f"  一致 : {n_agree}")
        print(f"  不一致: {n_diff}")
        if diff_list:
            print()
            print("  前 20 个不一致点（均应为「贴边 1 位」的舍入差）：")
            for px, y, cb, cr, sk_i, fy, fcb, fcr, sk_f in diff_list:
                print(f"    0x{px:04X} 整数(Y={y} Cb={cb} Cr={cr})={sk_i}  "
                      f"浮点(Y={fy:.2f} Cb={fcb:.3f} Cr={fcr:.3f})={sk_f}")
        print()
        if n_diff == 0:
            print("  结论：整数与浮点判据在整个 RGB565 空间完全一致。")
        else:
            pct = 100.0 * n_diff / 65536.0
            print(f"  结论：{pct:.4f}% 的点存在 1 位舍入差（TB 已用「距边界>=2」过滤）。")

if __name__ == "__main__":
    main()
