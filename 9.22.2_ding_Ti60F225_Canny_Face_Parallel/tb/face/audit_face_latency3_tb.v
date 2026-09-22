`timescale 1ns/1ps
//======================================================================
//  audit_face_latency3_tb.v  —— 最终方法：相位差分（唯一可信）
//----------------------------------------------------------------------
//  前两版都不可信，原因：
//    v1 用"首次 valid 时刻" —— 含 row_ready 饱和等待，不是纯延迟
//    v2 用"脉冲块上升沿"   —— 脉冲被腐蚀/滤波改变形状，边沿不可靠
//
//  本版方法（无歧义）：
//    给一个**长时间的稳定行流**（比如 200 行），
//    在 (x=100, y=50) 处放一个"相位标记"——但不用数据，
//    而是记录 **de_i 在第 50 行的第 100 个像素** 对应的 $time，
//    再在输出侧记录 **de_o(或 valid) 第一次变为高** 之后，
//    数到第 100 个有效像素 的 $time。
//    两者之差 = 该级的 (行延迟 × 1281 + 拍延迟)。
//
//    因为两侧数的是"同一个序号的像素"，所以与数据内容无关，
//    也不会被腐蚀/滤波影响。这是最鲁棒的做法。
//
//  同时输出行延迟与拍延迟的分解，用 x_o/y_o 辅助验证。
//======================================================================

module audit_face_latency3_tb;

    localparam integer WIDTH     = 1280;
    localparam integer TOTAL_ROWS= 120;
    localparam integer MARK_ROW  = 50;
    localparam integer MARK_COL  = 100;
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
    // 被测 1：low_pass_realtime（无 x_o/y_o 输出，只有 output_valid）
    //------------------------------------------------------------------
    wire lpf_out, lpf_v;
    low_pass_realtime #(.WIDTH(WIDTH), .DEPTH(720), .RADIUS(3), .THRESH(15))
      u_lpf (.clk(clk), .pixel_valid(de_i), .binary_input(bin_i),
             .pixel_x(x_i), .pixel_y(y_i),
             .filtered_output(lpf_out), .output_valid(lpf_v));

    //------------------------------------------------------------------
    // 被测 2/3：morph 两条路径（同样无 x_o/y_o，只有 erode_valid）
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
    // 相位计数：对每一路，在"valid 高"时计数有效像素序号
    //   输入侧：序号 = 全局像素计数
    //   输出侧：序号 = 从该路 valid 首次拉高起算
    //------------------------------------------------------------------
    // 输入侧：记录 MARK 点的全局像素序号
    integer in_pixcnt;          // 输入像素计数（de_i 高时自增）
    integer mark_in_time;       // MARK 点的 $time
    integer mark_in_idx;        // MARK 点的序号
    integer mark_in_row, mark_in_col;

    // 输出侧：各路从 valid 首次拉高开始数像素
    integer lpf_cnt, mor0_cnt, mor1_cnt;
    reg     lpf_run, mor0_run, mor1_run;
    integer lpf_mark_time, mor0_mark_time, mor1_mark_time;
    integer lpf_first_time, mor0_first_time, mor1_first_time;

    always @(posedge clk) begin
        if (de_i) begin
            in_pixcnt = in_pixcnt + 1;
        end
    end

    // 输入标记点
    always @(posedge clk) begin
        if (de_i && x_i == MARK_COL[10:0] && y_i == MARK_ROW[9:0] && mark_in_time < 0) begin
            mark_in_time = $time;
            mark_in_idx  = in_pixcnt;
        end
    end

    // 输出侧逐路计数，并在达到 in 侧序号时记时刻
    always @(posedge clk) begin
        // LPF
        if (lpf_v) begin
            if (!lpf_run) begin lpf_run = 1'b1; lpf_first_time = $time; lpf_cnt = 0; end
            if (lpf_cnt == mark_in_idx && lpf_mark_time < 0) lpf_mark_time = $time;
            lpf_cnt = lpf_cnt + 1;
        end
        // morph 腐蚀
        if (mor0_v) begin
            if (!mor0_run) begin mor0_run = 1'b1; mor0_first_time = $time; mor0_cnt = 0; end
            if (mor0_cnt == mark_in_idx && mor0_mark_time < 0) mor0_mark_time = $time;
            mor0_cnt = mor0_cnt + 1;
        end
        // morph 开运算
        if (mor1_v) begin
            if (!mor1_run) begin mor1_run = 1'b1; mor1_first_time = $time; mor1_cnt = 0; end
            if (mor1_cnt == mark_in_idx && mor1_mark_time < 0) mor1_mark_time = $time;
            mor1_cnt = mor1_cnt + 1;
        end
    end

    //------------------------------------------------------------------
    // 激励
    //------------------------------------------------------------------
    integer r, c;

    initial begin
        de_i=0; x_i=0; y_i=0; bin_i=0; vs_i=0;
        in_pixcnt=0; mark_in_time=-1; mark_in_idx=-1;
        lpf_cnt=0; mor0_cnt=0; mor1_cnt=0;
        lpf_run=0; mor0_run=0; mor1_run=0;
        lpf_mark_time=-1; mor0_mark_time=-1; mor1_mark_time=-1;
        lpf_first_time=-1; mor0_first_time=-1; mor1_first_time=-1;

        $display("========================================================================");
        $display(" Task 0: face 模块延迟实测 —— 相位差分法（mark 点 x=%0d y=%0d）", MARK_COL, MARK_ROW);
        $display("========================================================================");

        repeat(4) @(negedge clk);
        rst_n = 1'b1;
        repeat(2) @(negedge clk);
        vs_i = 1'b1; @(negedge clk); vs_i = 1'b0; @(negedge clk);

        for (r = 0; r < TOTAL_ROWS; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                @(negedge clk);
                de_i = 1'b1; x_i = c[10:0]; y_i = r[9:0];
                bin_i = 1'b1;      // 全 1，保证输出一直有有效像素
            end
            @(negedge clk); de_i = 1'b0; bin_i = 1'b0;
        end
        repeat(2000) @(negedge clk);

        $display("");
        $display("  输入侧 MARK 点: 序号=%0d, 时刻=%0t", mark_in_idx, mark_in_time);
        $display("");
        begin : REPORT
            integer cyc, ROWCY;
            integer d_lpf, d_mor0, d_mor1;
            integer tclk_lpf, tclk_mor0, tclk_mor1;
            integer row_lpf, row_mor0, row_mor1;
            cyc = 2*CLK_HALF;
            ROWCY = WIDTH + 1;

            $display("  各路 valid 首次拉高时刻:");
            $display("    low_pass  : %0t", lpf_first_time);
            $display("    morph 腐蚀: %0t", mor0_first_time);
            $display("    morph 开运算: %0t", mor1_first_time);
            $display("");

            if (lpf_mark_time > 0 && mor0_mark_time > 0 && mor1_mark_time > 0) begin
                d_lpf  = (lpf_mark_time  - mark_in_time) / cyc;
                d_mor0 = (mor0_mark_time - mark_in_time) / cyc;
                d_mor1 = (mor1_mark_time - mark_in_time) / cyc;

                row_lpf  = d_lpf  / ROWCY;  tclk_lpf  = d_lpf  % ROWCY;
                row_mor0 = d_mor0 / ROWCY;  tclk_mor0 = d_mor0 % ROWCY;
                row_mor1 = d_mor1 / ROWCY;  tclk_mor1 = d_mor1 % ROWCY;

                $display("  ★ 同序号像素的相位差 = 模块总延迟");
                $display("    low_pass_realtime    : %5d 拍 = %0d 行 + %3d 拍 (行周期 %0d)",
                         d_lpf,  row_lpf,  tclk_lpf,  ROWCY);
                $display("    morph 腐蚀 (brk=0)    : %5d 拍 = %0d 行 + %3d 拍",
                         d_mor0, row_mor0, tclk_mor0);
                $display("    morph 开运算 (brk=1)  : %5d 拍 = %0d 行 + %3d 拍",
                         d_mor1, row_mor1, tclk_mor1);
            end else begin
                $display("  未能捕捉到 mark 像素（mark_in_idx=%0d）", mark_in_idx);
                $display("    lpf_mark=%0t mor0_mark=%0t mor1_mark=%0t",
                         lpf_mark_time, mor0_mark_time, mor1_mark_time);
                err = err + 1;
            end
            $display("");
            $display("  err = %0d", err);
        end
        $display("========================================================================");
        $finish;
    end

    initial begin
        #200000000;
        $display("TIMEOUT err=%0d", err);
        $finish;
    end

endmodule
