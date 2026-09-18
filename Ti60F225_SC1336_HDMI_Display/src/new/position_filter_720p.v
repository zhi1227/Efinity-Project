// 720p位置约束过滤模块
module position_filter_720p #(
    parameter IMAGE_HEIGHT = 720,     // 图像高度
    parameter MAX_Y_RATIO_X10 = 7     // 最大Y位置比例×10 (0.7)
) (
    input clk,
    input rst_n,
    input [9:0] bbox_min_y, bbox_max_y,
    input bbox_valid,
    output reg position_passed,
    output reg filter_done
);

reg [9:0] center_y;
reg [15:0] y_ratio_x10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        position_passed <= 1'b0;
        filter_done <= 1'b0;
        center_y <= 0;
        y_ratio_x10 <= 0;
    end else begin
        filter_done <= 1'b0;
        if (bbox_valid) begin
            center_y <= (bbox_min_y + bbox_max_y) >> 1;
            y_ratio_x10 <= (center_y * 10) / IMAGE_HEIGHT;
            
            // 位置约束：人脸通常在图像上半部分
            if (y_ratio_x10 <= MAX_Y_RATIO_X10) begin
                position_passed <= 1'b1;
            end else begin
                position_passed <= 1'b0;
            end
            filter_done <= 1'b1;
        end
    end
end

endmodule