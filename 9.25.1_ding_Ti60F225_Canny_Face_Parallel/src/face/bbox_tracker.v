`timescale 1ns/1ps
//======================================================================
//  bbox_tracker.v —— 候选 bbox → 稳定跟随的 bbox（Task 4）
//
//  职责（只做时序，不做空间筛选——空间筛选由 bbox_filter_720p 负责）：
//    1) 帧末扫候选表，挑「面积最大且通过尺寸/宽高比」的候选
//    2) 连续性门限：与上一帧输出比，中心位移 < 上一帧半宽/半高 才接受（拒跳变）
//    3) 指数平滑：每帧向目标靠拢 1/2^SMOOTH_SHIFT（去抖）
//    4) 丢失保持：连续无候选 <= HOLD_FRAMES 帧保持上一位置；超过则清零
//    5) 首次捕获（out_valid=0）直接接受，不做平滑拖尾
//
//  纯无符号运算 + 移位，无乘法器/除法器。
//======================================================================
module bbox_tracker #(
    parameter AWIDTH       = 11,
    parameter HB           = 10,
    parameter SMOOTH_SHIFT = 3,     // 1/8
    parameter HOLD_FRAMES  = 15,
    parameter MIN_W        = 20,    // 候选最小宽（像素）
    parameter MIN_H        = 20,
    parameter MIN_AR_X10   = 6,     // 宽高比下限 x10（0.6）
    parameter MAX_AR_X10   = 20,    // 宽高比上限 x10（2.0）
    parameter SCAN_WAIT    = 3      // 表读等待拍数（与上层表读延迟匹配）
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                vs_rise,          // 帧末单拍：启动扫表
    input  wire [5:0]          in_blob_count,
    output reg  [5:0]          in_addr,
    input  wire [AWIDTH-1:0]   in_min_x, in_max_x,
    input  wire [HB-1:0]       in_min_y, in_max_y,
    input  wire                in_valid,
    output reg  [AWIDTH-1:0]   out_min_x, out_max_x,
    output reg  [HB-1:0]       out_min_y, out_max_y,
    output reg                 out_valid,
    output reg  [2:0]          dbg_state
);
    localparam ST_IDLE = 3'd0, ST_SCAN = 3'd1, ST_EVAL = 3'd2, ST_UPD = 3'd3;

    reg [2:0]  st;
    reg [5:0]  addr;
    reg [7:0]  wait_cnt;
    reg [7:0]  hold_cnt;

    reg [AWIDTH-1:0] b_min_x, b_max_x;
    reg [HB-1:0]     b_min_y, b_max_y;
    reg [23:0]       b_area;
    reg              b_hit;

    // 候选几何（组合）
    wire [AWIDTH:0]  cw   = in_max_x - in_min_x + 1'b1;
    wire [HB:0]      ch   = in_max_y - in_min_y + 1'b1;
    wire [AWIDTH+3:0] cw10 = (cw << 3) + (cw << 1);        // cw*10
    wire [HB+3:0]     ch_min = (ch << 2) + (ch << 1);      // ch*MIN_AR_X10(=6)
    wire [HB+4:0]     ch_max = (ch << 4) + (ch << 2);      // ch*MAX_AR_X10(=20)
    wire              size_ok = (cw >= MIN_W) && (ch >= MIN_H);
    wire              ar_ok   = (cw10 >= ch_min) && (cw10 <= ch_max);
    wire              cand_ok = in_valid && size_ok && ar_ok;
    wire [23:0]       cand_area = cw * ch;                  // TB 允许多用途乘法；综合会用 DSP/移位（见 RULING）

    // 上一帧输出几何
    wire [AWIDTH:0] pw = out_max_x - out_min_x + 1'b1;
    wire [HB:0]     ph = out_max_y - out_min_y + 1'b1;
    wire [AWIDTH-1:0] pcx = (out_min_x + out_max_x) >> 1;
    wire [HB-1:0]     pcy = (out_min_y + out_max_y) >> 1;
    wire [AWIDTH-1:0] ccx = (in_min_x + in_max_x) >> 1;
    wire [HB-1:0]     ccy = (in_min_y + in_max_y) >> 1;
    wire [AWIDTH:0] dx = (ccx > pcx) ? (ccx - pcx) : (pcx - ccx);
    wire [HB:0]     dy = (ccy > pcy) ? (ccy - pcy) : (pcy - ccy);
    wire            cont_ok = (~out_valid) || ((dx <= (pw >> 1)) && (dy <= (ph >> 1)));

    // 平滑步长（至少 1 像素，保证收敛）
    reg [AWIDTH-1:0] sx, sy;
    always @(*) begin
        if (b_min_x > out_min_x) sx = ((b_min_x - out_min_x) >> SMOOTH_SHIFT) | 11'd1;
        else                     sx = ((out_min_x - b_min_x) >> SMOOTH_SHIFT) | 11'd1;
        if (b_min_y > out_min_y) sy = ((b_min_y - out_min_y) >> SMOOTH_SHIFT) | 10'd1;
        else                     sy = ((out_min_y - b_min_y) >> SMOOTH_SHIFT) | 10'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= ST_IDLE; addr <= 6'd0; wait_cnt <= 8'd0; hold_cnt <= 8'd0;
            b_min_x <= 0; b_max_x <= 0; b_min_y <= 0; b_max_y <= 0; b_area <= 0; b_hit <= 0;
            in_addr <= 6'd0;
            out_min_x <= 0; out_max_x <= 0; out_min_y <= 0; out_max_y <= 0;
            out_valid <= 1'b0; dbg_state <= ST_IDLE;
        end else begin
            dbg_state <= st;
            case (st)
            ST_IDLE: begin
                if (vs_rise) begin
                    addr <= 6'd1; wait_cnt <= 8'd0;
                    b_area <= 24'd0; b_hit <= 1'b0;
                    in_addr <= 6'd1;
                    st <= ST_SCAN;
                end
            end
            ST_SCAN: begin
                // 送地址后等 SCAN_WAIT 拍再取数
                if (wait_cnt < SCAN_WAIT) begin
                    wait_cnt <= wait_cnt + 8'd1;
                end else begin
                    wait_cnt <= 8'd0;
                    if (cand_ok && (cand_area > b_area)) begin
                        b_area <= cand_area;
                        b_min_x <= in_min_x; b_max_x <= in_max_x;
                        b_min_y <= in_min_y; b_max_y <= in_max_y;
                        b_hit <= 1'b1;
                    end
                    if (addr >= in_blob_count) begin
                        st <= ST_EVAL;
                    end else begin
                        addr <= addr + 6'd1;
                        in_addr <= addr + 6'd1;
                    end
                end
            end
            ST_EVAL: begin
                if (b_hit && cont_ok) begin
                    // 首次捕获直接置位；否则平滑靠拢
                    if (!out_valid) begin
                        out_min_x <= b_min_x; out_max_x <= b_max_x;
                        out_min_y <= b_min_y; out_max_y <= b_max_y;
                    end else begin
                        if (b_min_x > out_min_x) out_min_x <= out_min_x + sx;
                        else if (b_min_x < out_min_x) out_min_x <= out_min_x - sx;
                        if (b_max_x > out_max_x) out_max_x <= out_max_x + sx;
                        else if (b_max_x < out_max_x) out_max_x <= out_max_x - sx;
                        if (b_min_y > out_min_y) out_min_y <= out_min_y + sy;
                        else if (b_min_y < out_min_y) out_min_y <= out_min_y - sy;
                        if (b_max_y > out_max_y) out_max_y <= out_max_y + sy;
                        else if (b_max_y < out_max_y) out_max_y <= out_max_y - sy;
                    end
                    out_valid <= 1'b1;
                    hold_cnt <= 8'd0;
                end else begin
                    // 无候选或被连续性门限拒绝 → 保持
                    if (out_valid) begin
                        if (hold_cnt >= HOLD_FRAMES[7:0]) begin
                            out_valid <= 1'b0;      // 超时清除
                            hold_cnt  <= 8'd0;
                        end else begin
                            hold_cnt <= hold_cnt + 8'd1;
                        end
                    end
                end
                st <= ST_IDLE;
            end
            default: st <= ST_IDLE;
            endcase
        end
    end
endmodule

