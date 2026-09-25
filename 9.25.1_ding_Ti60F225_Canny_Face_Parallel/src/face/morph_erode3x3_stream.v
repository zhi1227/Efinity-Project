`timescale 1ns/1ps
// 3x3 binary erosion (min) OR vertical Nx1 opening (adaptive), streaming, BRAM line-buffers.
// - WIDTH = 1280 for 720p
// - If break_en_i=0: output = 3x3 erosion (vertical行延时用BRAM)
// - If break_en_i=1: output = vertical opening with length V_OPEN_LEN (N必须为奇数>=3)
// 依赖外部已存在的 line_delay_bit 模块（见 low_pass_realtime.v）
module morph_erode3x3_stream #(
  parameter integer WIDTH        = 1280,
  parameter integer V_OPEN_LEN   = 11      // 建议 7/9/11；越大越易断开“脸-脖”竖向连接
)(
  input        clk,
  input        rst_n,
  input        vs_in,
  input        de_in,
  input        bin_in,
  input        break_en_i,        // 上一帧“大目标”标志：1=启用垂直N开运算；0=仅3x3腐蚀

  output reg   erode_out,         // 自适应输出
  output reg   erode_valid        // 对应路径有效
);

  // VS rising
  reg vs_q; wire vs_rise = vs_in & ~vs_q;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) vs_q <= 1'b0; else vs_q <= vs_in;
  end

  // ----------------------------------------------------------------------------
  // Path A: 3x3 腐蚀（行延时用 BRAM）
  // ----------------------------------------------------------------------------
  // BRAM 同步读对齐：当前行像素延迟 1 拍作为窗口输入
  reg bin_in_d;
  always @(posedge clk) if (de_in) bin_in_d <= bin_in;

  // 列地址（写入/读取 BRAM 行延时）
  reg [10:0] col_cnt3;
  reg        de_q3;
  wire       de_fall3 = (~de_in) & de_q3;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      col_cnt3 <= 11'd0;
      de_q3    <= 1'b0;
    end else begin
      de_q3 <= de_in;
      if (vs_rise) col_cnt3 <= 11'd0;
      else if (de_in) begin
        col_cnt3 <= (col_cnt3 == WIDTH-1) ? 11'd0 : (col_cnt3 + 11'd1);
      end else if (de_fall3) begin
        col_cnt3 <= 11'd0;
      end
    end
  end

  // 两条 BRAM 行延时：得到上一行、上两行的像素（与 bin_in_d 对齐）
  wire ld1_dout3, ld2_dout3;
  // stage0: 写入 bin_in_d
  line_delay_bit #(.WIDTH(WIDTH)) u_ld1_3 (
    .clk  (clk),
    .we   (de_in),
    .addr (col_cnt3),
    .din  (bin_in_d),
    .dout (ld1_dout3)
  );
  // stage1: 写入上一行输出
  line_delay_bit #(.WIDTH(WIDTH)) u_ld2_3 (
    .clk  (clk),
    .we   (de_in),
    .addr (col_cnt3),
    .din  (ld1_dout3),
    .dout (ld2_dout3)
  );

  // 三行的水平3-tap移位寄存器（每行3bit），行首清零
  reg [2:0] h0, h1, h2;
  wire new_line3 = de_in && (col_cnt3 == 11'd0);

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      h0 <= 3'b000; h1 <= 3'b000; h2 <= 3'b000;
    end else if (de_in) begin
      if (new_line3) begin
        h0 <= 3'b000; h1 <= 3'b000; h2 <= 3'b000;
      end else begin
        h0 <= {h0[1:0], bin_in_d};
        h1 <= {h1[1:0], ld1_dout3};
        h2 <= {h2[1:0], ld2_dout3};
      end
    end
  end

  // 垂直行就绪（0..2），每行末尾+1
  reg [1:0] row_ready3;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) row_ready3 <= 2'd0;
    else if (vs_rise) row_ready3 <= 2'd0;
    else if (de_fall3 && (row_ready3 != 2'd2)) row_ready3 <= row_ready3 + 2'd1;
  end

  wire valid_3x3 = de_in && (col_cnt3 >= 11'd2) && (row_ready3 == 2'd2);
  wire out_3x3   = &{h0, h1, h2};

  // ----------------------------------------------------------------------------
  // Path B: 垂直 N×1 开运算（行延时均用 BRAM）
  // 先垂直 N 腐蚀（AND N 行），再对“腐蚀后流”垂直 N 膨胀（OR N 行）
  // ----------------------------------------------------------------------------
  localparam integer VLEN = (V_OPEN_LEN < 3) ? 3 : (V_OPEN_LEN | 1); // 强制奇数>=3

  // 行就绪计数 0..(VLEN-1)（基于输入流）
  reg [$clog2(VLEN):0] row_ready_v;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) row_ready_v <= 0;
    else if (vs_rise) row_ready_v <= 0;
    else if (de_fall3 && (row_ready_v < VLEN-1)) row_ready_v <= row_ready_v + 1'b1;
  end

  // VLEN-1 条 BRAM 行延时链：把当前/上一行/.../上VLEN-1行对齐到同一拍
  wire [VLEN-2:0] vtap_bin;
  genvar gi;
  generate
    for (gi=0; gi<VLEN-1; gi=gi+1) begin: GEN_VTAP_BIN
      wire din_i = (gi==0) ? bin_in_d : vtap_bin[gi-1];
      line_delay_bit #(.WIDTH(WIDTH)) u_vtap_bin (
        .clk  (clk),
        .we   (de_in),
        .addr (col_cnt3),
        .din  (din_i),
        .dout (vtap_bin[gi])
      );
    end
  endgenerate

  // 垂直 N 腐蚀：AND 当前(bin_in_d) 与 vtap_bin[*]
  integer k;
  reg out_v_erode;
  always @(*) begin
    out_v_erode = bin_in_d;
    for (k=0; k<VLEN-1; k=k+1)
      out_v_erode = out_v_erode & vtap_bin[k];
  end
  wire valid_v_erode = de_in && (row_ready_v == VLEN-1);

  // 对齐同步读：腐蚀结果延迟 1 拍再进入第二组 BRAM 行延时
  reg erode_v_d;  // 写入下游行延时
  always @(posedge clk) if (valid_v_erode) erode_v_d <= out_v_erode;

  // 针对“腐蚀后流”的列地址与行延时（VLEN-1 条）
  reg  [10:0] col_cnt_v;
  reg         v_de_q;
  wire        v_de_fall = (~valid_v_erode) & v_de_q;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      col_cnt_v <= 11'd0; v_de_q <= 1'b0;
    end else begin
      v_de_q <= valid_v_erode;
      if (vs_rise) col_cnt_v <= 11'd0;
      else if (valid_v_erode) begin
        col_cnt_v <= (col_cnt_v == WIDTH-1) ? 11'd0 : (col_cnt_v + 11'd1);
      end else if (v_de_fall) begin
        col_cnt_v <= 11'd0;
      end
    end
  end

  wire [VLEN-2:0] vtap_ero; // 前一/前二/...行的腐蚀结果
  genvar gj;
  generate
    for (gj=0; gj<VLEN-1; gj=gj+1) begin: GEN_VTAP_ERO
      wire din_j = (gj==0) ? erode_v_d : vtap_ero[gj-1];
      line_delay_bit #(.WIDTH(WIDTH)) u_vtap_ero (
        .clk  (clk),
        .we   (valid_v_erode),
        .addr (col_cnt_v),
        .din  (din_j),
        .dout (vtap_ero[gj])
      );
    end
  endgenerate

  // 垂直 N 膨胀：OR 当前(erode_v_d) 与 vtap_ero[*]
  integer m;
  reg out_v_open;
  always @(*) begin
    out_v_open = erode_v_d;
    for (m=0; m<VLEN-1; m=m+1)
      out_v_open = out_v_open | vtap_ero[m];
  end
  // 有效：沿用 valid_v_erode（顶/底若有边缘效应，对断桥影响不大）
  wire valid_v_open = valid_v_erode;

  // ----------------------------------------------------------------------------
  // 输出选择
  // ----------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      erode_out   <= 1'b0;
      erode_valid <= 1'b0;
    end else begin
      if (break_en_i) begin
        erode_out   <= valid_v_open ? out_v_open : 1'b0;
        erode_valid <= valid_v_open;
      end else begin
        erode_out   <= valid_3x3 ? out_3x3 : 1'b0;
        erode_valid <= valid_3x3;
      end
    end
  end


endmodule