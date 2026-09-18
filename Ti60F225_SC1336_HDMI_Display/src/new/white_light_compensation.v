// Auto White Balance (frame-end update)
// - Accumulate R/G/B over the frame (pix_en=1)
// - At frame end (f_end falling edge): Average = Sum * (1/N)  [N = IMAGE_W*IMAGE_H]
// - Next cycle: lookup reciprocal(average) and latch gains
// - Apply gains to current pixels with saturation
module awb_design #(
    // 请按你的真实有效分辨率设置（默认 1280x720）
    parameter integer IMAGE_W = 1280,
    parameter integer IMAGE_H = 720,

    // 新增：通道强度系数 K（0..127）。原逻辑是 <<7 (=×128)。
    // 这里改为 ×K（<=127），从而“减弱白平衡拉动幅度”。
    // 建议起始：K_R=120（略暖肤色），K_G=112，K_B=108~112（避免偏冷）。
    parameter integer K_R = 120,
    parameter integer K_G = 112,
    parameter integer K_B = 112
)(
    input  wire        Clk,
    input  wire        Rst,        // active-high reset（保持原语义）

    input  wire        f_end,      // 帧有效信号（高电平表示帧内），用其下降沿作为帧结束
    input  wire        l_end,      // 行结束（未使用，仅透传）
    input  wire        pix_en,     // 像素有效
    input  wire [7:0]  iR,
    input  wire [7:0]  iG,
    input  wire [7:0]  iB,

    output reg         f_end_o,
    output reg         l_end_o,
    output reg         pix_en_o,
    output wire [7:0]  oR,
    output wire [7:0]  oG,
    output wire [7:0]  oB
);
    // --------------- VS 边沿 ---------------
    reg f_d0, f_d1;
    always @(posedge Clk or negedge Rst) begin
        if (!Rst) begin
            f_d0 <= 1'b0; f_d1 <= 1'b0;
        end else begin
            f_d0 <= f_end;
            f_d1 <= f_d0;
        end
    end
    wire f_rise =  f_d0 & ~f_d1;   // 帧开始
    wire f_fall = ~f_d0 &  f_d1;   // 帧结束

    // --------------- 累加器 ---------------
    reg [31:0] AccR, AccG, AccB;
    always @(posedge Clk or negedge Rst) begin
        if (!Rst) begin
            AccR <= 32'd0; AccG <= 32'd0; AccB <= 32'd0;
        end else begin
            if (f_rise) begin
                AccR <= 32'd0; AccG <= 32'd0; AccB <= 32'd0;
            end else if (pix_en) begin
                AccR <= AccR + iR;
                AccG <= AccG + iG;
                AccB <= AccB + iB;
            end
        end
    end

    // --------------- 图像像素倒数常数 Q1.31 ---------------
    // INV_PIX_Q31 = 2^31 / (IMAGE_W*IMAGE_H)
    localparam integer PIXELS = IMAGE_W * IMAGE_H;
    localparam [31:0] INV_PIX_Q31 = 32'h8000_0000 / PIXELS;

    // --------------- 帧末计算均值并锁存 ---------------
    // Product: 32b * 32b -> 64b; Q33.31
    wire [63:0] avgR_prod = AccR * INV_PIX_Q31;
    wire [63:0] avgG_prod = AccG * INV_PIX_Q31;
    wire [63:0] avgB_prod = AccB * INV_PIX_Q31;

    reg  [7:0] AverageR, AverageG, AverageB;   // 帧级均值（0..255）
    reg        avg_latched;                    // 均值已更新打一拍

    always @(posedge Clk or negedge Rst) begin
        if (!Rst) begin
            AverageR   <= 8'd1;
            AverageG   <= 8'd1;
            AverageB   <= 8'd1;
            avg_latched<= 1'b0;
        end else begin
            // 在帧结束沿锁存本帧均值（取 Q33.31 的整数位 [38:31]）
            if (f_fall) begin
                AverageR <= (avgR_prod[38:31] == 8'd0) ? 8'd1 : avgR_prod[38:31];
                AverageG <= (avgG_prod[38:31] == 8'd0) ? 8'd1 : avgG_prod[38:31];
                AverageB <= (avgB_prod[38:31] == 8'd0) ? 8'd1 : avgB_prod[38:31];
                avg_latched <= 1'b1; // 下一拍锁增益
            end else begin
                avg_latched <= 1'b0;
            end
        end
    end

    // --------------- 倒数查表（组合） ---------------
    wire [31:0] AverageR_recip, AverageG_recip, AverageB_recip;
    Reciprocal Reciprocal_R(.Average(AverageR), .Recip(AverageR_recip));
    Reciprocal Reciprocal_G(.Average(AverageG), .Recip(AverageG_recip));
    Reciprocal Reciprocal_B(.Average(AverageB), .Recip(AverageB_recip));

    // --------------- 帧级增益寄存（幅度可调，轻微偏暖） ---------------
    // 原版：Rgain/Ggain/Bgain = reciprocal << 7  （即 ×128，把通道均值拉到 128）
    // 本版：改为 reciprocal × K_* （其中 K_* ∈ [0..127]），将“×128”弱化为“×K_*”
    // 注意：32位 * 7位 = 39位，正好适配 Rgain/Ggain/Bgain 的 39bit 定义，无需改位宽。
    wire [6:0] KR7 = (K_R > 127) ? 7'd127 : K_R[6:0];
    wire [6:0] KG7 = (K_G > 127) ? 7'd127 : K_G[6:0];
    wire [6:0] KB7 = (K_B > 127) ? 7'd127 : K_B[6:0];

    reg [38:0] Rgain, Ggain, Bgain;
    always @(posedge Clk or negedge Rst) begin
        if (!Rst) begin
            // 初值不影响稳定后行为，保持原注释“初值=1.0”
            Rgain <= {32'd256,7'd0};
            Ggain <= {32'd256,7'd0};
            Bgain <= {32'd256,7'd0};
        end else begin
            if (avg_latched) begin
                // 原来是 {Average*_recip,7'd0}（×128），现在改为 *K_*（≤127）
                // 这样 oX ≈ iX * (K_*/AverageX)。K_* 略小于 128 → 幅度更小，不易过曝；
                // 且 K_R > K_G ≥ K_B → 画面略偏暖，更讨好肤色。
                Rgain <= AverageR_recip * KR7; // 32b*7b=39b
                Ggain <= AverageG_recip * KG7;
                Bgain <= AverageB_recip * KB7;
            end
        end
    end

    // --------------- 应用增益并饱和 ---------------
    wire [40:0] oRTemp = iR * Rgain;
    wire [40:0] oGTemp = iG * Ggain;
    wire [40:0] oBTemp = iB * Bgain;

    // 与原写法兼容：用高位判溢，再取 [38:31] 作为 8bit
    assign oR = (oRTemp[40:31] > 10'd255) ? 8'd255 : oRTemp[38:31];
    assign oG = (oGTemp[40:31] > 10'd255) ? 8'd255 : oGTemp[38:31];
    assign oB = (oBTemp[40:31] > 10'd255) ? 8'd255 : oBTemp[38:31];

    // --------------- 控制信号透传（1T） ---------------
    always @(posedge Clk or negedge Rst) begin
        if (!Rst) begin
            f_end_o <= 1'b0; l_end_o <= 1'b0; pix_en_o <= 1'b0;
        end else begin
            f_end_o <= f_end;
            l_end_o <= l_end;
            pix_en_o<= pix_en;
        end
    end
endmodule