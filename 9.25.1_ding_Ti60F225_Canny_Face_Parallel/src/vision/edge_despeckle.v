`timescale 1ns/1ps
//======================================================================
//  edge_despeckle.v —— Canny 边缘图去孤立噪点（P0 升级版）
//
//  判据（两级）：
//      保留 = (邻居数 >  thresh_i)                       // 粗边缘（>=2 像素宽）
//           | (邻居数 == thresh_i) & 存在「对向邻居对」  // 1 像素宽的细线
//
//  为什么加"对向邻居"：
//    只有"邻居数>=2"时，2~3 像素抱团的噪点（L 形、折角）也会存活；
//    而真实细线的两侧邻居一定是**对向**的（左-右 / 上-下 / 两对角）。
//    加上对向判定后：L 形噪点簇被清除，1 像素直线/斜线仍完整保留。
//    代价：矩形直角处的拐角像素（两邻居不相向）会被削掉 1 个像素。
//
//  窗口位序（line_buffer_3x3）：win[8]=左上 … win[4]=中心 … win[0]=右下
//    win[7]上 win[5]左 win[3]右 win[1]下 win[8]/win[0]主对角 win[6]/win[2]副对角
//
//  thresh_i 是**输入端口**（非编译期常量）→ 预留给后续旋转编码器 / param_ctrl 驱动
//  延迟：2 行（行缓存）+ 1 拍输出寄存
//======================================================================
module edge_despeckle #(
    parameter AWIDTH = 11,
    parameter WIDTH  = 1280
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                frame_start,
    input  wire [3:0]          thresh_i,     // 去噪强度：2=弱(默认) 3=中 4=强
    input  wire                de_i,
    input  wire [AWIDTH-1:0]   x_i,
    input  wire [9:0]          y_i,
    input  wire                edge_i,
    output reg                 edge_o,
    output reg                 de_o,
    output reg  [AWIDTH-1:0]   x_o,
    output reg  [9:0]          y_o
);
    wire [8:0]  win;
    wire        wv;
    wire [AWIDTH-1:0] wx;
    wire [9:0]  wy;

    line_buffer_3x3 #(.WIDTH(WIDTH), .DWIDTH(1), .AWIDTH(AWIDTH)) u_lb (
        .clk(clk), .rst_n(rst_n), .frame_start(frame_start),
        .de_i(de_i), .x_i(x_i), .y_i(y_i), .data_i(edge_i),
        .window_o(win), .window_valid(wv), .x_o(wx), .y_o(wy)
    );

    // 8 邻域计数（不含中心 win[4]）
    wire [3:0] ncnt = {3'b0, win[0]} + {3'b0, win[1]} + {3'b0, win[2]} +
                      {3'b0, win[3]} + {3'b0, win[5]} +
                      {3'b0, win[6]} + {3'b0, win[7]} + {3'b0, win[8]};

    // 对向邻居对：左右 / 上下 / 主对角 / 副对角
    wire opp = (win[5] & win[3]) | (win[7] & win[1]) |
               (win[8] & win[0]) | (win[6] & win[2]);

    wire keep = (ncnt >  thresh_i) |
                ((ncnt == thresh_i) & opp);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_o <= 1'b0; de_o <= 1'b0; x_o <= {AWIDTH{1'b0}}; y_o <= 10'd0;
        end else begin
            edge_o <= keep;
            de_o   <= wv;
            x_o    <= wx;
            y_o    <= wy;
        end
    end
endmodule
