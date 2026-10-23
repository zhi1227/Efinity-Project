`timescale 1ns/1ps
//======================================================================
//  nms_hist.v —— 帧级自适应阈值（P2）  [重写版：REQ/USE 两拍握手，杜绝相位错位]
//  1) 帧内 1/4 采样，对 NMS 幅值 nms_mag[11:4] 做 256 bin 直方图
//  2) 帧末：REQ/USE 两拍逐 bin 求和 -> N；再自顶向下累加，累到 >= N/2^ratio_shift
//     的那一格即 TH_HIGH（取格中心），TH_LOW = TH_HIGH >> 1
//  3) ratio_shift_i 3=1/8, 4=1/16(默认), 5=1/32  → 编码器预留接口
//======================================================================
module nms_hist #(
    parameter BINS = 256
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                frame_start,
    input  wire                frame_end,
    input  wire [3:0]          ratio_shift_i,
    input  wire [11:0]         mag_i,
    input  wire                mag_valid_i,
    output reg  [11:0]         th_high_o,
    output reg  [11:0]         th_low_o,
    output reg                 th_valid_o,
    output reg  [2:0]          dbg_state,
    // ---- 调试用（只在 st==IDLE 时用，仿真定位直方图内容）----
    input  wire [7:0]          dbg_addr_i,
    input  wire                dbg_req_i,
    output reg  [15:0]         dbg_hist_o,
    output wire [31:0]         dbg_n_total_o,
    output wire [31:0]         dbg_target_o
);
    localparam S_IDLE=3'd0, S_CLR=3'd1, S_SUM_REQ=3'd2, S_SUM_USE=3'd3,
               S_PREP=3'd4, S_SCAN_REQ=3'd5, S_SCAN_USE=3'd6;

    (* ram_style="block" *) (* ramstyle="block" *)
    reg [15:0] hist [0:BINS-1];

    reg [2:0]  st;
    reg [8:0]  idx;
    reg [7:0]  clr_i;
    reg [31:0] n_total, acc, target;
    reg [15:0] rd;
    reg        rd_en;
    reg [11:0] bin_hit;
    reg        dbg_req_d;

    // 直方图读（同步，1 拍）
    always @(posedge clk) if (rd_en) rd <= hist[idx];

    // 唯一写口：清零 / 采样累加
    reg [1:0]  samp, upd_st;
    reg [8:0]  upd_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin samp<=2'd0; upd_st<=2'd0; upd_idx<=9'd0; end
        else begin
            case (upd_st)
            2'd0: if (st==S_IDLE && (upd_st==2'd0) && mag_valid_i) begin
                      if (samp==2'd3) begin
                          samp<=2'd0; upd_idx<=mag_i[11:4]; upd_st<=2'd1;   // 先立地址
                      end else samp<=samp+2'd1;
                  end
            2'd1: upd_st <= 2'd2;      // 地址已稳定，本相发 rd_en（见 FSM 块）
            2'd2: upd_st <= 2'd0;      // 本相写回 rd+1
            endcase
        end
    end

    always @(posedge clk) begin
        if (st==S_CLR)        hist[clr_i]  <= 16'd0;
        else if (upd_st==2'd2) hist[upd_idx] <= rd + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st<=S_IDLE; idx<=9'd0; clr_i<=8'd0; n_total<=0; acc<=0; target<=0;
            th_high_o<=0; th_low_o<=0; th_valid_o<=1'b0; rd_en<=1'b0; bin_hit<=0;
            dbg_state<=S_IDLE;
        end else begin
            dbg_state <= st;
            rd_en <= 1'b0;
            dbg_req_d <= 1'b0;
            if (upd_st==2'd1) begin idx<=upd_idx; rd_en<=1'b1; end  // 采样读（地址已在前相立好）
            else if (dbg_req_i && (st==S_IDLE)) begin idx<=dbg_addr_i; rd_en<=1'b1; dbg_req_d<=1'b1; end
            if (dbg_req_d) dbg_hist_o <= rd;
            case (st)
            S_IDLE: if (frame_start) begin st<=S_CLR; clr_i<=8'd0; end
                    else if (frame_end) begin st<=S_SUM_REQ; idx<=9'd0; n_total<=0; end
            S_CLR: begin
                if (clr_i==BINS[7:0]-1'b1) begin st<=S_IDLE; clr_i<=8'd0; end   // 清完回 IDLE，等 frame_end 再统计
                else clr_i<=clr_i+8'd1;
            end
            // ---- 求和：REQ(发地址) / USE(取数据) 交替 ----
            S_SUM_REQ: begin rd_en<=1'b1; st<=S_SUM_USE; end
            S_SUM_USE: begin
                n_total <= n_total + rd;
                if (idx==BINS[8:0]-1'b1) begin st<=S_PREP; end
                else begin idx<=idx+9'd1; st<=S_SUM_REQ; end
            end
            S_PREP: begin
                target  <= n_total >> ratio_shift_i;
                idx     <= BINS[8:0]-1'b1;
                acc     <= 32'd0;
                st      <= S_SCAN_REQ;
            end
            // ---- 扫描：自顶向下 ----
            S_SCAN_REQ: begin rd_en<=1'b1; st<=S_SCAN_USE; end
            S_SCAN_USE: begin
                if ((acc + rd) >= target) begin          // 命中：用当前格
                    th_high_o  <= {idx[7:0], 4'b1000};
                    th_low_o   <= {idx[7:0], 4'b1000} >> 1;
                    th_valid_o <= 1'b1;
                    st         <= S_IDLE;
                end else if (idx==9'd0) begin            // 兜底
                    th_high_o  <= 12'd16;
                    th_low_o   <= 12'd8;
                    th_valid_o <= 1'b1;
                    st         <= S_IDLE;
                end else begin
                    acc <= acc + rd;
                    idx <= idx - 9'd1;
                    st  <= S_SCAN_REQ;
                end
            end
            default: st <= S_IDLE;
            endcase
        end
    end
    // 调试输出（放在声明之后，避免 used before declaration）
    assign dbg_n_total_o = n_total;
    assign dbg_target_o  = target;
endmodule
