// 720p椭圆拟合检测模块（简化版本）
// 基于边界框的简单椭圆拟合，用于替代复杂的轮廓拟合
module ellipse_fitting_720p #(
    parameter MIN_ELLIPSE_RATIO = 10,  // 最小椭圆比例×10 (1.0)
    parameter MAX_ELLIPSE_RATIO = 16   // 最大椭圆比例×10 (1.6)
) (
    input clk,
    input rst_n,
    input binary_region,              // 二值化区域（未使用，简化版本）
    input [10:0] region_min_x, region_max_x,
    input [9:0] region_min_y, region_max_y,
    input region_valid,
    output reg ellipse_passed,
    output reg filter_done
);

reg [10:0] width, height;
reg [15:0] ellipse_ratio_x10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ellipse_passed <= 1'b0;
        filter_done <= 1'b0;
        width <= 0;
        height <= 0;
        ellipse_ratio_x10 <= 0;
    end else begin
        filter_done <= 1'b0;
        if (region_valid) begin
            width <= region_max_x - region_min_x + 1;
            height <= region_max_y - region_min_y + 1;
            
            // 简化的椭圆比例计算：长边/短边
            if (width > height) begin
                ellipse_ratio_x10 <= (width * 10) / height;
            end else begin
                ellipse_ratio_x10 <= (height * 10) / width;
            end
            
            // 椭圆约束检查
            if (ellipse_ratio_x10 >= MIN_ELLIPSE_RATIO && ellipse_ratio_x10 <= MAX_ELLIPSE_RATIO) begin
                ellipse_passed <= 1'b1;
            end else begin
                ellipse_passed <= 1'b0;
            end
            filter_done <= 1'b1;
        end
    end
end

endmodule
