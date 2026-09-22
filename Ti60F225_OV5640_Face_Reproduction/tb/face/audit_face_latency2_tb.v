`timescale 1ns/1ps
//======================================================================
//  audit_face_latency2_tb.v
//----------------------------------------------------------------------
//  Task 0 延迟审计（第二版，方法修正）
//
//  第一版用"输出侧首次 valid 的时刻"做基准，这对 low_pass / 腐蚀路径
//  是对的（它们从第 1 行末尾就开始输出），但对 morph 的垂直开运算
//  路径是**错的**：开运算路径要等 row_ready_v 饱和（VLEN-1 行）后
//  才开始输出，所以"首次 valid"只反映了饱和等待，不含下游 8 级行延时。
//
//  本版改用**信号边沿差分**：
//    输入侧放一个"脉冲标记"（某一行整行为 1，其余行整行为 0），
//    输出侧观察该脉冲的上升沿出现时刻，作差即总延迟。
//    脉冲必须足够宽（整行），才能穿过多数滤波/腐蚀而不被吃掉。
//
//  为了让脉冲不被腐蚀掉，用"上下各 3 行同时为 1"（7 行高的块），
//  这样 3x3 腐蚀后中心仍是 1，7x7 多数滤波后也仍是 1。
//======================================================================

module audit_face_latency2_tb;

    localparam integer WIDTH     = 1280;
    localparam integer PRE_ROWS  = 20;    // 脉冲前的填充行
    localparam integer BLK_ROWS  = 7;     // 脉冲块高度（3x3 腐蚀需 >=3，7x7 多数需 >=7）
    localparam integer POST_ROWS = 40;    // 脉冲后排空
    localparam integer CLK_HALF  = 5;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #CLK_HALF clk = ~clk;

    integer err = 0;

    reg          de_i;
    reg  [10:0]  x_i;
    reg  [9:0]   y_i;
    reg          bin_i;
    reg          vs_i;

    //------------------------------------------------------------------
    // 被测 1：low_pass_realtime
    //------------------------------------------------------------------
    wire lpf_out, lpf_v;
    low_pass_realtime #(.WIDTH(WIDTH), .DEPTH(720), .RADIUS(3), .THRESH(15))
      u_lpf (.clk(clk), .pixel_valid(de_i), .binary_input(bin_i),
             .pixel_x(x_i), .pixel_y(y_i),
             .filtered_output(lpf_out), .output_valid(lpf_v));

    //------------------------------------------------------------------
    // 被测 2/3：morph 两条路径
    //------------------------------------------------------------------
    wire mor0_out, mor0_v;
    wire mor1_out, mor1_v;

    morph_erode3x3_stream #(.WIDTH(WIDTH), .V_OPEN_LEN(9))
      u_mor_erode (.clk(clk), .rst_n(rst_n), .vs_in(vs_i),
                   .de_in(de_i), .bin_in(bin_i), .break_en_i(1'b0),
                   .erode_out(mor0_out), .erode_valid(mor0_v));

    morph_erode3x3_stream #(.WIDTH(WIDTH), .V_OPEN_LEN(9))
      u_mor_open (.clk(clk), .rst_n(rst_n), .vs_in(vs_i),
                  .de_in(de_i), .bin_in(bin_i), .break_en_i(1'b1),
                  .erode_out(mor1_out), .erode_valid(mor1_v));

    //------------------------------------------------------------------
    // 边沿检测辅助：记录各输出侧"第一次出现 data=1 且 valid=1"的时刻
    //------------------------------------------------------------------
    integer t_lpf1, t_mor0_1, t_mor1_1;
    reg     armed;

    always @(posedge clk) begin
        if (armed) begin
            if (lpf_v  && lpf_out  && t_lpf1   < 0) t_lpf1   = $time;
            if (mor0_v && mor0_out && t_mor0_1 < 0) t_mor0_1 = $time;
            if (mor1_v && mor1_out && t_mor1_1 < 0) t_mor1_1 = $time;
        end
    end

    // 输入侧脉冲块第一行第一列的时刻
    integer t_in;

    integer r, c;

    initial begin
        de_i = 0; x_i = 0; y_i = 0; bin_i = 0; vs_i = 0; armed = 0;
        t_lpf1 = -1; t_mor0_1 = -1; t_mor1_1 = -1; t_in = -1;

        $display("================================================================");
        $display(" Task 0: face 模块总延迟实测（脉冲块法）");
        $display("   块: 行 %0d..%0d, 整行全 1；其余行全 0", PRE_ROWS, PRE_ROWS+BLK_ROWS-1);
        $display("================================================================");

        repeat(4) @(negedge clk);
        rst_n = 1'b1;
        repeat(2) @(negedge clk);
        vs_i = 1'b1; @(negedge clk); vs_i = 1'b0; @(negedge clk);
        armed = 1'b1;

        // 前置填充行
        for (r = 0; r < PRE_ROWS; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                @(negedge clk);
                de_i = 1'b1; x_i = c[10:0]; y_i = r[9:0]; bin_i = 1'b0;
            end
            @(negedge clk); de_i = 1'b0; bin_i = 1'b0;
        end

        // 脉冲块：BLK_ROWS 行整行全 1
        for (r = PRE_ROWS; r < PRE_ROWS + BLK_ROWS; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                @(negedge clk);
                de_i = 1'b1; x_i = c[10:0]; y_i = r[9:0]; bin_i = 1'b1;
                if (r == PRE_ROWS && c == 0) t_in = $time;
            end
            @(negedge clk); de_i = 1'b0; bin_i = 1'b0;
        end

        // 排空
        for (r = PRE_ROWS + BLK_ROWS; r < PRE_ROWS + BLK_ROWS + POST_ROWS; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                @(negedge clk);
                de_i = 1'b1; x_i = c[10:0]; y_i = r[9:0]; bin_i = 1'b0;
            end
            @(negedge clk); de_i = 1'b0; bin_i = 1'b0;
        end

        repeat(10) @(negedge clk);
        armed = 0;

        $display("");
        $display("  输入脉冲块首像素时刻 t_in = %0t", t_in);
        $display("");
        begin : CALC
            integer cyc;
            integer d_lpf, d_mor0, d_mor1;
            integer ROWCY;
            cyc = 2 * CLK_HALF;
            ROWCY = WIDTH + 1;   // 1281

            d_lpf  = (t_lpf1   - t_in) / cyc;
            d_mor0 = (t_mor0_1 - t_in) / cyc;
            d_mor1 = (t_mor1_1 - t_in) / cyc;

            $display("  总延迟（拍）:");
            $display("    low_pass_realtime          : %6d 拍 = %0d 行 + %0d 拍",
                     d_lpf,  d_lpf/ROWCY,  d_lpf%ROWCY);
            $display("    morph 腐蚀 (brk=0)          : %6d 拍 = %0d 行 + %0d 拍",
                     d_mor0, d_mor0/ROWCY, d_mor0%ROWCY);
            $display("    morph 开运算 (brk=1)        : %6d 拍 = %0d 行 + %0d 拍",
                     d_mor1, d_mor1/ROWCY, d_mor1%ROWCY);
            $display("");
            $display("  设计预期:");
            $display("    low_pass  : 6 级行延时 + 内部打拍");
            $display("    morph 腐蚀: 2 级行延时 + 内部打拍");
            $display("    morph 开运算: 2*(VLEN-1)=16 级行延时 + 内部打拍");
            $display("");
            $display("  err = %0d", err);
        end
        $display("================================================================");
        $finish;
    end

    initial begin
        #80000000;
        $display("TIMEOUT err=%0d", err);
        $finish;
    end

endmodule
