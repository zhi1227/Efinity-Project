// 720p视频流增强人脸检测模块 - 针对1280x720分辨率优化
// 实现多目标检测、边界框计算和多重过滤
// 修改：输出单个bbox和index，使用BRAM存储
module enhanced_face_detector_720p #(
    parameter WIDTH = 1280,          // 720p图像宽度
    parameter DEPTH = 720,           // 720p图像高度
    parameter MAX_FACES = 16,        // 最大人脸数量（减少到16）
    parameter FILTER_SIZE = 5        // 滤波器大小
) (
    input clk,                       // 时钟信号
    input rst_n,                     // 复位信号（低有效）
    input [7:0] image_R, image_G, image_B,  // RGB输入
    input pixel_valid,               // 像素有效信号
    input [10:0] pixel_x, pixel_y,   // 像素坐标（扩展到11位支持1280）
    input frame_start, frame_end,    // 帧开始和结束信号
    
    // 输出单个bbox和index
    output reg [10:0] out_bbox_min_x,
    output reg [10:0] out_bbox_max_x,
    output reg [9:0] out_bbox_min_y,
    output reg [9:0] out_bbox_max_y,
    output reg [3:0] out_index,
    output reg out_valid    ,
    output reg [3:0] face_count_out  // 新增：输出face_count
);

// 内部信号定义
wire binary_output;                  // 二值化输出（1位）
wire binary_valid;                   // 二值化有效信号
wire filtered_output;                // 滤波后输出（1位二值化）
wire filtered_valid;                 // 滤波有效信号
wire [3:0] component_id;             // 组件ID（4位支持16个）
wire component_valid;                // 组件有效信号
wire [15:0] component_area_out;      // 组件面积输出
wire [15:0] component_perimeter_out; // 组件周长输出（流式）
// 二阶矩输出（用于椭圆轴比计算）      移出测试
//wire [47:0] sum_x_out, sum_y_out, sum_xx_out, sum_yy_out, sum_xy_out;

// 临时边界框变量（从cc_analyzer接收，改为wire）
wire [10:0] current_bbox_min_x;
wire [10:0] current_bbox_max_x;
wire [9:0] current_bbox_min_y;
wire [9:0] current_bbox_max_y;

// 实时过滤管道（流式处理）
// 几何约束过滤信号
wire geometric_pass;         // 几何约束通过信号
wire geometric_done;         // 几何约束完成信号

// 位置约束过滤信号
wire position_pass;          // 位置约束通过信号
wire position_done;          // 位置约束完成信号

// 椭圆拟合检测信号（简化版本，基于边界框）
wire ellipse_passed;         // 椭圆拟合通过信号
wire filter_done;            // 椭圆拟合完成信号

// 椭圆轴比检测信号（精确版本，基于二阶矩）     移出
// wire axisratio_pass;         // 椭圆轴比通过信号
// wire axisratio_done;         // 椭圆轴比完成信号

// 综合椭圆检测通过信号（并联：两个都通过）
wire ellipse_combined_pass;

// 紧凑度检测信号
wire compactness_pass;       // 紧凑度通过信号
wire compactness_done;       // 紧凑度完成信号

// 肤色检测模块实例化（实时处理）
face_reader_720p skin_detector (
    .image_in_R(image_R),            // R分量输入
    .image_in_G(image_G),            // G分量输入
    .image_in_B(image_B),            // B分量输入
    .pixel_x(pixel_x),               // 像素X坐标
    .pixel_y(pixel_y),               // 像素Y坐标
    .pixel_valid(pixel_valid),       // 像素有效信号
    .clk(clk),                       // 时钟信号
    .binary_output(binary_output),   // 二值化输出
    .output_valid(binary_valid)      // 二值化有效信号
);

// 低通滤波模块实例化（实时处理）
low_pass_realtime low_pass_filter (
    .binary_input(binary_output),    // 二值化输入
    .pixel_x(pixel_x),               // 像素X坐标
    .pixel_y(pixel_y),               // 像素Y坐标
    .pixel_valid(binary_valid),      // 像素有效信号
    .clk(clk),                       // 时钟信号
    .filtered_output(filtered_output), // 滤波后输出
    .output_valid(filtered_valid)    // 滤波有效信号
);

// 流式连通组件分析模块实例化（实时处理）
streaming_connected_components cc_analyzer (
    .clk(clk),                       // 时钟信号
    .rst_n(rst_n),                   // 复位信号
    .binary_input(filtered_output),  // 滤波后输入
    .pixel_x(pixel_x),               // 像素X坐标
    .pixel_y(pixel_y),               // 像素Y坐标
    .pixel_valid(filtered_valid),    // 滤波有效信号
    .frame_start(frame_start),       // 帧开始信号
    .frame_end(frame_end),           // 帧结束信号
    .component_id(component_id),     // 组件ID输出
    .component_valid(component_valid), // 组件有效信号
    .component_area(component_area_out), // 组件面积输出
    .component_perimeter(component_perimeter_out), // 组件周长输出
    .bbox_min_x(current_bbox_min_x),      // 连接到wire变量
    .bbox_max_x(current_bbox_max_x),
    .bbox_min_y(current_bbox_min_y),
    .bbox_max_y(current_bbox_max_y)
    // 二阶矩输出（用于椭圆轴比计算）      移出
    // .sum_x(sum_x_out), .sum_y(sum_y_out), .sum_xx(sum_xx_out), 
    // .sum_yy(sum_yy_out), .sum_xy(sum_xy_out)
);

// 几何约束过滤模块实例化（720p参数）
geometric_filter_720p geo_filter (
    .clk(clk),               // 时钟信号
    .rst_n(rst_n),           // 复位信号
    .bbox_min_x(current_bbox_min_x), // 使用wire变量
    .bbox_max_x(current_bbox_max_x),
    .bbox_min_y(current_bbox_min_y),
    .bbox_max_y(current_bbox_max_y),
    .component_area(component_area_out),  // 组件面积（从连通组件获取）
    .bbox_valid(component_valid), // 边界框有效信号
    .bbox_passed(geometric_pass), // 几何约束通过信号
    .filter_done(geometric_done)  // 几何约束完成信号
);

// 位置约束过滤模块实例化（720p参数）
position_filter_720p pos_filter (
    .clk(clk),               // 时钟信号
    .rst_n(rst_n),           // 复位信号
    .bbox_min_y(current_bbox_min_y), // 使用wire变量
    .bbox_max_y(current_bbox_max_y),
    .bbox_valid(geometric_pass), // 几何约束通过信号
    .position_passed(position_pass), // 位置约束通过信号
    .filter_done(position_done) // 位置约束完成信号
);

// 椭圆拟合检测模块实例化（720p参数，简化版本）
ellipse_fitting_720p ellipse_filter (
    .clk(clk),               // 时钟信号
    .rst_n(rst_n),           // 复位信号
    .binary_region(1'b0),    // 二值化区域（未使用，简化版本，设为0）
    .region_min_x(current_bbox_min_x), // 使用wire变量
    .region_max_x(current_bbox_max_x),
    .region_min_y(current_bbox_min_y),
    .region_max_y(current_bbox_max_y),
    .region_valid(position_pass), // 位置约束通过信号作为有效输入
    .ellipse_passed(ellipse_passed), // 椭圆拟合通过信号
    .filter_done(filter_done) // 椭圆拟合完成信号
);

// 椭圆轴比检测模块实例化（720p参数，精确版本）         移出
// ellipse_axisratio_720p axisratio_filter (
    // .clk(clk),               // 时钟信号
    // .rst_n(rst_n),           // 复位信号
    // .valid_in(position_pass), // 位置约束通过信号
    // .area_in(component_area_out), // 区域面积
    // 二阶矩输入（从连通组件获取）
    // .sum_x(sum_x_out), .sum_y(sum_y_out), .sum_xx(sum_xx_out), 
    // .sum_yy(sum_yy_out), .sum_xy(sum_xy_out), // 连接真实值
    // .axisratio_pass(axisratio_pass), // 椭圆轴比通过信号
    // .done(axisratio_done) // 椭圆轴比完成信号
// );

// 综合椭圆检测：并联（两个都通过）    移出
//assign ellipse_combined_pass = ellipse_passed && axisratio_pass;

// 紧凑度标量评估（基于面积与周长，流式友好）
compactness_eval_720p comp_eval (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(ellipse_passed), // 更正端口名
    .area_in(component_area_out),
    .perimeter_in(component_perimeter_out),
    .compactness_passed(compactness_pass),
    .done(compactness_done) // 假设端口名为done
);

// 输出控制逻辑（输出单个bbox和index）
reg [3:0] current_face_index;

integer i;  // 修改：使用 integer 代替 int
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位所有输出
        out_valid <= 1'b0;
        current_face_index <= 0;
        out_index <= 0;
        out_bbox_min_x <= 0;
        out_bbox_max_x <= 0;
        out_bbox_min_y <= 0;
        out_bbox_max_y <= 0;
        face_count_out <= 0;  // 复位face_count_out
    end else begin
        out_valid <= 1'b0;
        // 实时输出：当紧凑度检测通过时输出人脸
        if (compactness_pass && compactness_done && current_face_index < MAX_FACES) begin
            // 输出当前检测到的人脸
            out_bbox_min_x <= current_bbox_min_x;
            out_bbox_max_x <= current_bbox_max_x;
            out_bbox_min_y <= current_bbox_min_y;
            out_bbox_max_y <= current_bbox_max_y;
            out_index <= current_face_index;
            out_valid <= 1'b1;
            current_face_index <= current_face_index + 1;
            face_count_out <= current_face_index + 1;  // 更新face_count_out
        end else if (frame_end) begin
            // 帧结束时重置
            current_face_index <= 0;
            face_count_out <= current_face_index;  // 输出最终face_count
        end
    end
end

endmodule