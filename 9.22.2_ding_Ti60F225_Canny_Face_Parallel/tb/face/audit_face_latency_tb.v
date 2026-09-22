`timescale 1ns/1ps
//======================================================================
//  audit_face_latency_tb.v
//----------------------------------------------------------------------
//  Task 0 —— face 模块延迟审计（实测）
//
//  方法：给同一路行扫描激励（WIDTH=1280，行间 de 拉低 1 拍），
//        在每一级输出侧记录 "de 首个有效拍" 的时刻。
//        同一级内 de 通路是纯打拍，所以输出 de 的起始相位
//        就等于该级引入的额外延迟。
//
//  为什么用 de 相位而不是"标定像素"：
//        low_pass 是 7x7 多数滤波，单像素标定点会被滤除；
//        morph 是腐蚀，单点同样会被吃掉。
//        用 de 的上升沿相位测则与被处理数据无关，最稳。
//
//  绝对拍数怎么定：
//        另跑一个"零延迟基准"——一个只做 de_out<=de_in 的哑模块，
//        它的 de 上升沿就是 1 拍。用它把时间换算成拍数。
//======================================================================

module audit_face_latency_tb;

    localparam integer WIDTH     = 1280;
    localparam integer ROWS      = 16;      // 喂 16 行
    localparam integer CLK_HALF  = 5;       // 10ns 周期

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #CLK_HALF clk = ~clk;

    integer err = 0;

    //------------------------------------------------------------------
    // 激励
    //------------------------------------------------------------------
    reg          de_i;
    reg  [10:0]  x_i;
    reg  [9:0]   y_i;
    reg          bin_i;
    reg          vs_i;

    //------------------------------------------------------------------
    // 基准尺：1 拍延迟的哑模块
    //------------------------------------------------------------------
    reg base_de;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) base_de <= 1'b0; else base_de <= de_i;

    //------------------------------------------------------------------
    // 被测 1：low_pass_realtime
    //------------------------------------------------------------------
    wire lpf_out, lpf_v;
    low_pass_realtime #(.WIDTH(WIDTH), .DEPTH(720), .RADIUS(3), .THRESH(15))
      u_lpf (
        .clk(clk), .pixel_valid(de_i), .binary_input(bin_i),
        .pixel_x(x_i), .pixel_y(y_i),
        .filtered_output(lpf_out), .output_valid(lpf_v)
      );

    //------------------------------------------------------------------
    // 被测 2/3：morph_erode3x3_stream，break_en 分别 0 / 1
    //------------------------------------------------------------------
    wire        mor0_out, mor0_v;
    wire        mor1_out, mor1_v;

    morph_erode3x3_stream #(.WIDTH(WIDTH), .V_OPEN_LEN(9))
      u_mor_erode (
        .clk(clk), .rst_n(rst_n), .vs_in(vs_i),
        .de_in(de_i), .bin_in(bin_i), .break_en_i(1'b0),
        .erode_out(mor0_out), .erode_valid(mor0_v)
      );

    morph_erode3x3_stream #(.WIDTH(WIDTH), .V_OPEN_LEN(9))
      u_mor_open (
        .clk(clk), .rst_n(rst_n), .vs_in(vs_i),
        .de_in(de_i), .bin_in(bin_i), .break_en_i(1'b1),
        .erode_out(mor1_out), .erode_valid(mor1_v)
      );

    //------------------------------------------------------------------
    // 被测 4：bbox_overlay（空 bbox 表，只看 de 通路相位）
    //------------------------------------------------------------------
    wire [23:0] ov_rgb;
    wire        ov_de, ov_vs, ov_hs;

    bbox_overlay #(.WIDTH(WIDTH), .HEIGHT(720), .MAX_BLOBS(16), .THICKNESS(2))
      u_ov (
        .clk(clk), .rst_n(rst_n),
        .rgb_in(24'h123456), .de_in(de_i), .vs_in(vs_i), .hs_in(1'b0),
        .x_in(x_i), .y_in(y_i),
        .blob_count(6'd0), .addr_out(),
        .bbox_min_x(11'd0), .bbox_max_x(11'd0),
        .bbox_min_y(10'd0), .bbox_max_y(10'd0),
        .bbox_valid(1'b0),
        .rgb_out(ov_rgb), .de_out(ov_de), .vs_out(ov_vs), .hs_out(ov_hs),
        .pending_swap()
      );

    //------------------------------------------------------------------
    // 采样首批 de 有效时刻
    //------------------------------------------------------------------
    integer t_base, t_lpf, t_mor3, t_morv, t_ov;
    reg     armed;                 // 复位后开始计数

    always @(posedge clk) begin
        if (armed) begin
            if (base_de && t_base < 0) t_base = $time;
            if (lpf_v   && t_lpf  < 0) t_lpf  = $time;
            if (mor0_v  && t_mor3 < 0) t_mor3 = $time;
            if (mor1_v  && t_morv < 0) t_morv = $time;
            if (ov_de   && t_ov   < 0) t_ov   = $time;
        end
    end

    //------------------------------------------------------------------
    // 激励主流程
    //------------------------------------------------------------------
    integer r, c;

    initial begin
        de_i = 0; x_i = 0; y_i = 0; bin_i = 0; vs_i = 0;
        armed = 1'b0;
        t_base = -1; t_lpf = -1; t_mor3 = -1; t_morv = -1; t_ov = -1;

        $display("================================================");
        $display(" Task 0: face 模块延迟实测");
        $display("================================================");

        repeat(4) @(negedge clk);
        rst_n = 1'b1;
        repeat(2) @(negedge clk);

        // VS 上升沿清 row_ready
        vs_i = 1'b1; @(negedge clk); vs_i = 1'b0; @(negedge clk);

        armed = 1'b1;

        // 喂 ROWS 行，全 1（保证腐蚀后仍有输出；多数滤波也能过）
        for (r = 0; r < ROWS; r = r + 1) begin
            for (c = 0; c < WIDTH; c = c + 1) begin
                @(negedge clk);
                de_i = 1'b1; x_i = c[10:0]; y_i = r[9:0]; bin_i = 1'b1;
            end
            @(negedge clk);
            de_i = 1'b0; bin_i = 1'b0;      // 行间 de 下拉，供 row_ready 计数
        end

        repeat(20) @(negedge clk);
        armed = 1'b0;

        //------------------------------------------------------------------
        // 报告
        //------------------------------------------------------------------
        $display("");
        $display("  实测首批 de/valid 时刻（$time, ns）:");
        $display("    base  (1 拍基准尺)        : %0t", t_base);
        $display("    low_pass_realtime         : %0t", t_lpf);
        $display("    morph 腐蚀路径 (brk=0)     : %0t", t_mor3);
        $display("    morph 垂直开运算 (brk=1)   : %0t", t_morv);
        $display("    bbox_overlay              : %0t", t_ov);
        $display("");

        begin : CALC
            integer cyc;
            integer d_lpf, d_mor3, d_morv, d_ov;
            cyc = 2 * CLK_HALF;   // 一个时钟周期 ns
            d_lpf  = (t_lpf  - t_base) / cyc;
            d_mor3 = (t_mor3 - t_base) / cyc;
            d_morv = (t_morv - t_base) / cyc;
            d_ov   = (t_ov   - t_base) / cyc;

            $display("  相对 base(1 拍) 的额外延迟：");
            $display("    low_pass_realtime         : %0d 拍 (含 base 的 1 拍)", d_lpf + 1);
            $display("    morph 腐蚀路径 (brk=0)     : %0d 拍 (含 base 的 1 拍)", d_mor3 + 1);
            $display("    morph 垂直开运算 (brk=1)   : %0d 拍 (含 base 的 1 拍)", d_morv + 1);
            $display("    bbox_overlay              : %0d 拍 (含 base 的 1 拍)", d_ov + 1);
            $display("");

            // 一致性检查
            if (d_ov + 1 != 1) begin
                $display("  WARN: bbox_overlay 应为 1 拍，实测 %0d 拍", d_ov + 1);
                err = err + 1;
            end
            if (d_lpf <= 0) begin
                $display("  WARN: low_pass 延迟应 >0");
                err = err + 1;
            end
            $display("  err = %0d", err);
        end

        $display("================================================");
        $finish;
    end

    initial begin
        #20000000;
        $display("TIMEOUT err=%0d", err);
        $finish;
    end

endmodule
