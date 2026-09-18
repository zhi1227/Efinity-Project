

module low_pass_realtime #(
    parameter integer WIDTH     = 1280,
    parameter integer DEPTH     = 720,
    parameter integer RADIUS    = 3,      // 固定为3（对应7x7），保留参数以便后续扩展
    parameter integer THRESH    = 15      // 默认约0.52*N（N=29），更连贯可降到14/13，更锐利升到16/17
)(
    input        clk,
    input        pixel_valid,              // 输入有效
    input        binary_input,             // 二值输入（1位）
    input [10:0] pixel_x,                  // x坐标（0..WIDTH-1）
    input [9:0]  pixel_y,                  // y坐标（0..DEPTH-1）

    output reg   filtered_output,          // 二值输出
    output reg   output_valid              // 输出有效（窗口完全覆盖时为1）
);

    // -----------------------------
    // 行延时：获取上一行到第六行的当前列像素（使用块RAM）
    // -----------------------------
    wire ld1_dout, ld2_dout, ld3_dout, ld4_dout, ld5_dout, ld6_dout;

    // 为了与块RAM同步读延迟（1拍）对齐，把当前行像素也延迟1拍再入本行窗口
    reg  bin_in_d;
    always @(posedge clk) if (pixel_valid) bin_in_d <= binary_input;

    // 6级按行延时链
    line_delay_bit #(.WIDTH(WIDTH)) u_ld1 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(bin_in_d),  .dout(ld1_dout));
    line_delay_bit #(.WIDTH(WIDTH)) u_ld2 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(ld1_dout),  .dout(ld2_dout));
    line_delay_bit #(.WIDTH(WIDTH)) u_ld3 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(ld2_dout),  .dout(ld3_dout));
    line_delay_bit #(.WIDTH(WIDTH)) u_ld4 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(ld3_dout),  .dout(ld4_dout));
    line_delay_bit #(.WIDTH(WIDTH)) u_ld5 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(ld4_dout),  .dout(ld5_dout));
    line_delay_bit #(.WIDTH(WIDTH)) u_ld6 (.clk(clk), .we(pixel_valid), .addr(pixel_x), .din(ld5_dout),  .dout(ld6_dout));

    // -----------------------------
    // 每行7位横向窗口（移位寄存器），索引说明：
    // win_rowX[6] 最老（x-6），win_rowX[0] 最新（与bin_in_d对齐的当前列）
    // 中心列对应索引3（x-3）
    // -----------------------------
    reg [6:0] win_row0, win_row1, win_row2, win_row3, win_row4, win_row5, win_row6;

    // 行首清零，避免上一行尾巴污染
    wire new_line = pixel_valid && (pixel_x == 11'd0);

    always @(posedge clk) begin
        if (pixel_valid) begin
            // 行首清零
            if (new_line) begin
                win_row0 <= 7'd0;
                win_row1 <= 7'd0;
                win_row2 <= 7'd0;
                win_row3 <= 7'd0;
                win_row4 <= 7'd0;
                win_row5 <= 7'd0;
                win_row6 <= 7'd0;
            end else begin
                // 依次移位，最低位放入最新像素
                win_row0 <= {win_row0[5:0], bin_in_d};
                win_row1 <= {win_row1[5:0], ld1_dout};
                win_row2 <= {win_row2[5:0], ld2_dout};
                win_row3 <= {win_row3[5:0], ld3_dout};
                win_row4 <= {win_row4[5:0], ld4_dout};
                win_row5 <= {win_row5[5:0], ld5_dout};
                win_row6 <= {win_row6[5:0], ld6_dout};
            end
        end
    end

    // -----------------------------
    // 7x7 圆盘结构元素（半径3，欧氏距离）计数 “1”的个数
    // 选取位置：dy=0: 7列；dy=1: 5列(1..5) ×2行；dy=2: 5列(1..5) ×2行；dy=3: 1列(3) ×2行
    // 总数N=29
    // -----------------------------
    reg [5:0] sum_cnt; // 0..29 足够

    always @(posedge clk) begin
        if (pixel_valid) begin
            // 展开相加（综合器会做加法树）
            // 中心行（win_row3）全7列
            sum_cnt <=
                win_row3[0] + win_row3[1] + win_row3[2] + win_row3[3] + win_row3[4] + win_row3[5] + win_row3[6]
              // dy = ±1 -> win_row2 与 win_row4，列1..5
              + win_row2[1] + win_row2[2] + win_row2[3] + win_row2[4] + win_row2[5]
              + win_row4[1] + win_row4[2] + win_row4[3] + win_row4[4] + win_row4[5]
              // dy = ±2 -> win_row1 与 win_row5，列1..5
              + win_row1[1] + win_row1[2] + win_row1[3] + win_row1[4] + win_row1[5]
              + win_row5[1] + win_row5[2] + win_row5[3] + win_row5[4] + win_row5[5]
              // dy = ±3 -> win_row0 与 win_row6，列3
              + win_row0[3] + win_row6[3];
        end
    end

    // -----------------------------
    // 有效输出 gating：窗口完全覆盖后才输出
    // 横向需要至少7列：x >= 6；纵向需要至少7行：y >= 6
    // -----------------------------
    reg valid_s0, valid_s1;
    reg h_ok_s0, v_ok_s0, h_ok_s1, v_ok_s1;

    always @(posedge clk) begin
        valid_s0 <= pixel_valid;
        valid_s1 <= valid_s0;

        h_ok_s0 <= (pixel_x >= 11'd6);
        v_ok_s0 <= (pixel_y >= 10'd6);
        h_ok_s1 <= h_ok_s0;
        v_ok_s1 <= v_ok_s0;

        // 二值决策（与sum_cnt同步，延迟1拍的gating）
        if (valid_s1 && h_ok_s1 && v_ok_s1) begin
            filtered_output <= (sum_cnt >= THRESH);
            output_valid    <= 1'b1;
        end else begin
            filtered_output <= 1'b0;
            output_valid    <= 1'b0;
        end
    end

endmodule

// ===========================================
// 单行延时（1bit × WIDTH），推断块RAM，同步读
// ===========================================
module line_delay_bit #(
    parameter integer WIDTH = 1280
)(
    input              clk,
    input              we,
    input      [10:0]  addr,   // 0..WIDTH-1
    input              din,
    output reg         dout
);
    // 兼容多厂商属性，确保推断为块RAM
    (* ram_style = "block" *)
    (* ramstyle  = "block" *)
    reg [0:0] mem [0:WIDTH-1];

    always @(posedge clk) begin
        if (we) mem[addr] <= din;
        dout <= mem[addr]; // 同步读：输出延一拍
    end
endmodule