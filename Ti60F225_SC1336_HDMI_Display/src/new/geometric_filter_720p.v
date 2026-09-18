// 720p 几何过滤（几何阈值 + 包含/IoU NMS + 面积 Top-K），按帧稳定、支持多目标、严格防越界
// - 上游：SCC 前一帧紧凑表（随机读，1拍流水返回）
// - 本模块：几何阈值(含最小 bbox 面积) -> 包含/IoU NMS -> 面积 Top-K（MAX_OUT_BLOBS）
// - 下游：对外提供“上一帧”稳定表（VS 上才切换银行）
// 说明：所有数组写入均使用“常量上限 for + 等值判断”，避免综合器动态下标越界报错。

module geometric_filter_720p #(
    parameter integer MAX_IN_BLOBS     = 64,    // 上游最大候选
    parameter integer MAX_OUT_BLOBS    = 16,    // 输出最多保留
    // 几何阈值开关：0=旁路（仅NMS+Top-K），1=启用几何阈值
    parameter integer FILTER_ENABLE    = 1,
    // 几何阈值
    parameter integer MIN_W            = 40,
    parameter integer MAX_W            = 360,
    parameter integer MIN_H            = 40,
    parameter integer MAX_H            = 360,
    parameter integer MIN_AREA_BBOX    = 1200,  // 新增：最小 bbox 面积阈值（强力抑制小碎框）
    parameter integer MIN_AR_X10       = 8,     // 0.8
    parameter integer MAX_AR_X10       = 15,    // 1.5
    parameter integer IOU_THR_X100     = 30,    // IoU 阈值×100 (0.30)
    parameter integer WIDTH            = 1280,
    parameter integer HEIGHT           = 720
)(
    input              clk,
    input              rst_n,
    input              vs_in,

    // upstream CCL list
    input      [5:0]   in_blob_count,
    output reg [5:0]   in_addr_out,    // 1..in_blob_count
    input      [10:0]  in_min_x,
    input      [10:0]  in_max_x,
    input      [9:0]   in_min_y,
    input      [9:0]   in_max_y,
    input              in_bbox_valid,

    // downstream filtered list
    output reg [5:0]   blob_count,
    input      [5:0]   raddr,          // 1..blob_count
    output reg [10:0]  bbox_min_x,
    output reg [10:0]  bbox_max_x,
    output reg [9:0]   bbox_min_y,
    output reg [9:0]   bbox_max_y,
    output reg         bbox_valid,

    // debug
    output reg [5:0]   dbg_keep_n
);
    // 常量边界
    localparam [5:0] MAX_IN6     = (MAX_IN_BLOBS  > 63) ? 6'd63 : MAX_IN_BLOBS[5:0];
    localparam [5:0] OUT_MAX_IDX = (MAX_OUT_BLOBS > 0)  ? (MAX_OUT_BLOBS[5:0] - 6'd1) : 6'd0;

    // VS 上升沿
    reg vs_q; wire vs_rise = vs_in & ~vs_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vs_q <= 1'b0; else vs_q <= vs_in;
    end

    // 双缓冲（严格 0..MAX_OUT_BLOBS-1）
    reg [10:0] a_x0 [0:MAX_OUT_BLOBS-1], a_x1 [0:MAX_OUT_BLOBS-1];
    reg [9:0]  a_y0 [0:MAX_OUT_BLOBS-1], a_y1 [0:MAX_OUT_BLOBS-1];
    reg [5:0]  a_n;

    reg [10:0] b_x0 [0:MAX_OUT_BLOBS-1], b_x1 [0:MAX_OUT_BLOBS-1];
    reg [9:0]  b_y0 [0:MAX_OUT_BLOBS-1], b_y1 [0:MAX_OUT_BLOBS-1];
    reg [5:0]  b_n;

    reg        draw_sel;   // 0 draw A, 1 draw B
    reg        fill_sel;   // 0 fill A, 1 fill B

    // 抓取控制：严格 1 拍流水
    reg        fetching, pending_swap;
    reg [5:0]  to_read_n, rd_idx, last_req, latched_cnt;

    // 当前帧保留集合（写 fill bank）
    reg [5:0]  keep_n;                   // 本帧保留数（最多等于 MAX_OUT_BLOBS）
    reg [21:0] keep_area [0:MAX_OUT_BLOBS-1];

    // 切换/清空
    reg        next_draw_sel, next_fill_sel, clear_sel;

    // 计算变量
    integer i, j, mi;
    integer idx_min;
    reg [10:0] w; reg [9:0] h;
    reg [21:0] area_bbox, amin;
    reg [15:0] ar_x10;
    reg        pass;

    // NMS 比较用
    reg [10:0] ex_x0, ex_x1; reg [9:0] ex_y0, ex_y1;
    reg        drop_cand; integer rep_idx; reg [5:0] rep_idx6;
    reg [10:0] ix0, ix1; reg [9:0] iy0, iy1; reg [10:0] ovw; reg [9:0] ovh;
    reg [21:0] inter_area, ex_area; reg [23:0] union_area; reg [31:0] iou_x100;

    // 追加写槽位（仅在 keep_n<MAX_OUT_BLOBS 时使用）
    reg [5:0]  idx_write6;

    // 主过程
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            draw_sel<=1'b0; fill_sel<=1'b1; pending_swap<=1'b0;
            a_n<=0; b_n<=0; keep_n<=0; dbg_keep_n<=0;
            to_read_n<=0; rd_idx<=0; last_req<=0; latched_cnt<=0; fetching<=1'b0;
            in_addr_out<=6'd1;
            blob_count<=0; bbox_min_x<=0; bbox_max_x<=0; bbox_min_y<=0; bbox_max_y<=0; bbox_valid<=1'b0;
            for (i=0;i<MAX_OUT_BLOBS;i=i+1) begin
                a_x0[i]<=0; a_x1[i]<=0; a_y0[i]<=0; a_y1[i]<=0; keep_area[i]<=0;
                b_x0[i]<=0; b_x1[i]<=0; b_y0[i]<=0; b_y1[i]<=0;
            end
        end else begin
            in_addr_out <= 6'd1;

            // VS：切换与清零
            if (vs_rise) begin
                next_draw_sel = draw_sel;
                next_fill_sel = fill_sel;
                clear_sel     = fill_sel;
                if (pending_swap) begin
                    next_draw_sel = fill_sel;
                    next_fill_sel = ~fill_sel;
                    clear_sel     = next_fill_sel;
                end
                draw_sel     <= next_draw_sel;
                fill_sel     <= next_fill_sel;
                pending_swap <= 1'b0;

                // 开启本帧抓取
                to_read_n   <= (in_blob_count > MAX_IN6) ? MAX_IN6 : in_blob_count;
                rd_idx      <= 6'd1;
                last_req    <= 6'd0;
                latched_cnt <= 6'd0;
                fetching    <= (in_blob_count != 0);
                keep_n      <= 6'd0;
                dbg_keep_n  <= 6'd0;

                // 清“下一帧要填充”的计数
                if (clear_sel==1'b0) a_n <= 6'd0; else b_n <= 6'd0;
            end

            if (fetching) begin
                // 锁存上一请求返回
                if (in_bbox_valid && (last_req>=6'd1) && (last_req<=to_read_n)) begin
                    // bbox 几何量
                    w = (in_max_x >= in_min_x) ? (in_max_x - in_min_x + 11'd1) : 11'd0;
                    h = (in_max_y >= in_min_y) ? (in_max_y - in_min_y + 10'd1) : 10'd0;
                    area_bbox = w * h;
                    if (w!=0 && h!=0) begin
                        if (w >= h) ar_x10 = (w * 16'd10) / h;
                        else        ar_x10 = (h * 16'd10) / w;
                    end else begin
                        ar_x10 = 16'd0;
                    end

                    // 几何阈值（强力抑制小碎框 + 合理形状）
                    pass = (FILTER_ENABLE==0) ? 1'b1 :
                           ((w >= MIN_W[10:0]) && (w <= MAX_W[10:0]) &&
                            (h >= MIN_H[9:0])  && (h <= MAX_H[9:0])  &&
                            (area_bbox >= MIN_AREA_BBOX[21:0])       &&
                            (ar_x10 >= MIN_AR_X10[15:0]) && (ar_x10 <= MAX_AR_X10[15:0]) &&
                            // 贴边也视为可疑（可按需关闭）
                            (in_min_x > 11'd3) && (in_min_y > 10'd3) &&
                            (in_max_x + 11'd1 < (WIDTH  - 11'd3)) &&
                            (in_max_y + 10'd1 < (HEIGHT - 10'd3)));

                    if (pass) begin
                        // NMS（包含 + IoU）与当前已保留集合比较
                        drop_cand = 1'b0; rep_idx = -1;
                        for (j=0; j<MAX_OUT_BLOBS; j=j+1) begin
                            if (j < keep_n) begin
                                if (fill_sel==1'b0) begin
                                    ex_x0 = a_x0[j]; ex_x1 = a_x1[j]; ex_y0 = a_y0[j]; ex_y1 = a_y1[j];
                                end else begin
                                    ex_x0 = b_x0[j]; ex_x1 = b_x1[j]; ex_y0 = b_y0[j]; ex_y1 = b_y1[j];
                                end
                                ex_area = (ex_x1 - ex_x0 + 11'd1) * (ex_y1 - ex_y0 + 10'd1);

                                // 包含：cand 被 ex 包含 -> 丢弃；ex 被 cand 包含 -> 替换 ex
                                if ((in_min_x >= ex_x0) && (in_max_x <= ex_x1) &&
                                    (in_min_y >= ex_y0) && (in_max_y <= ex_y1)) begin
                                    drop_cand = 1'b1;
                                end
                                if ((ex_x0 >= in_min_x) && (ex_x1 <= in_max_x) &&
                                    (ex_y0 >= in_min_y) && (ex_y1 <= in_max_y)) begin
                                    if (rep_idx < 0) rep_idx = j;
                                end

                                // IoU 抑制（取面积大者）
                                ix0 = (in_min_x >= ex_x0) ? in_min_x : ex_x0;
                                iy0 = (in_min_y >= ex_y0) ? in_min_y : ex_y0;
                                ix1 = (in_max_x <= ex_x1) ? in_max_x : ex_x1;
                                iy1 = (in_max_y <= ex_y1) ? in_max_y : ex_y1;
                                if ((ix1 >= ix0) && (iy1 >= iy0)) begin
                                    ovw = ix1 - ix0 + 11'd1; ovh = iy1 - iy0 + 10'd1;
                                    inter_area = ovw * ovh;
                                end else begin
                                    inter_area = 22'd0;
                                end
                                union_area = area_bbox + ex_area - inter_area;
                                if (union_area != 0) begin
                                    iou_x100 = (inter_area * 32'd100) / union_area;
                                    if (iou_x100 >= IOU_THR_X100[31:0]) begin
                                        if (area_bbox > ex_area) begin
                                            if (rep_idx < 0) rep_idx = j; // cand 胜，替换 ex
                                        end else begin
                                            drop_cand = 1'b1;             // ex 胜，丢 cand
                                        end
                                    end
                                end
                            end
                        end

                        rep_idx6 = (rep_idx < 0) ? 6'h3F : rep_idx[5:0];

                        if (!drop_cand) begin
                            if (rep_idx >= 0) begin
                                // 替换 ex（常量上限 for 写入）
                                for (mi=0; mi<MAX_OUT_BLOBS; mi=mi+1) begin
                                    if (mi[5:0] == rep_idx6) begin
                                        if (fill_sel==1'b0) begin
                                            a_x0[mi] <= in_min_x; a_x1[mi] <= in_max_x;
                                            a_y0[mi] <= in_min_y; a_y1[mi] <= in_max_y;
                                        end else begin
                                            b_x0[mi] <= in_min_x; b_x1[mi] <= in_max_x;
                                            b_y0[mi] <= in_min_y; b_y1[mi] <= in_max_y;
                                        end
                                        keep_area[mi] <= area_bbox;
                                    end
                                end
                            end else if (keep_n < MAX_OUT_BLOBS[5:0]) begin
                                // 追加
                                idx_write6 = keep_n;
                                for (mi=0; mi<MAX_OUT_BLOBS; mi=mi+1) begin
                                    if (mi[5:0] == idx_write6) begin
                                        if (fill_sel==1'b0) begin
                                            a_x0[mi] <= in_min_x; a_x1[mi] <= in_max_x;
                                            a_y0[mi] <= in_min_y; a_y1[mi] <= in_max_y;
                                        end else begin
                                            b_x0[mi] <= in_min_x; b_x1[mi] <= in_max_x;
                                            b_y0[mi] <= in_min_y; b_y1[mi] <= in_max_y;
                                        end
                                        keep_area[mi] <= area_bbox;
                                    end
                                end
                                keep_n     <= keep_n + 6'd1;
                                dbg_keep_n <= keep_n + 6'd1;
                            end else begin
                                // Top-K：替换面积最小
                                amin = keep_area[0]; idx_min = 0;
                                for (j=1; j<MAX_OUT_BLOBS; j=j+1) begin
                                    if (keep_area[j] < amin) begin
                                        amin    = keep_area[j];
                                        idx_min = j;
                                    end
                                end
                                if (area_bbox > amin) begin
                                    for (mi=0; mi<MAX_OUT_BLOBS; mi=mi+1) begin
                                        if (mi == idx_min) begin
                                            if (fill_sel==1'b0) begin
                                                a_x0[mi] <= in_min_x; a_x1[mi] <= in_max_x;
                                                a_y0[mi] <= in_min_y; a_y1[mi] <= in_max_y;
                                            end else begin
                                                b_x0[mi] <= in_min_x; b_x1[mi] <= in_max_x;
                                                b_y0[mi] <= in_min_y; b_y1[mi] <= in_max_y;
                                            end
                                            keep_area[mi] <= area_bbox;
                                        end
                                    end
                                end
                            end
                        end
                    end

                    latched_cnt <= latched_cnt + 6'd1;
                end

                // 下一个地址
                if (rd_idx <= to_read_n) begin
                    last_req   <= rd_idx;
                    in_addr_out<= rd_idx;
                    rd_idx     <= rd_idx + 6'd1;
                end

                // 抓取完成：等待下次 VS 切换显示
                if (latched_cnt == to_read_n) begin
                    fetching     <= 1'b0;
                    pending_swap <= 1'b1;
                    if (fill_sel==1'b0) a_n <= keep_n; else b_n <= keep_n;
                end
            end

            // 下游随机读：整帧稳定
            blob_count <= (draw_sel==1'b0) ? a_n : b_n;
            if ((raddr>=6'd1) && (raddr<=blob_count) && (raddr-6'd1 <= OUT_MAX_IDX)) begin
                if (draw_sel==1'b0) begin
                    bbox_min_x <= a_x0[raddr-1]; bbox_max_x <= a_x1[raddr-1];
                    bbox_min_y <= a_y0[raddr-1]; bbox_max_y <= a_y1[raddr-1];
                end else begin
                    bbox_min_x <= b_x0[raddr-1]; bbox_max_x <= b_x1[raddr-1];
                    bbox_min_y <= b_y0[raddr-1]; bbox_max_y <= b_y1[raddr-1];
                end
                bbox_valid <= 1'b1;
            end else begin
                bbox_min_x <= 0; bbox_max_x <= 0; bbox_min_y <= 0; bbox_max_y <= 0;
                bbox_valid <= 1'b0;
            end
        end
    end
endmodule