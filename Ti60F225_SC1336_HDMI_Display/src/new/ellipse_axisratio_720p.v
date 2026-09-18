// 二阶矩轴比评估模块（流式友好，适配720p）
// 思路：使用区域的二阶原始矩（Σx, Σy, Σx², Σy², Σxy）构造协方差矩阵的无尺度形式
//       M = [[mxx, mxy], [mxy, myy]]，其中：
//       mxx = A*Σx² - (Σx)^2；myy = A*Σy² - (Σy)^2；mxy = A*Σxy - (Σx)(Σy)
// 该矩阵与真实协方差矩阵成比例，主/次特征值之比与比例无关。
// 轴比≈sqrt(λ1/λ2)。为避免开方，比较 λ1 与 (ratio^2)*λ2。

module ellipse_axisratio_720p #(
    parameter MIN_RATIO_X10 = 10,  // 最小轴比×10（例如1.0 -> 10）
    parameter MAX_RATIO_X10 = 16   // 最大轴比×10（例如1.6 -> 16）
) (
    input        clk,
    input        rst_n,
    input        valid_in,          // 输入有效（区域可评估）
    input [19:0] area_in,           // 区域面积（支持至~1M）
    // 原始矩输入（建议由连通域阶段同步累加产生，坐标为像素索引）
    input [47:0] sum_x,             
    input [47:0] sum_y,             
    input [47:0] sum_xx,            
    input [47:0] sum_yy,            
    input [47:0] sum_xy,            
    output reg   axisratio_pass,    // 轴比通过
    output reg   done               // 完成标志
);

// 声明内部变量（模块级别）
reg [63:0] mxx, myy, mxy;           // 无尺度二阶矩（放大量级）
reg [31:0] ms_xx, ms_yy, ms_xy;     // 缩放后的二阶矩（避免乘法溢出）
reg [31:0] trace_s;                 // 缩放后迹
reg [31:0] d_abs;                   // 
reg [63:0] d2;                      // 
reg [63:0] xy2_4;                   // 
reg [63:0] delta_sq;                // 
reg [31:0] delta;                   // 
reg [31:0] lambda1, lambda2;        // 缩放后特征值

// 牛顿迭代变量（模块级别）
reg [31:0] x, x_next;

// 轴比判定变量（模块级别）
reg [63:0] lhs, rhs_min, rhs_max;

// 比较用的(ratio^2)×100（因为 ratio 以×10给出）
localparam [15:0] MIN_R2_X100 = MIN_RATIO_X10 * MIN_RATIO_X10; // (min*10)^2 = min^2 * 100
localparam [15:0] MAX_R2_X100 = MAX_RATIO_X10 * MAX_RATIO_X10; // (max*10)^2 = max^2 * 100

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        axisratio_pass <= 1'b0;
        done <= 1'b0;
        mxx <= 64'd0; myy <= 64'd0; mxy <= 64'd0;
        ms_xx <= 32'd0; ms_yy <= 32'd0; ms_xy <= 32'd0;
        trace_s <= 32'd0; d_abs <= 32'd0; d2 <= 64'd0; xy2_4 <= 64'd0;
        delta_sq <= 64'd0; delta <= 32'd0; lambda1 <= 32'd0; lambda2 <= 32'd0;
        x <= 32'd0; x_next <= 32'd0;
        lhs <= 64'd0; rhs_min <= 64'd0; rhs_max <= 64'd0;
    end else begin
        done <= 1'b0;
        axisratio_pass <= 1'b0;
        if (valid_in) begin
            if (area_in == 0) begin
                axisratio_pass <= 1'b0;
                done <= 1'b1;
            end else begin
                // 计算无尺度二阶矩
                // 
                mxx <= area_in * sum_xx - (sum_x * sum_x);
                myy <= area_in * sum_yy - (sum_y * sum_y);
                mxy <= area_in * sum_xy - (sum_x * sum_y);

                // 简单夹紧避免负数（数值抖动）
                // 同时做固定比例缩放到32位（右移S位），S取16以留乘法余量
                // 注意：这里用阻塞式组合到下一拍用更稳健，当前写法两拍稳定
            end
        end else begin
            // 第二拍：缩放并计算特征值近似
            // 右移16位缩放（防溢出），防止后续平方溢出
            ms_xx <= (mxx[63:16] != 0) ? mxx[47:16] : mxx[31:0]; // 粗略压缩
            ms_yy <= (myy[63:16] != 0) ? myy[47:16] : myy[31:0];
            ms_xy <= (mxy[63:16] != 0) ? mxy[47:16] : mxy[31:0];

            // Δ = sqrt((ms_xx - ms_yy)^2 + 4*ms_xy^2) 使用牛顿迭代开方（内联）
            if (ms_xx >= ms_yy) d_abs <= ms_xx - ms_yy; else d_abs <= ms_yy - ms_xx;
            d2 <= {32'd0, d_abs} * {32'd0, d_abs};
            xy2_4 <= ({32'd0, ms_xy} * {32'd0, ms_xy}) << 2; // *4
            delta_sq <= d2 + xy2_4;

            // 牛顿迭代计算开方（展开8次迭代以接近原版）
            x = (delta_sq[63:32] != 0) ? 32'hFFFF : 32'hFF;  // 初始估计
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            x_next = (x == 0) ? 1 : (x + (delta_sq / x)) >> 1;
            x = x_next;
            delta <= x;  // 最终结果

            trace_s <= ms_xx + ms_yy;
            // λ1,2 = (trace ± Δ)/2（结果仍是缩放空间的值）
            lambda1 <= (trace_s + delta) >> 1;
            lambda2 <= (trace_s > delta) ? ((trace_s - delta) >> 1) : 32'd0;

            // 轴比判定：λ1 与 (ratio^2)*λ2 比较；为避免小数，使用 ×100 标度
            // 判定条件：
            //   MIN: λ1*100 >= MIN_R2_X100 * λ2
            //   MAX: λ1*100 <= MAX_R2_X100 * λ2
            if (lambda2 == 0) begin
                axisratio_pass <= 1'b0; // 退化
            end else begin
                lhs = {32'd0, lambda1} * {32'd0, 32'd100};
                rhs_min = {32'd0, lambda2} * {32'd0, MIN_R2_X100};
                rhs_max = {32'd0, lambda2} * {32'd0, MAX_R2_X100};
                axisratio_pass <= (lhs >= rhs_min) && (lhs <= rhs_max);
            end
            done <= 1'b1;
        end
    end
end

endmodule


