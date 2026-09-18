// 720p紧凑度评估模块（标量评估，流式友好）
// 输入面积与周长，计算 score = (area * 125) / (perimeter * perimeter)
// 与 MIN_COMPACTNESS(×10) 比较：score > MIN_COMPACTNESS 视为通过
module compactness_eval_720p #(
    parameter MIN_COMPACTNESS = 3,   // 最小紧凑度 (0.3 * 10)
    parameter MIN_AREA = 50          // 最小面积
) (
    input        clk,
    input        rst_n,
    input        valid_in,                 // 输入有效（区域可评估）
    input [15:0] area_in,                  // 区域面积
    input [15:0] perimeter_in,             // 区域周长
    output reg   compactness_passed,       // 紧凑度通过
    output reg   done                      // 完成标志
);

reg [31:0] numerator;                      // area * 125
reg [31:0] denominator;                    // perimeter * perimeter
reg [31:0] score;                          // 定点×10得分

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        compactness_passed <= 1'b0;
        done <= 1'b0;
        numerator <= 32'd0;
        denominator <= 32'd0;
        score <= 32'd0;
    end else begin
        done <= 1'b0;
        if (valid_in) begin
            // 保护：面积与周长阈值
            if (perimeter_in == 16'd0 || area_in < MIN_AREA) begin
                compactness_passed <= 1'b0;
                done <= 1'b1;
            end else begin
                numerator <= area_in * 32'd125; // 125 ≈ 4π*10
                denominator <= perimeter_in * perimeter_in;
                // 简单一拍计算，下一拍出结果（本实现一拍完成）
                score <= (area_in * 32'd125) / (perimeter_in * perimeter_in);
                compactness_passed <= (score > MIN_COMPACTNESS);
                done <= 1'b1;
            end
        end
    end
end

endmodule


