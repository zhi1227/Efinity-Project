module face_reader_720p #(
    parameter COLOR_DEPTH = 8        // 颜色位深
) (
    // RGB输入
    input [COLOR_DEPTH-1:0] image_in_R, image_in_G, image_in_B,
    // 坐标输入（由HDMI模块提供）
    input [10:0] pixel_x, pixel_y,   // 像素坐标（11位和10位）
    input pixel_valid,               // 像素有效信号
    input clk,                       // 时钟信号
    
    // 输出
    output reg binary_output,        // 二值化输出（1位）
    output reg output_valid          // 输出有效信号
);

    // YUV颜色空间转换公式
    // Y = (R+2G+B)/4
    // U = R - G
    // V = B - G 
    wire [COLOR_DEPTH-1:0] U;  // U分量
    // 计算U分量，检查下溢
    assign U = image_in_R < image_in_G ? 0 : image_in_R - image_in_G;

    // 实时肤色检测逻辑
    always @(posedge clk) begin
        if (pixel_valid) begin
            // 肤色检测：U分量在26-74范围内判定为肤色
            if (U > 10 && U < 90) begin
                binary_output <= 1'b1;  // 输出1（肤色）
            end else begin
                binary_output <= 1'b0;  // 输出0（非肤色）
            end
            output_valid <= 1'b1;       // 设置输出有效
        end else begin
            output_valid <= 1'b0;       // 清除输出有效
        end
    end

endmodule
