`timescale 1ns / 1ps
// Streaming CCL wrapper with tail-flush of zero rows to finalize edge-touching blobs.
// 变更点：
// - 新增 FLUSH_ROWS：每帧结束后向 true_ccl 追加 FLUSH_ROWS 行全0（DataEn=1, PixelData=0），强制 finalize 贴边连通域。
// - 将 true_ccl 的复位从 frame_start 延后到“冲刷完成”之后，再下发 RST_CYCLES。
// - 双缓冲表的切换、break_en_o 的发布，也改为在“冲刷完成（进入RESET阶段）”时进行，确保贴边目标不会漏掉。
// 其余接口/功能保持不变。
module streaming_connected_components #(
    parameter integer Wb = 11,
    parameter integer Hb = 10,
    parameter integer Nb = 10,
    parameter integer MAX_BLOBS = 64,
    parameter integer RST_CYCLES = 8,
    // 碎块过滤（CCL 内部先做一道最小保护）
    parameter integer MIN_W = 40,
    parameter integer MIN_H = 40,
    parameter integer MIN_AREA = 2500,
    // 近脸触发阈值
    parameter integer BREAK_MIN_W = 100,
    parameter integer BREAK_MIN_H = 140,
    parameter integer BREAK_AR_MIN_X10 = 12, // h/w >=1.2
    // 面积位宽
    parameter integer AREA_W = 22,
    // 帧尾冲刷的虚拟零行数
    parameter integer FLUSH_ROWS = 2,
    // 每行像素宽度（用于冲刷宽度计数）
    parameter integer WIDTH = 1280
)(
    input               clk, input rst_n,

    // Pixel stream from upstream
    input               in_valid,
    input               in_bin,
    input [10:0]        in_x,       // 未使用，仅为接口兼容
    input [9:0]         in_y,       // 未使用，仅为接口兼容

    // Frame delimitation pulses（由上层基于 VS 沿检测生成）
    input               frame_start, // VS 上升沿单拍
    input               frame_end,   // VS 下降沿单拍

    // Previous-frame compact bbox table (random read)
    output reg [5:0]    blob_count,
    input      [5:0]    raddr,
    output reg [10:0]   r_min_x, r_max_x,
    output reg [9:0]    r_min_y, r_max_y,
    output reg          r_valid,
    output reg [AREA_W-1:0] r_area_pix,

    // 帧级近脸触发（上一帧是否存在近脸）
    output reg          break_en_o,

    // debug LED
    output              led
);
    localparam integer COUNTW = 90 - 3*Wb - 2*Hb - Nb;

    // --------------------------
    // 尾部冲刷 + 复位 状态机
    // --------------------------
    localparam ST_RUN   = 2'd0; // 正常喂流
    localparam ST_FLUSH = 2'd1; // 喂 FLUSH_ROWS 行全0
    localparam ST_RESET = 2'd2; // 下发 RST_CYCLES 个周期的 SRST

    reg [1:0] st;
    reg [10:0] flush_col;
    reg [7:0]  flush_row;
    reg [$clog2(RST_CYCLES+1)-1:0] rst_cnt;
    reg core_srst_n;

    wire flush_start = frame_end; // 帧尾单拍触发冲刷

    // 送入 true_ccl 的有效与像素：正常 in_valid/in_bin 或 冲刷数据
    wire core_DataEn = (st==ST_FLUSH) ? 1'b1 : in_valid;
    wire core_Pixel  = (st==ST_FLUSH) ? 1'b0 : in_bin;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        st <= ST_RUN;
        flush_col <= 11'd0; flush_row <= 8'd0;
        rst_cnt <= 0; core_srst_n <= 1'b1;
      end else begin
        case(st)
          ST_RUN: begin
            core_srst_n <= 1'b1;
            if (flush_start) begin
              st <= ST_FLUSH;
              flush_col <= 11'd0;
              flush_row <= 8'd0;
            end
          end
          ST_FLUSH: begin
            core_srst_n <= 1'b1;
            // 送一整行 WIDTH 个 0
            flush_col <= flush_col + 11'd1;
            if (flush_col == (WIDTH-1)) begin
              flush_col <= 11'd0;
              flush_row <= flush_row + 8'd1;
            end
            // 完成 FLUSH_ROWS 行 -> 进入 reset
            if ((flush_row == (FLUSH_ROWS-1)) && (flush_col == (WIDTH-1))) begin
              st <= ST_RESET;
              rst_cnt <= RST_CYCLES[$clog2(RST_CYCLES+1)-1:0];
            end
          end
          ST_RESET: begin
            // 对 true_ccl 下发短复位
            core_srst_n <= 1'b0;
            if (rst_cnt != 0) begin
              rst_cnt <= rst_cnt - 1'b1;
            end else begin
              st <= ST_RUN;
              core_srst_n <= 1'b1;
            end
          end
          default: st <= ST_RUN;
        endcase
      end
    end

    // true_ccl
    wire                        core_OEn;
    wire [COUNTW-1:0]           core_Count;
    wire [Wb-1:0]               core_XMin, core_XMax;
    wire [Hb-1:0]               core_YMin, core_YMax;
    wire [Nb-1:0]               core_RealN;

    true_ccl #(.Wb(Wb),.Hb(Hb),.Nb(Nb)) u_true_ccl (
      .clk(clk),
      .SRST(core_srst_n),            // 注意：复位已改为“冲刷后再复位”
      .DataEn(core_DataEn),          // 冲刷期间持续有效
      .PixelData(core_Pixel),        // 冲刷像素恒为 0
      .OEn(core_OEn),
      .Count(core_Count),
      .XMin(core_XMin), .XMax(core_XMax),
      .YMin(core_YMin), .YMax(core_YMax),
      .RealN(core_RealN)
    );

    // debug LED：拉亮一段时间
    reg [23:0] oen_stretch;
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) oen_stretch <= 0;
      else if(core_OEn) oen_stretch <= 24'd10_000_00;
      else if(oen_stretch!=0) oen_stretch <= oen_stretch - 1'b1;
    end
    assign led = (oen_stretch != 0);

    // 尺寸/面积计算
    wire [10:0] w_calc = (core_XMax >= core_XMin)? (core_XMax - core_XMin + 11'd1):11'd0;
    wire [9:0]  h_calc = (core_YMax >= core_YMin)? (core_YMax - core_YMin + 10'd1):10'd0;
    wire [21:0] area_calc = w_calc * h_calc;
    wire        pass_small = (w_calc >= MIN_W[10:0]) && (h_calc >= MIN_H[9:0]) && (area_calc >= MIN_AREA[21:0]);

    // 近脸触发：高且偏瘦（统计到“本帧结束冲刷完成”为止）
    wire [21:0] lhs = h_calc * 22'd10;
    wire [21:0] rhs = w_calc * BREAK_AR_MIN_X10;
    wire        tall_slim = (lhs >= rhs);
    reg         large_seen;

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        large_seen <= 1'b0;
        break_en_o <= 1'b0;
      end else begin
        // 只要在本帧（包含冲刷期）见到符合阈值的大块，即置位
        if (core_OEn && pass_small) begin
          if ((w_calc >= BREAK_MIN_W[10:0]) && (h_calc >= BREAK_MIN_H[9:0]) && tall_slim)
            large_seen <= 1'b1;
        end
        // 在进入 RESET（即冲刷完成）时发布上一帧的 break_en，并清零计数
        if (st==ST_RESET && rst_cnt==RST_CYCLES[$clog2(RST_CYCLES+1)-1:0]) begin
          break_en_o <= large_seen;
          large_seen <= 1'b0;
        end
      end
    end

    // 双缓冲表：在 OEn 时写入；在进入 RESET（冲刷完成）时切换与发布
    reg buf_sel; reg [5:0] wr_count, rd_count;
    reg [10:0] min_x_buf0 [0:MAX_BLOBS-1], max_x_buf0 [0:MAX_BLOBS-1];
    reg [9:0]  min_y_buf0 [0:MAX_BLOBS-1], max_y_buf0 [0:MAX_BLOBS-1];
    reg [AREA_W-1:0] area_buf0 [0:MAX_BLOBS-1];
    reg [10:0] min_x_buf1 [0:MAX_BLOBS-1], max_x_buf1 [0:MAX_BLOBS-1];
    reg [9:0]  min_y_buf1 [0:MAX_BLOBS-1], max_y_buf1 [0:MAX_BLOBS-1];
    reg [AREA_W-1:0] area_buf1 [0:MAX_BLOBS-1];

    integer i;
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        wr_count<=0; rd_count<=0; buf_sel<=1'b0;
        for(i=0;i<MAX_BLOBS;i=i+1) begin
          min_x_buf0[i]<=0; max_x_buf0[i]<=0; min_y_buf0[i]<=0; max_y_buf0[i]<=0; area_buf0[i]<=0;
          min_x_buf1[i]<=0; max_x_buf1[i]<=0; min_y_buf1[i]<=0; max_y_buf1[i]<=0; area_buf1[i]<=0;
        end
      end else begin
        // 写：本帧（含冲刷期）所有通过 pass_small 的结果
        if (core_OEn && pass_small) begin
          if (wr_count < MAX_BLOBS) begin
            if (!buf_sel) begin
              min_x_buf0[wr_count]<=core_XMin; max_x_buf0[wr_count]<=core_XMax;
              min_y_buf0[wr_count]<=core_YMin; max_y_buf0[wr_count]<=core_YMax;
              area_buf0[wr_count] <=core_Count[AREA_W-1:0];
            end else begin
              min_x_buf1[wr_count]<=core_XMin; max_x_buf1[wr_count]<=core_XMax;
              min_y_buf1[wr_count]<=core_YMin; max_y_buf1[wr_count]<=core_YMax;
              area_buf1[wr_count] <=core_Count[AREA_W-1:0];
            end
            if (wr_count != MAX_BLOBS-1) wr_count <= wr_count + 6'd1;
          end
        end

        // 切换：在进入 RESET 的第一个周期执行（冲刷完成）
        if (st==ST_RESET && rst_cnt==RST_CYCLES[$clog2(RST_CYCLES+1)-1:0]) begin
          rd_count <= wr_count;
          buf_sel  <= ~buf_sel;
          wr_count <= 6'd0;
        end
      end
    end

    // 对外发布计数（上一帧）
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) blob_count <= 6'd0;
      else        blob_count <= rd_count;
    end

    // 随机读（上一帧）
    wire [5:0] ridx = (raddr==6'd0)? 6'd0 : (raddr-6'd1);
    wire       r_in_range = (raddr>=6'd1) && (raddr<=rd_count);
    wire [10:0] rd_min_x = (!buf_sel)? min_x_buf1[ridx] : min_x_buf0[ridx];
    wire [10:0] rd_max_x = (!buf_sel)? max_x_buf1[ridx] : max_x_buf0[ridx];
    wire [9:0]  rd_min_y = (!buf_sel)? min_y_buf1[ridx] : min_y_buf0[ridx];
    wire [9:0]  rd_max_y = (!buf_sel)? max_y_buf1[ridx] : max_y_buf0[ridx];
    wire [AREA_W-1:0] rd_area = (!buf_sel)? area_buf1[ridx] : area_buf0[ridx];

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        r_min_x<=0; r_max_x<=0; r_min_y<=0; r_max_y<=0; r_area_pix<={AREA_W{1'b0}}; r_valid<=1'b0;
      end else begin
        if (r_in_range) begin
          r_min_x<=rd_min_x; r_max_x<=rd_max_x; r_min_y<=rd_min_y; r_max_y<=rd_max_y; r_area_pix<=rd_area; r_valid<=1'b1;
        end else begin
          r_min_x<=0; r_max_x<=0; r_min_y<=0; r_max_y<=0; r_area_pix<={AREA_W{1'b0}}; r_valid<=1'b0;
        end
      end
    end
endmodule