`timescale 1ns/1ps
// 自适应 bbox 过滤：尺寸/紧凑度/轴比/（可选）填充率，贴边/大框放宽；容量提升到 32。
// 关键点：紧凑度使用 area_pix（真实像素面积）；大框分支也启用较低填充率阈值。
module bbox_filter_720p #(
    parameter integer WIDTH            = 1280,
    parameter integer HEIGHT           = 720,
    parameter integer MAX_IN_BLOBS     = 64,
    parameter integer MAX_OUT_BLOBS    = 32,

    // 尺寸保护（0=不上限）
    parameter integer MIN_W            = 50,
    parameter integer MAX_W            = 800,
    parameter integer MIN_H            = 50,
    parameter integer MAX_H            =  0,

    // 紧凑度(×10) + 像素面积下限（紧凑度用 area_pix）
    parameter integer MIN_COMPACTNESS  = 1,     // 建议：4~5
    parameter integer MIN_AREA_PIX     = 1200,  // 建议：1200~2000

    // 轴比 (×10)
    parameter integer MIN_RATIO_X10    = 8,     // 0.9
    parameter integer MAX_RATIO_X10    = 17,    // 1.4

    // 填充率 (×100) 0=禁用
    parameter integer EXTENT_MIN_X100  = 40,    // 建议：40~45
    parameter integer EXTENT_MAX_X100  = 90,

    // 面积输入位宽
    parameter integer AREA_W           = 22,

    // 大框/贴边自适应
    parameter integer LARGE_W_THR            = 200,
    parameter integer LARGE_H_THR            = 200,
    parameter integer LARGE_AREA_BBOX_THR    = 25000,
    parameter integer MIN_COMPACTNESS_LARGE  = 1,   // 0.3
    parameter integer MIN_RATIO_X10_LARGE    = 8,   // 0.8
    parameter integer MAX_RATIO_X10_LARGE    = 18,  // 1.8
    parameter integer EXTENT_MIN_X100_LARGE  = 45,  // 给个底线

    // 贴边保留（仍然需要一定像素面积）
    parameter integer EDGE_KEEP_EN           = 1,
    parameter integer EDGE_MIN_AREA_PIX      = 1800,

    parameter integer LOWER_REGION_THRESHOLD = 600, // 屏幕下方区域起始Y坐标
    
// 新增：横向框宽高比约束参数（宽/高）
   parameter integer MAX_WIDTH_HEIGHT_RATIO_X10 = 13, // 宽高比上限×10 (例如20表示2.0)

    parameter integer BYPASS                 = 0
)(
    input              clk,
    input              rst_n,
    input              vs_in,

    // upstream (上一帧紧凑表)
    input      [5:0]   in_blob_count,
    output reg [5:0]   in_addr_out,
    input      [10:0]  in_bbox_min_x,
    input      [10:0]  in_bbox_max_x,
    input      [9:0]   in_bbox_min_y,
    input      [9:0]   in_bbox_max_y,
    input      [AREA_W-1:0] in_area_pix,
    input              in_bbox_valid,

    // downstream（上一帧过滤后表）
    output reg [5:0]   blob_count,
    input      [5:0]   addr_in,
    output reg [10:0]  bbox_min_x,
    output reg [10:0]  bbox_max_x,
    output reg [9:0]   bbox_min_y,
    output reg [9:0]   bbox_max_y,
    output reg         bbox_valid,
    output             fetching_active
);

generate
if (BYPASS != 0) begin : GEN_BYPASS
    always @(*) begin
        in_addr_out = addr_in;
        blob_count  = in_blob_count;
    end
    assign fetching_active = 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bbox_min_x<=0; bbox_max_x<=0; bbox_min_y<=0; bbox_max_y<=0; bbox_valid<=1'b0;
        end else begin
            bbox_min_x<=in_bbox_min_x; bbox_max_x<=in_bbox_max_x;
            bbox_min_y<=in_bbox_min_y; bbox_max_y<=in_bbox_max_y;
            bbox_valid<=in_bbox_valid;
        end
    end
end else begin : GEN_FILTER
    // VS rising
    reg vs_q; wire vs_rise = vs_in & ~vs_q;
    always @(posedge clk or negedge rst_n) begin if(!rst_n) vs_q<=1'b0; else vs_q<=vs_in; end

    // 双缓冲（A/B）
    reg [10:0] a_x0 [0:MAX_OUT_BLOBS-1], a_x1 [0:MAX_OUT_BLOBS-1];
    reg [9:0]  a_y0 [0:MAX_OUT_BLOBS-1], a_y1 [0:MAX_OUT_BLOBS-1];
    reg [31:0] a_score [0:MAX_OUT_BLOBS-1];
    reg [5:0]  a_n;

    reg [10:0] b_x0 [0:MAX_OUT_BLOBS-1], b_x1 [0:MAX_OUT_BLOBS-1];
    reg [9:0]  b_y0 [0:MAX_OUT_BLOBS-1], b_y1 [0:MAX_OUT_BLOBS-1];
    reg [31:0] b_score [0:MAX_OUT_BLOBS-1];
    reg [5:0]  b_n;

    reg draw_sel, fill_sel, pending_swap;

    // FSM
    localparam S_IDLE=2'd0, S_REQ=2'd1, S_LATCH=2'd2, S_DONE=2'd3;
    reg [1:0] state;
    reg [5:0] to_read_n, idx, kept_cnt;
    reg       arm_fetch;
    reg [1:0] wait_ctr;

    localparam integer MAX_IN_CAP_INT  = (MAX_IN_BLOBS  < 64) ? MAX_IN_BLOBS  : 63;
    localparam integer MAX_OUT_CAP_INT = (MAX_OUT_BLOBS < 64) ? MAX_OUT_BLOBS : 63;

    assign fetching_active = (state != S_IDLE);

    // 帧稳定输出计数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) blob_count <= 6'd0;
        else        blob_count <= (draw_sel==1'b0) ? a_n : b_n;
    end

    // 中间量
    reg [15:0] w_t, h_t, long_t, short_t, per_t;
    reg [31:0] area_bbox_t, per_sq_t, lhs_t, rhs_t, long10_t, short_min_t, short_max_t;
    reg [31:0] ext_lhs, ext_rhs_min, ext_rhs_max;
    reg [AREA_W-1:0] area_pix_t;

    reg pass_size_t, pass_area_pix_t, pass_compact_t, pass_ar_t, pass_position_t, pass_extent_t,pass_width_height_ratio_t;
    reg keep_this;
    reg [31:0] score_t;
    reg [5:0]  mini;

    integer i;

    // 小工具：写入槽位
    task write_slot(
        input sel, input [5:0] pos,
        input [10:0] x0, input [10:0] x1, input [9:0] y0, input [9:0] y1,
        input [31:0] score
    );
    begin
        if (sel==1'b0) begin
            a_x0[pos]<=x0; a_x1[pos]<=x1; a_y0[pos]<=y0; a_y1[pos]<=y1; a_score[pos]<=score;
        end else begin
            b_x0[pos]<=x0; b_x1[pos]<=x1; b_y0[pos]<=y0; b_y1[pos]<=y1; b_score[pos]<=score;
        end
    end
    endtask

    // 找最小 score 的下标
    function [5:0] find_min_idx(input sel, input [5:0] n);
        integer j; reg [31:0] minv; reg [5:0] mini0;
    begin
        minv = 32'hFFFFFFFF; mini0 = 6'd0;
        for (j=0;j<MAX_OUT_BLOBS;j=j+1) if (j<n) begin
            if (sel==1'b0) begin
                if (a_score[j] < minv) begin minv = a_score[j]; mini0 = j[5:0]; end
            end else begin
                if (b_score[j] < minv) begin minv = b_score[j]; mini0 = j[5:0]; end
            end
        end
        find_min_idx = mini0;
    end
    endfunction

    reg next_draw_sel, next_fill_sel, clear_sel;
    // 主逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_addr_out<=0; draw_sel<=1'b0; fill_sel<=1'b1; pending_swap<=1'b0;
            a_n<=0; b_n<=0;
            for (i=0;i<MAX_OUT_BLOBS;i=i+1) begin
                a_x0[i]<=0; a_x1[i]<=0; a_y0[i]<=0; a_y1[i]<=0; a_score[i]<=0;
                b_x0[i]<=0; b_x1[i]<=0; b_y0[i]<=0; b_y1[i]<=0; b_score[i]<=0;
            end
            state<=S_IDLE; to_read_n<=0; idx<=0; kept_cnt<=0; arm_fetch<=1'b0; wait_ctr<=0;
        end else begin
            if (vs_rise) begin
                
                next_draw_sel=draw_sel; next_fill_sel=fill_sel; clear_sel=fill_sel;
                if (pending_swap) begin next_draw_sel=fill_sel; next_fill_sel=~fill_sel; clear_sel=next_fill_sel; end
                draw_sel<=next_draw_sel; fill_sel<=next_fill_sel; pending_swap<=1'b0;
                if (clear_sel==1'b0) a_n<=0; else b_n<=0;

                if (MAX_IN_CAP_INT >= 63) to_read_n <= in_blob_count;
                else to_read_n <= (in_blob_count > MAX_IN_CAP_INT) ? MAX_IN_CAP_INT[5:0] : in_blob_count;

                idx<=6'd1; kept_cnt<=0; arm_fetch<=1'b1; wait_ctr<=0;
            end

            case (state)
              S_IDLE: begin
                in_addr_out<=6'd0;
                if (arm_fetch) begin arm_fetch<=1'b0; state <= (to_read_n!=0)? S_REQ : S_IDLE; end
              end
              S_REQ: begin
                if (idx <= to_read_n) begin in_addr_out <= idx; wait_ctr<=0; state<=S_LATCH; end
                else state <= S_DONE;
              end
              S_LATCH: begin
                wait_ctr <= wait_ctr + 2'd1;
                if (in_bbox_valid || (wait_ctr==2'd2)) begin
                    // 基本量
                    w_t = (in_bbox_max_x >= in_bbox_min_x) ? (in_bbox_max_x - in_bbox_min_x + 11'd1) : 16'd0;
                    h_t = (in_bbox_max_y >= in_bbox_min_y) ? (in_bbox_max_y - in_bbox_min_y + 10'd1) : 16'd0;
                    area_bbox_t = w_t * h_t;
                    area_pix_t  = in_area_pix;
                    per_t = (w_t + h_t) << 1;
                    per_sq_t = per_t * per_t;
                    if (w_t >= h_t) begin long_t=w_t; short_t=h_t; end else begin long_t=h_t; short_t=w_t; end
                    long10_t = long_t * 32'd10;

                    // 判定：贴边/大框
                    // 注意：这些组合逻辑依赖当前条目的 w/h 等，放在此处计算最稳妥
                    // 不用 wire，避免不同综合器在 always 块外解析时机不同而报错
                    // 这里直接用局部变量判断
                    // 尺寸 & 像素面积
                    pass_size_t      = 1'b1;
                    if (MIN_W > 0) pass_size_t = pass_size_t && (w_t >= MIN_W);
                    if (MIN_H > 0) pass_size_t = pass_size_t && (h_t >= MIN_H);
                    if (MAX_W > 0) pass_size_t = pass_size_t && (w_t <= MAX_W);
                    if (MAX_H > 0) pass_size_t = pass_size_t && (h_t <= MAX_H);
                    pass_area_pix_t  = (area_pix_t >= MIN_AREA_PIX);

                    // 触边/大框
                    // 用当前条目的 bbox 判断
                    begin : RELAX_SCOPE
                      reg edge_touch, is_large, use_relax;
                      reg [31:0] lhs_loc, rhs_loc;
                      reg [31:0] short_min_loc, short_max_loc;

                      edge_touch = (in_bbox_min_x==11'd0) ||
                                   (in_bbox_max_x >= (WIDTH-1)) ||
                                   (in_bbox_min_y==10'd0) ||
                                   (in_bbox_max_y >= (HEIGHT-1));
                      is_large   = (w_t >= LARGE_W_THR) || (h_t >= LARGE_H_THR) || (area_bbox_t >= LARGE_AREA_BBOX_THR);
                      use_relax  = is_large || edge_touch;

                      // 紧凑度：用 area_pix（需要零扩展到32位）
                      if (per_t==0) pass_compact_t=1'b0;
                      else begin
                          // 修正：用双大括号写法，兼容性更好
                          lhs_loc = ({{(32-AREA_W){1'b0}}, area_pix_t}) * 32'd125;
                          rhs_loc = per_sq_t * (use_relax ? MIN_COMPACTNESS_LARGE : MIN_COMPACTNESS);
                          pass_compact_t = (lhs_loc > rhs_loc);
                      end

                      // 轴比
                      if ((w_t==0)||(h_t==0)) pass_ar_t=1'b0;
                      else begin
                          short_min_loc = short_t * (use_relax ? MIN_RATIO_X10_LARGE : MIN_RATIO_X10);
                          short_max_loc = short_t * (use_relax ? MAX_RATIO_X10_LARGE : MAX_RATIO_X10);
                          pass_ar_t     = (long10_t >= short_min_loc) && (long10_t <= short_max_loc);
                      end

                      // 填充率：area_pix vs (w*h)
                      if (((use_relax?EXTENT_MIN_X100_LARGE:EXTENT_MIN_X100)==0) && (EXTENT_MAX_X100==0)) pass_extent_t=1'b1;
                      else if (area_bbox_t==0) pass_extent_t=1'b0;
                      else begin
                          ext_lhs     = ({{(32-AREA_W){1'b0}}, area_pix_t}) * 32'd100;
                          ext_rhs_min = area_bbox_t * (use_relax?EXTENT_MIN_X100_LARGE:EXTENT_MIN_X100);
                          pass_extent_t = ((use_relax?EXTENT_MIN_X100_LARGE:EXTENT_MIN_X100)==0) ? 1'b1 : (ext_lhs >= ext_rhs_min);
                          if (EXTENT_MAX_X100>0) begin
                              ext_rhs_max = area_bbox_t * EXTENT_MAX_X100;
                              pass_extent_t = pass_extent_t && (ext_lhs <= ext_rhs_max);
                          end
                      end
                      //位置约束
                      pass_position_t = (in_bbox_min_y < LOWER_REGION_THRESHOLD);
                      
                      //横向约束
                      if (h_t == 0) begin
                        pass_width_height_ratio_t = 1'b0; // 避免除零
                      end else begin
                      // 直接使用宽度和高度计算宽高比，不使用长短边
                        pass_width_height_ratio_t = (w_t * 10) <= (h_t * MAX_WIDTH_HEIGHT_RATIO_X10);
                      end
                      
                      // 贴边优先（但仍要求尺寸+像素面积）
                      if (EDGE_KEEP_EN && edge_touch && (area_pix_t >= EDGE_MIN_AREA_PIX[AREA_W-1:0]))
                          keep_this = pass_size_t && pass_area_pix_t && pass_ar_t && pass_extent_t;
                      else
                          keep_this = pass_size_t && pass_area_pix_t && pass_compact_t && pass_ar_t && pass_extent_t && pass_position_t && pass_width_height_ratio_t;
                    end

                    // 分数：像素面积（越大越优先）
                    score_t = {10'd0, area_pix_t};

                    if (keep_this) begin
                        if (kept_cnt < MAX_OUT_CAP_INT[5:0]) begin
                            write_slot(fill_sel, kept_cnt, in_bbox_min_x, in_bbox_max_x, in_bbox_min_y, in_bbox_max_y, score_t);
                            kept_cnt <= kept_cnt + 6'd1;
                        end else begin
                            mini = find_min_idx(fill_sel, kept_cnt);
                            if ((fill_sel==1'b0 && score_t > a_score[mini]) ||
                                (fill_sel==1'b1 && score_t > b_score[mini])) begin
                                write_slot(fill_sel, mini, in_bbox_min_x, in_bbox_max_x, in_bbox_min_y, in_bbox_max_y, score_t);
                            end
                        end
                    end

                    idx <= idx + 6'd1;
                    state <= S_REQ;
                end
              end
              S_DONE: begin
                if (fill_sel==1'b0) a_n <= kept_cnt; else b_n <= kept_cnt;
                pending_swap <= 1'b1; state<=S_IDLE;
              end
            endcase
        end
    end

    // 读侧
    wire [5:0] ridx = (addr_in==6'd0)? 6'd0 : (addr_in-6'd1);
    wire [5:0] dn   = (draw_sel==1'b0) ? a_n : b_n;
    wire       in_range = (addr_in>=6'd1) && (addr_in<=dn);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bbox_min_x<=0; bbox_max_x<=0; bbox_min_y<=0; bbox_max_y<=0; bbox_valid<=1'b0;
        end else begin
            if (in_range) begin
                if (draw_sel==1'b0) begin
                    bbox_min_x<=a_x0[ridx]; bbox_max_x<=a_x1[ridx]; bbox_min_y<=a_y0[ridx]; bbox_max_y<=a_y1[ridx];
                end else begin
                    bbox_min_x<=b_x0[ridx]; bbox_max_x<=b_x1[ridx]; bbox_min_y<=b_y0[ridx]; bbox_max_y<=b_y1[ridx];
                end
                bbox_valid<=1'b1;
            end else begin
                bbox_min_x<=0; bbox_max_x<=0; bbox_min_y<=0; bbox_max_y<=0; bbox_valid<=1'b0;
            end
        end
    end
end
endgenerate
endmodule