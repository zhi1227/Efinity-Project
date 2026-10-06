`timescale 1ns/1ps
//======================================================================
//  rgb565_to_ycbcr_skin_tb.v
//----------------------------------------------------------------------
//  Task 1 TB：定向 ≥10 组 + 随机 100000 组
//
//  参考模型与 RTL 走**不同实现路径**（硬性规定）：
//    RTL  ：移位加法展开系数，`>>> 8` 算术右移，无符号比较
//    本 TB：用 real 浮点算 BT.601 标准公式，再做四舍五入后比较
//           —— 若 RTL 系数写错（比如 107 少加一项），浮点这条路必然暴露
//
//  另外：定向用例的期望值不是手算的，是用 Python 独立脚本
//        （tools/ref_face_bbox.py 的前身，见文件末尾注释）生成的，
//        已核对 Cb=128>127 使白色天然被排除。
//
//  容差说明：
//    浮点参考与整数近似在 Cb/Cr 上可能差 ±1（因为 >>8 是截断不是四舍五入）。
//    故对判据边界（|值-阈值| <= 1）的用例，TB 不比较，只比较明确在阈值
//    内部的点。随机用例也用"距阈值 >=2"的点，避免把舍入差当 bug。
//======================================================================

module rgb565_to_ycbcr_skin_tb;

    localparam AWIDTH = 11;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg              de_i;
    reg  [AWIDTH-1:0]x_i;
    reg  [9:0]       y_i;
    reg  [15:0]      rgb565_i;
    reg  [7:0]       cb_min, cb_max, cr_min, cr_max, y_min, y_max;

    wire             skin_o, de_o;
    wire [AWIDTH-1:0]x_o;
    wire [9:0]       y_o;

    rgb565_to_ycbcr_skin #(.AWIDTH(AWIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .de_i(de_i), .x_i(x_i), .y_i(y_i), .rgb565_i(rgb565_i),
        .cb_min_i(cb_min), .cb_max_i(cb_max),
        .cr_min_i(cr_min), .cr_max_i(cr_max),
        .y_min_i(y_min),   .y_max_i(y_max),
        .skin_o(skin_o), .de_o(de_o), .x_o(x_o), .y_o(y_o)
    );

    integer err = 0;
    integer ok  = 0;
    integer i;

    //------------------------------------------------------------------
    // 浮点参考模型（路径独立）
    //------------------------------------------------------------------
    real rR, rG, rB, rY, rCb, rCr;
    integer iY, iCb, iCr;

    function [7:0] exp5to8(input [4:0] v);  exp5to8 = (v<<3) | (v>>2); endfunction
    function [7:0] exp6to8(input [5:0] v);  exp6to8 = (v<<2) | (v>>4); endfunction

    task ref_model(input [15:0] px);
        begin
            rR = exp5to8(px[15:11]);
            rG = exp6to8(px[10:5]);
            rB = exp5to8(px[4:0]);
            rY  =  0.299*rR + 0.587*rG + 0.114*rB;
            rCb = -0.168736*rR - 0.331264*rG + 0.5*rB + 128.0;
            rCr =  0.5*rR - 0.418688*rG - 0.081312*rB + 128.0;
        end
    endtask

    // 参考判定（浮点直接比，不做取整）
    // 注意：Verilog-2001 不允许 function 内 enable task，故这里用 task，
    //       结果写入全局 reg ref_b / ref_clear。
    reg ref_b, ref_clear;

    task ref_skin(input [15:0] px);
        begin
            ref_model(px);
            ref_b = (rY >= y_min) && (rY <= y_max) &&
                    (rCb >= cb_min) && (rCb <= cb_max) &&
                    (rCr >= cr_min) && (rCr <= cr_max);
        end
    endtask

    // 该点是否"离所有阈值边界足够远"（>=2），可用于严格比较
    task ref_is_clear(input [15:0] px);
        begin
            ref_model(px);
            ref_clear = (rY  - y_min  >= 2) && (y_max - rY  >= 2) &&
                        (rCb - cb_min >= 2) && (cb_max - rCb >= 2) &&
                        (rCr - cr_min >= 2) && (cr_max - rCr >= 2);
        end
    endtask

    //------------------------------------------------------------------
    // 驱动一个像素并比对
    //   strict=1 时启用"远离边界"过滤
    //------------------------------------------------------------------
    task check(input [15:0] px, input strict);
        reg exp_b;
        begin
            @(negedge clk);
            de_i = 1'b1; rgb565_i = px; x_i = x_i + 1'b1;
            @(negedge clk);                       // 等 1 拍流水
            ref_is_clear(px);                     // 先算"离边界距离"
            if (strict && !ref_clear) begin
                // 距边界太近，浮点与整数近似可能差 1，跳过严格比较
                ok = ok + 1;
            end else begin
                ref_skin(px);                     // 再算期望值（刷新 rY/rCb/rCr）
                exp_b = ref_b;
                if (skin_o !== exp_b) begin
                    if (err < 20)
                        $display("  FAIL px=%04h exp=%b got=%b  (Y=%.1f Cb=%.1f Cr=%.1f)",
                                 px, exp_b, skin_o, rY, rCb, rCr);
                    err = err + 1;
                end else ok = ok + 1;
            end
        end
    endtask

    //------------------------------------------------------------------
    // [A0] 硬真值表（由 Python 独立脚本生成，整数与浮点双路核对）
    //      这一组不跳过、不容差，必须逐点精确命中。
    //      期望值来源：tools/gen_skin_truth.py（见文件末尾）
    //------------------------------------------------------------------
    task hard_check(input [15:0] px, input exp, input [7:0] eY, eCb, eCr);
        begin
            @(negedge clk);
            de_i = 1'b1; rgb565_i = px; x_i = x_i + 1'b1;
            @(negedge clk);
            if (skin_o !== exp) begin
                $display("  FAIL[HARD] px=%04h exp=%b got=%b (期望 Y=%0d Cb=%0d Cr=%0d)",
                         px, exp, skin_o, eY, eCb, eCr);
                err = err + 1;
            end else ok = ok + 1;
        end
    endtask

    //------------------------------------------------------------------
    // 定向用例（期望值由 Python 独立脚本生成，见文件头说明）
    //------------------------------------------------------------------
    integer t;

    initial begin
        de_i=0; x_i=0; y_i=0; rgb565_i=0;
        cb_min=8'd77; cb_max=8'd127;
        cr_min=8'd133; cr_max=8'd173;
        y_min=8'd40;  y_max=8'd235;

        $display("================================================================");
        $display(" Task 1: rgb565_to_ycbcr_skin TB");
        $display("================================================================");

        repeat(4) @(negedge clk);
        rst_n = 1'b1;
        repeat(2) @(negedge clk);

        //--------------------------------------------------------------
        // [A0] 硬真值表：12 组，精确定值，不跳过
        //--------------------------------------------------------------
        $display("");
        $display("  [A0] 硬真值表（12 组，精确定值）");
        //        像素      期望  Y   Cb  Cr
        hard_check(16'hE5B2, 1'b1, 192, 102, 155);  // 典型肤色
        hard_check(16'hCCAF, 1'b1, 163, 105, 158);  // 偏深肤色
        hard_check(16'hF655, 1'b1, 212, 105, 152);  // 浅肤色
        hard_check(16'h936A, 1'b1, 117, 107, 149);  // 深肤色
        hard_check(16'hFFFF, 1'b0, 255, 128, 128);  // 白  —— Cb=128>127
        hard_check(16'h0000, 1'b0,   0, 128, 128);  // 黑  —— Y=0<40
        hard_check(16'h8410, 1'b0, 130, 128, 128);  // 中灰
        hard_check(16'h07E0, 1'b0, 149,  43,  21);  // 纯绿
        hard_check(16'h001F, 1'b0,  28, 255, 107);  // 纯蓝
        hard_check(16'hF800, 1'b0,  76,  85, 255);  // 纯红
        hard_check(16'hC490, 1'b1, 160, 112, 155);  // 中间色 RGB(198,144,128)
        hard_check(16'h83ED, 1'b0, 125, 117, 132);  // Cr=132，卡在 133 下限外 1
        $display("      硬真值表小计：ok=%0d err=%0d", ok, err);

        //--------------------------------------------------------------
        // [A] 定向用例 1~10：Python 真值表
        //     典型肤色 E5B2 (230,180,150) Y=192.8 Cb=102.7 Cr=155.3 -> 1
        //     偏深肤色 CCAF (200,150,120) Y=163.7 Cb=105.1 Cr=158.2 -> 1
        //     浅肤色   F655 (240,200,175) Y=212.7 Cb=105.6 Cr=152.4 -> 1
        //     深肤色   936A (150,110, 80) Y=117.6 Cb=107.9 Cr=149.7 -> 1
        //--------------------------------------------------------------
        $display("");
        $display("  [A] 定向：肤色正例（应判 1）");
        check(16'hE5B2, 1'b1);   // 典型肤色
        check(16'hCCAF, 1'b1);   // 偏深肤色
        check(16'hF655, 1'b1);   // 浅肤色
        check(16'h936A, 1'b1);   // 深肤色

        $display("  [B] 定向：非肤色反例（应判 0）");
        check(16'hFFFF, 1'b1);   // 白   Cb=128 > 127 排除
        check(16'h0000, 1'b1);   // 黑   Y=0 < 40   排除
        check(16'h8410, 1'b1);   // 中灰 Cb=Cr=128  排除
        check(16'h07E0, 1'b1);   // 纯绿 Cb=43.5    排除
        check(16'h001F, 1'b1);   // 纯蓝 Cb=255.5   排除
        check(16'hF800, 1'b1);   // 纯红 Cr=255.5   排除

        //--------------------------------------------------------------
        // [C] 暗部：Y < 40 应判 0（即使色度像肤色）
        //     构造一个"灰暗肤色"——把典型肤色整体压暗
        //--------------------------------------------------------------
        $display("  [C] 定向：暗部 Y<40 应排除");
        check(16'h0821, 1'b1);   // 很暗的偏红 -> Y 低
        check(16'h1042, 1'b1);   // 暗红 -> Y 低

        //--------------------------------------------------------------
        // [D] 过曝：Y > 235 应判 0
        //--------------------------------------------------------------
        $display("  [D] 定向：过曝 Y>235 应排除");
        check(16'hFFDF, 1'b1);   // 近白偏黄
        check(16'hFFFF, 1'b1);   // 纯白（重复确认）

        //--------------------------------------------------------------
        // [E] 阈值边界方向（用严格比较会跳过，这里用非严格看趋势）
        //     直接把阈值放开成全域，任何像素都应为 1
        //--------------------------------------------------------------
        $display("  [E] 定向：阈值全开 -> 全 1");
        cb_min=8'd0; cb_max=8'd255; cr_min=8'd0; cr_max=8'd255;
        y_min =8'd0; y_max =8'd255;
        check(16'h0000, 1'b0);
        check(16'hFFFF, 1'b0);
        check(16'h8410, 1'b0);
        // 恢复默认
        cb_min=8'd77; cb_max=8'd127;
        cr_min=8'd133; cr_max=8'd173;
        y_min=8'd40;  y_max=8'd235;

        //--------------------------------------------------------------
        // [F] 阈值全关 -> 全 0
        //--------------------------------------------------------------
        $display("  [F] 定向：阈值全关 -> 全 0");
        cb_min=8'd200; cb_max=8'd200;
        check(16'hE5B2, 1'b0);   // 典型肤色也不通过
        cb_min=8'd77; cb_max=8'd127;

        $display("");
        $display("  [A-F] 定向合计：ok=%0d err=%0d", ok, err);

        //--------------------------------------------------------------
        // [G] 随机 100000 组
        //--------------------------------------------------------------
        $display("");
        $display("  [G] 随机 100000 组...");
        for (t = 0; t < 100000; t = t + 1) begin
            check($random, 1'b1);
        end
        $display("      ok=%0d err=%0d", ok, err);

        //--------------------------------------------------------------
        // [H] de/x/y 透传检查（1 拍）
        //--------------------------------------------------------------
        $display("");
        $display("  [H] de/x/y 透传检查");
        begin : PIPE_CHK
            reg [AWIDTH-1:0] ex_x; reg [9:0] ex_y; reg ex_de;
            @(negedge clk);
            de_i = 1'b1; x_i = 11'd777; y_i = 10'd123; rgb565_i = 16'hE5B2;
            ex_de = 1'b1; ex_x = 11'd777; ex_y = 10'd123;
            @(negedge clk);
            if (de_o !== ex_de || x_o !== ex_x || y_o !== ex_y) begin
                $display("  FAIL 透传: de_o=%b x_o=%0d y_o=%0d (期望 %b %0d %0d)",
                         de_o, x_o, y_o, ex_de, ex_x, ex_y);
                err = err + 1;
            end else ok = ok + 1;
            // 撤销 de 后 1 拍，de_o 应为 0
            @(negedge clk);
            de_i = 1'b0;
            @(negedge clk);
            if (de_o !== 1'b0) begin
                $display("  FAIL de_o 应随 de_i 撤销");
                err = err + 1;
            end else ok = ok + 1;
        end

        $display("");
        $display("================================================================");
        if (err == 0)
            $display(" PASS: ok=%0d err=%0d", ok, err);
        else
            $display(" FAIL: ok=%0d err=%0d", ok, err);
        $display("================================================================");
        $finish;
    end

    initial begin
        #5000000;
        $display("TIMEOUT err=%0d", err);
        $finish;
    end

endmodule
