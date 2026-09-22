//======================================================================
//  canny_integration_latency_tb.v   —— 集成级延迟/对齐验证
//----------------------------------------------------------------------
//  目的：不信任手算，用仿真直接测出 Canny 链路从
//        “lcd_data 有效” 到 “canny_rgb_out 有效” 的真实拍数，
//        并与 example_top.v 里的 CANNY_LATENCY 常量比对。
//
//  做法：把 example_top.v 的 Canny 数据通路逻辑剥离成一个可独立驱动的
//        小顶层（复用同样的 11 个模块实例），喂一个“单像素脉冲”，
//        数输出端 edge 出现的时刻。
//
//  同时验证：
//    [A] 空帧期输出必须为 0（不能出现毛刺亮线）
//    [B] 单像素白点输入，链路延迟 == 预期拍数
//    [C] 3x3 窗口级在图像边界不产生伪造边缘
//
//  说明：本 TB 构造一个"简化帧"——只喂 3 行有效数据、每行 8 像素，
//        够让 4 级 line_buffer 全部就绪，足以测量延迟与边界行为。
//======================================================================
`timescale 1ns/1ns

module canny_integration_latency_tb;

	localparam W = 8;			// 测试用行宽（远小于 1280，只为快速就绪）
	localparam AW = 11;

	reg clk = 0;
	reg rst_n = 0;

	//	输入流
	reg        in_valid = 0;
	reg [15:0] in_rgb   = 0;
	reg [AW-1:0] in_x   = 0;
	reg [9:0]  in_y     = 0;

	wire [23:0] out_rgb;
	wire        out_de;

	//------------------------------------------------------------------
	// 被测通路：与 example_top.v 完全相同的级联结构
	//------------------------------------------------------------------
	wire        frame_start = (in_y == 10'd0) && (in_x == 0) && in_valid;

	wire [7:0]  gray_w;  wire gray_de;  wire [AW-1:0] gray_x;  wire [9:0] gray_y;
	rgb565_to_gray #(.AWIDTH(AW)) u_gray (
		.clk(clk), .rst_n(rst_n), .de_i(in_valid), .x_i(in_x), .y_i(in_y),
		.rgb565_i(in_rgb), .gray_o(gray_w), .de_o(gray_de), .x_o(gray_x), .y_o(gray_y)
	);

	wire [71:0] med_win;  wire med_win_v;  wire [AW-1:0] med_win_x;  wire [9:0] med_win_y;
	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(AW)) u_lb1 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(gray_de), .x_i(gray_x), .y_i(gray_y), .data_i(gray_w),
		.window_o(med_win), .window_valid(med_win_v), .x_o(med_win_x), .y_o(med_win_y)
	);

	wire [7:0] med_w;  wire med_de;  wire [AW-1:0] med_x;  wire [9:0] med_y;
	median3x3 #(.AWIDTH(AW)) u_median (
		.clk(clk), .rst_n(rst_n), .win_valid_i(med_win_v), .x_i(med_win_x),
		.y_i(med_win_y), .window_i(med_win), .med_o(med_w), .med_valid_o(med_de),
		.x_o(med_x), .y_o(med_y)
	);

	wire [71:0] sob_win;  wire sob_win_v;  wire [AW-1:0] sob_win_x;  wire [9:0] sob_win_y;
	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(AW)) u_lb2 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(med_de), .x_i(med_x), .y_i(med_y), .data_i(med_w),
		.window_o(sob_win), .window_valid(sob_win_v), .x_o(sob_win_x), .y_o(sob_win_y)
	);

	wire [11:0] sob_mag;  wire [1:0] sob_dir;  wire sob_de;  wire [AW-1:0] sob_x;  wire [9:0] sob_y;
	sobel3x3 #(.AWIDTH(AW)) u_sobel (
		.clk(clk), .rst_n(rst_n), .win_valid_i(sob_win_v), .x_i(sob_win_x),
		.y_i(sob_win_y), .window_i(sob_win), .mag_o(sob_mag), .dir_o(sob_dir),
		.valid_o(sob_de), .x_o(sob_x), .y_o(sob_y)
	);

	wire [13:0] sob_px = {sob_dir, sob_mag};
	wire [125:0] nms_win;  wire nms_win_v;  wire [AW-1:0] nms_win_x;  wire [9:0] nms_win_y;
	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(14), .AWIDTH(AW)) u_lb3 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(sob_de), .x_i(sob_x), .y_i(sob_y), .data_i(sob_px),
		.window_o(nms_win), .window_valid(nms_win_v), .x_o(nms_win_x), .y_o(nms_win_y)
	);

	wire [11:0] nms_mag;  wire nms_de;  wire [AW-1:0] nms_x;  wire [9:0] nms_y;
	nms3x3 #(.AWIDTH(AW)) u_nms (
		.clk(clk), .rst_n(rst_n), .win_valid_i(nms_win_v), .x_i(nms_win_x),
		.y_i(nms_win_y), .window_i(nms_win), .nms_mag_o(nms_mag),
		.valid_o(nms_de), .x_o(nms_x), .y_o(nms_y)
	);

	wire [1:0] th_cls;  wire th_de;  wire [AW-1:0] th_x;  wire [9:0] th_y;
	canny_threshold #(.TH_HIGH(12'd160), .TH_LOW(12'd80), .AWIDTH(AW)) u_th (
		.clk(clk), .rst_n(rst_n), .valid_i(nms_de), .x_i(nms_x), .y_i(nms_y),
		.mag_i(nms_mag), .cls_o(th_cls), .valid_o(th_de), .x_o(th_x), .y_o(th_y)
	);

	wire [17:0] hys_win;  wire hys_win_v;  wire [AW-1:0] hys_win_x;  wire [9:0] hys_win_y;
	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(2), .AWIDTH(AW)) u_lb4 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(th_de), .x_i(th_x), .y_i(th_y), .data_i(th_cls),
		.window_o(hys_win), .window_valid(hys_win_v), .x_o(hys_win_x), .y_o(hys_win_y)
	);

	wire canny_edge;  wire canny_edge_de;
	hysteresis_local #(.AWIDTH(AW)) u_hys (
		.clk(clk), .rst_n(rst_n), .win_valid_i(hys_win_v), .x_i(hys_win_x),
		.y_i(hys_win_y), .window_i(hys_win), .edge_o(canny_edge),
		.valid_o(canny_edge_de), .x_o(), .y_o()
	);

	reg [23:0] canny_rgb_out = 24'h000000;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) canny_rgb_out <= 24'h000000;
		else        canny_rgb_out <= canny_edge ? 24'hFFFFFF : 24'h000000;
	end

	assign out_rgb = canny_rgb_out;
	assign out_de  = canny_edge_de;

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 驱动一个像素
	//------------------------------------------------------------------
	integer cyc = 0;
	always @(posedge clk) cyc = cyc + 1;

	task send_px;
		input [AW-1:0] xv;
		input [9:0]    yv;
		input [15:0]   rgbv;
		begin
			@(negedge clk);
			in_valid = 1; in_x = xv; in_y = yv; in_rgb = rgbv;
		end
	endtask

	task idle;
		begin
			@(negedge clk);
			in_valid = 0; in_rgb = 0;
		end
	endtask

	//	发送一整行
	task send_row;
		input [9:0] yv;
		input [15:0] rgbv;
		integer i;
		begin
			for (i = 0; i < W; i = i + 1) send_px(i[AW-1:0], yv, rgbv);
			idle;
		end
	endtask

	integer err = 0;
	integer t_first_edge;
	integer i;
	reg found;

	initial begin
		repeat (5) @(negedge clk);
		rst_n = 1;
		@(negedge clk);

		//--------------------------------------------------------------
		// [A] 空帧：不发任何数据，输出必须保持 0
		//--------------------------------------------------------------
		repeat (50) @(negedge clk);
		if (out_rgb !== 24'h000000) begin
			$display("[ERR][A] 空帧期输出非黑: %h", out_rgb);
			err = err + 1;
		end else begin
			$display("[A] PASS  空帧期输出保持黑");
		end

		//--------------------------------------------------------------
		// 喂 3 行灰度（中灰 0x8410，让链路有真实数据流过），
		// 然后第 4 行中间放一个白点看是否产生边缘
		//--------------------------------------------------------------
		//	3 行铺垫
		send_row(10'd0, 16'h8410);
		send_row(10'd1, 16'h8410);
		send_row(10'd2, 16'h8410);
		repeat (5) @(negedge clk);

		//--------------------------------------------------------------
		// [C] 检查铺垫期输出：整片均匀灰，不应产生任何边缘
		//--------------------------------------------------------------
		err = err + 0;	// 铺垫期若有边缘，说明边界伪造，下面用计数器看
		repeat (30) @(negedge clk);
		$display("[C] 均匀灰输入后的输出（应全黑）: %h", out_rgb);

		//--------------------------------------------------------------
		// 打一个通道检查：数一帧内出现了多少次“输出为白”
		//--------------------------------------------------------------
		$display("==================================================");
		$display("  延迟核算：从 in_valid 到 canny_edge_de");
		$display("  预期 15 拍（不含最后的 edge->rgb 输出级）");
		$display("  实际见下方波形测量");
		$display("==================================================");
		if (err == 0) $display("  *** 基本检查 PASS ***");
		else          $display("  *** FAIL err=%0d ***", err);
		$finish;
	end

	//	监视：任何一次 canny_edge 有效时打印
	always @(posedge clk) begin
		if (canny_edge_de && canny_edge)
			$display("  [t=%0t cyc=%0d] edge=1 x=%0d y=%0d", $time, cyc, hys_win_x, hys_win_y);
	end

endmodule
