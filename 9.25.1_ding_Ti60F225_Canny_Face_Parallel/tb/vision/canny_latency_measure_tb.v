//======================================================================
//  canny_latency_measure_tb.v   —— 精确测量 Canny 链路延迟
//----------------------------------------------------------------------
//  方法：喂一个"单像素亮点"（在均匀中灰背景上的一个白点），
//        该点会在链路中产生可观测的边缘响应。
//        同时用 valid 链独立测量：de 信号从输入到输出的传递拍数。
//
//  这里用更可靠的方法：给输入一个"DE 脉冲"，测量输出 DE 脉冲的延迟。
//  DE 会独立地逐级传播（每级都是 valid 透传），因此 DE 的延迟
//  == 数据通路的延迟，可精确到拍。
//
//  测得的拍数应与 example_top.v 的 CANNY_LATENCY 一致。
//======================================================================
`timescale 1ns/1ns

module canny_latency_measure_tb;

	localparam AW = 11;

	reg clk = 0;
	reg rst_n = 0;

	reg          in_valid = 0;
	reg [15:0]   in_rgb   = 0;
	reg [AW-1:0] in_x     = 0;
	reg [9:0]    in_y     = 0;

	wire [7:0]  gray_w;  wire gray_de;  wire [AW-1:0] gray_x;  wire [9:0] gray_y;
	wire [71:0] med_win; wire med_win_v; wire [AW-1:0] med_win_x; wire [9:0] med_win_y;
	wire [7:0]  med_w;   wire med_de;   wire [AW-1:0] med_x;   wire [9:0] med_y;
	wire [71:0] sob_win; wire sob_win_v; wire [AW-1:0] sob_win_x; wire [9:0] sob_win_y;
	wire [11:0] sob_mag; wire [1:0] sob_dir; wire sob_de; wire [AW-1:0] sob_x; wire [9:0] sob_y;
	wire [125:0] nms_win; wire nms_win_v; wire [AW-1:0] nms_win_x; wire [9:0] nms_win_y;
	wire [11:0] nms_mag; wire nms_de; wire [AW-1:0] nms_x; wire [9:0] nms_y;
	wire [1:0]  th_cls;  wire th_de;  wire [AW-1:0] th_x;  wire [9:0] th_y;
	wire [17:0] hys_win; wire hys_win_v; wire [AW-1:0] hys_win_x; wire [9:0] hys_win_y;
	wire canny_edge; wire canny_edge_de;

	wire frame_start = (in_y == 10'd0) && (in_x == 0) && in_valid;

	rgb565_to_gray #(.AWIDTH(AW)) u_gray (
		.clk(clk), .rst_n(rst_n), .de_i(in_valid), .x_i(in_x), .y_i(in_y),
		.rgb565_i(in_rgb), .gray_o(gray_w), .de_o(gray_de), .x_o(gray_x), .y_o(gray_y));

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(AW)) u_lb1 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(gray_de), .x_i(gray_x), .y_i(gray_y), .data_i(gray_w),
		.window_o(med_win), .window_valid(med_win_v), .x_o(med_win_x), .y_o(med_win_y));

	median3x3 #(.AWIDTH(AW)) u_median (
		.clk(clk), .rst_n(rst_n), .win_valid_i(med_win_v), .x_i(med_win_x),
		.y_i(med_win_y), .window_i(med_win), .med_o(med_w), .med_valid_o(med_de),
		.x_o(med_x), .y_o(med_y));

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(AW)) u_lb2 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(med_de), .x_i(med_x), .y_i(med_y), .data_i(med_w),
		.window_o(sob_win), .window_valid(sob_win_v), .x_o(sob_win_x), .y_o(sob_win_y));

	sobel3x3 #(.AWIDTH(AW)) u_sobel (
		.clk(clk), .rst_n(rst_n), .win_valid_i(sob_win_v), .x_i(sob_win_x),
		.y_i(sob_win_y), .window_i(sob_win), .mag_o(sob_mag), .dir_o(sob_dir),
		.valid_o(sob_de), .x_o(sob_x), .y_o(sob_y));

	wire [13:0] sob_px = {sob_dir, sob_mag};

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(14), .AWIDTH(AW)) u_lb3 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(sob_de), .x_i(sob_x), .y_i(sob_y), .data_i(sob_px),
		.window_o(nms_win), .window_valid(nms_win_v), .x_o(nms_win_x), .y_o(nms_win_y));

	nms3x3 #(.AWIDTH(AW)) u_nms (
		.clk(clk), .rst_n(rst_n), .win_valid_i(nms_win_v), .x_i(nms_win_x),
		.y_i(nms_win_y), .window_i(nms_win), .nms_mag_o(nms_mag),
		.valid_o(nms_de), .x_o(nms_x), .y_o(nms_y));

	canny_threshold #(.TH_HIGH(12'd160), .TH_LOW(12'd80), .AWIDTH(AW)) u_th (
		.clk(clk), .rst_n(rst_n), .valid_i(nms_de), .x_i(nms_x), .y_i(nms_y),
		.mag_i(nms_mag), .cls_o(th_cls), .valid_o(th_de), .x_o(th_x), .y_o(th_y));

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(2), .AWIDTH(AW)) u_lb4 (
		.clk(clk), .rst_n(rst_n), .frame_start(frame_start),
		.de_i(th_de), .x_i(th_x), .y_i(th_y), .data_i(th_cls),
		.window_o(hys_win), .window_valid(hys_win_v), .x_o(hys_win_x), .y_o(hys_win_y));

	hysteresis_local #(.AWIDTH(AW)) u_hys (
		.clk(clk), .rst_n(rst_n), .win_valid_i(hys_win_v), .x_i(hys_win_x),
		.y_i(hys_win_y), .window_i(hys_win), .edge_o(canny_edge),
		.valid_o(canny_edge_de), .x_o(), .y_o());

	always #5 clk = ~clk;

	integer cyc = 0;
	always @(posedge clk) cyc = cyc + 1;

	//------------------------------------------------------------------
	// 逐级 DE 上升沿时刻记录：测每一级的延迟，定位任何异常级
	//------------------------------------------------------------------
	integer t_gray = -1, t_lb1 = -1, t_med = -1, t_lb2 = -1;
	integer t_sob = -1, t_lb3 = -1, t_nms = -1, t_th = -1;
	integer t_lb4 = -1, t_hys = -1;

	reg g_q, l1_q, m_q, l2_q, s_q, l3_q, n_q, t_q, l4_q, h_q;
	always @(posedge clk) begin
		if ( gray_de  && !g_q  && t_gray  < 0) t_gray  = cyc;
		if ( med_win_v&& !l1_q && t_lb1   < 0) t_lb1   = cyc;
		if ( med_de   && !m_q  && t_med   < 0) t_med   = cyc;
		if ( sob_win_v&& !l2_q && t_lb2   < 0) t_lb2   = cyc;
		if ( sob_de   && !s_q  && t_sob   < 0) t_sob   = cyc;
		if ( nms_win_v&& !l3_q && t_lb3   < 0) t_lb3   = cyc;
		if ( nms_de   && !n_q  && t_nms   < 0) t_nms   = cyc;
		if ( th_de    && !t_q  && t_th    < 0) t_th    = cyc;
		if ( hys_win_v&& !l4_q && t_lb4   < 0) t_lb4   = cyc;
		if ( canny_edge_de && !h_q && t_hys < 0) t_hys = cyc;

		g_q <= gray_de;   l1_q <= med_win_v; m_q <= med_de;
		l2_q <= sob_win_v; s_q <= sob_de;    l3_q <= nms_win_v;
		n_q <= nms_de;    t_q <= th_de;      l4_q <= hys_win_v;
		h_q <= canny_edge_de;
	end

	initial begin
		repeat (5) @(negedge clk);
		rst_n = 1;
		@(negedge clk);

		//	喂足够多的行让所有 line_buffer 就绪（需要 >=3 行）
		//	注意：line_buffer_3x3 的 WIDTH 参数是 1280，内部地址合法保护
		//	条件是 x_i < WIDTH，且按 "DE 下降沿" 判行结束。
		//	故这里必须喂接近真实宽度的行，否则 row_ready 永远到不了 2。
		//	为了仿真速度，用较少的行数但足够宽的行。
		begin : feed
			integer yy, xx;
			for (yy = 0; yy < 12; yy = yy + 1) begin
				for (xx = 0; xx < 1280; xx = xx + 1) begin
					@(negedge clk);
					in_valid = 1; in_x = xx[AW-1:0]; in_y = yy[9:0];
					in_rgb   = 16'h8410;	// 均匀中灰
				end
				//	行结束：DE 拉低一拍，让 line_buffer 检测到下降沿
				@(negedge clk);
				in_valid = 0;
			end
			@(negedge clk);
			in_valid = 0;
		end

		repeat (200) @(negedge clk);

		$display("========================================================");
		$display("  Canny 链路各级 valid 上升沿时刻（cycle）");
		$display("--------------------------------------------------------");
		$display("  gray_de      首个有效   cycle = %0d", t_gray);
		$display("  lb1 window_v             = %0d  (+%0d)", t_lb1,  t_lb1 - t_gray);
		$display("  median med_de            = %0d  (+%0d)", t_med,  t_med  - t_lb1);
		$display("  lb2 window_v             = %0d  (+%0d)", t_lb2,  t_lb2  - t_med);
		$display("  sobel valid              = %0d  (+%0d)", t_sob,  t_sob  - t_lb2);
		$display("  lb3 window_v             = %0d  (+%0d)", t_lb3,  t_lb3  - t_sob);
		$display("  nms valid                = %0d  (+%0d)", t_nms,  t_nms  - t_lb3);
		$display("  threshold valid          = %0d  (+%0d)", t_th,   t_th   - t_nms);
		$display("  lb4 window_v             = %0d  (+%0d)", t_lb4,  t_lb4  - t_th);
		$display("  hysteresis edge_de       = %0d  (+%0d)", t_hys,  t_hys  - t_lb4);
		$display("--------------------------------------------------------");
		$display("  数据通路从输入 valid 到 hysteresis 输出：%0d 拍", t_hys - t_gray + 1);
		$display("  输入侧还有 1 拍对齐寄存器 (canny_valid_d)");
		$display("  => 相对 lcd_data 的总延迟约 %0d 拍", t_hys - t_gray + 2);
		$display("========================================================");
		$finish;
	end

endmodule
