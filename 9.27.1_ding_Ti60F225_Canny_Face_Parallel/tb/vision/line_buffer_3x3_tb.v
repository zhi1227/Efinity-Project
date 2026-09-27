//======================================================================
//  line_buffer_3x3_tb.v
//----------------------------------------------------------------------
//  line_buffer_3x3 的自检式测试台。
//
//  验证内容（对 640 和 1280 两种宽度各跑一遍）:
//    1. 窗口内容: 每个 window_valid 拍，用黄金模型从整帧缓存里取
//                 (x_o-1..x_o+1) x (y_o-1..y_o+1) 九个像素，
//                 与 window_o 的 9 个字段逐位比较。
//    2. 窗口坐标: x_o/y_o 必须落在 [1, WIDTH-2] x [1, HEIGHT-2]。
//    3. 边界行为: 窗口总数必须恰好等于 (HEIGHT-2)*(WIDTH-2)*帧数，
//                 多一个（越界/串行）或少一个都判 FAIL。
//                 因此第 0、1 行不产生窗口这一条被隐式严格覆盖。
//    4. 行首串行: 由第 1、3 条共同保证（列错位必然导致数值不等）。
//    5. frame_start: 跑 2 帧，第 2 帧开始前重发 frame_start，
//                    检验 row_ready 被清零后仍能重新产出正确窗口。
//
//  仿真器无关，可直接在 Questa / VCS / XSim 里跑。
//  已在 Vivado 2019.2 XSim 上通过。
//======================================================================
`timescale 1ns/1ps

//----------------------------------------------------------------------
// 单通道检查器：一路激励 + 一路 DUT + 一路黄金模型
//----------------------------------------------------------------------
module lb3x3_chk #(
	parameter integer WIDTH  = 1280,
	parameter integer AWIDTH = 11,
	parameter integer HEIGHT = 8,
	parameter integer BLANK  = 8,		// 行间消隐周期数
	parameter integer FRAMES = 2		// 帧数
)(
	input  wire			clk,
	input  wire			rst_n,
	output reg [31:0]	err_cnt,
	output reg [31:0]	ok_cnt,
	output reg			done,
	output reg [31:0]	cnt_xmax,	// x_o == WIDTH-2 的次数（诊断用）
	output reg [31:0]	cnt_ymax,	// y_o == HEIGHT-2 的次数
	output reg [31:0]	cnt_xy,		// x_o == WIDTH-2 且 y_o == HEIGHT-2
	output reg [31:0]	miss_cnt,	// 覆盖检查：出现次数 != FRAMES 的坐标个数
	output reg [AWIDTH-1:0] xmin, xmax,
	output reg [9:0]        ymin, ymax
);

	// 逐坐标覆盖计数：seen[y*WIDTH+x] 记录该中心坐标出现过几次
	reg [1:0] seen [0:WIDTH*HEIGHT-1];
	integer   kk;
	initial for (kk = 0; kk < WIDTH*HEIGHT; kk = kk + 1) seen[kk] = 0;

	//------------------------------------------------------------------
	// 激励产生
	//------------------------------------------------------------------
	integer period = BLANK + WIDTH;

	reg [31:0] cx;			// 行内计数 0..period-1
	reg [31:0] cy;			// 行计数
	reg [31:0] cf;			// 帧计数
	reg        go;			// 复位结束后开始

	wire de_i = go && (cx >= BLANK) && (cf < FRAMES);
	wire [AWIDTH-1:0] x_i = (cx >= BLANK) ? (cx - BLANK) : {AWIDTH{1'b0}};
	wire [9:0]        y_i = cy;

	// 帧起始脉冲：每帧行 0 的消隐期给出 1 拍
	wire frame_start = go && (cx == 0) && (cy == 0) && (cf < FRAMES);

	// 确定性测试图案：窗口内 9 个像素互不相同，任何行/列错位都会被抓到
	function [7:0] pat;
		input [31:0] px;
		input [31:0] py;
		begin
			pat = (px * 32'd7 + py * 32'd53 + px * py) & 32'h0000_00FF;
		end
	endfunction

	wire [7:0] data_i = pat(x_i, y_i);

	//------------------------------------------------------------------
	// 黄金模型：整帧像素缓存
	//------------------------------------------------------------------
	reg [7:0] frm [0:WIDTH*HEIGHT-1];

	always @(posedge clk) begin
		if (de_i) frm[y_i*WIDTH + x_i] <= data_i;
	end

	//------------------------------------------------------------------
	// DUT
	//------------------------------------------------------------------
	wire [9*8-1:0] window_o;
	wire           window_valid;
	wire [AWIDTH-1:0] x_o;
	wire [9:0]        y_o;

	line_buffer_3x3 #(
		.WIDTH (WIDTH),
		.DWIDTH(8),
		.AWIDTH(AWIDTH)
	) dut (
		.clk         (clk),
		.rst_n       (rst_n),
		.frame_start (frame_start),
		.de_i        (de_i),
		.x_i         (x_i),
		.y_i         (y_i),
		.data_i      (data_i),
		.window_o    (window_o),
		.window_valid(window_valid),
		.x_o         (x_o),
		.y_o         (y_o)
	);

	//------------------------------------------------------------------
	// 检查逻辑
	//------------------------------------------------------------------
	// window_o 字段切分：{p00,p01,p02, p10,p11,p12, p20,p21,p22}
	wire [7:0] wp00 = window_o[71:64];
	wire [7:0] wp01 = window_o[63:56];
	wire [7:0] wp02 = window_o[55:48];
	wire [7:0] wp10 = window_o[47:40];
	wire [7:0] wp11 = window_o[39:32];
	wire [7:0] wp12 = window_o[31:24];
	wire [7:0] wp20 = window_o[23:16];
	wire [7:0] wp21 = window_o[15:8];
	wire [7:0] wp22 = window_o[7:0];

	integer      iy, ix;
	reg [7:0]    e00,e01,e02,e10,e11,e12,e20,e21,e22;
	integer      shown;

	// 注意：不能用 cf<FRAMES 作为门限。一行最后 2 个窗口是在该行 DE 结束后的
	// 两拍才输出的，此时待测帧的帧计数已经自增，会被误挡掉。
	// 激励结束后 de_i 恒为 0，window_valid 自然不会再拉高，无需额外门限。
	always @(posedge clk) begin
		if (rst_n && window_valid) begin
			iy = y_o;
			ix = x_o;

			// 覆盖范围统计
			if (ix < xmin) xmin <= ix;
			if (ix > xmax) xmax <= ix;
			if (iy < ymin) ymin <= iy;
			if (iy > ymax) ymax <= iy;
			if (ix == WIDTH-2)  cnt_xmax <= cnt_xmax + 1;
			if (iy == HEIGHT-2) cnt_ymax <= cnt_ymax + 1;
			if (ix == WIDTH-2 && iy == HEIGHT-2) cnt_xy <= cnt_xy + 1;

			// 边界检查
			if (iy < 1 || iy > HEIGHT-2) begin
				if (shown < 10) $display("[%0d] FAIL 边界: y_o=%0d 越界", WIDTH, iy);
				err_cnt  <= err_cnt + 1;
				shown    <= shown + 1;
			end else if (ix < 1 || ix > WIDTH-2) begin
				if (shown < 10) $display("[%0d] FAIL 边界: x_o=%0d 越界", WIDTH, ix);
				err_cnt  <= err_cnt + 1;
				shown    <= shown + 1;
			end else begin
				seen[iy*WIDTH + ix] <= seen[iy*WIDTH + ix] + 1;

				// 黄金模型取窗
				e00 = frm[(iy-1)*WIDTH + (ix-1)];
				e01 = frm[(iy-1)*WIDTH + ix    ];
				e02 = frm[(iy-1)*WIDTH + (ix+1)];
				e10 = frm[ iy   *WIDTH + (ix-1)];
				e11 = frm[ iy   *WIDTH + ix    ];
				e12 = frm[ iy   *WIDTH + (ix+1)];
				e20 = frm[(iy+1)*WIDTH + (ix-1)];
				e21 = frm[(iy+1)*WIDTH + ix    ];
				e22 = frm[(iy+1)*WIDTH + (ix+1)];

				if (window_o !== {e00,e01,e02,e10,e11,e12,e20,e21,e22}) begin
					err_cnt <= err_cnt + 1;
					if (shown < 10) begin
						$display("[%0d] FAIL 窗口内容 @ x_o=%0d y_o=%0d", WIDTH, ix, iy);
						$display("         got = %02h %02h %02h / %02h %02h %02h / %02h %02h %02h",
							wp00,wp01,wp02,wp10,wp11,wp12,wp20,wp21,wp22);
						$display("         exp = %02h %02h %02h / %02h %02h %02h / %02h %02h %02h",
							e00,e01,e02,e10,e11,e12,e20,e21,e22);
					end
					shown <= shown + 1;
				end else begin
					ok_cnt <= ok_cnt + 1;
				end
			end
		end
	end

	//------------------------------------------------------------------
	// 激励时序 + 收尾判定
	//------------------------------------------------------------------
	integer exp_total = (HEIGHT-2) * (WIDTH-2) * FRAMES;

	// 覆盖检查：所有中心坐标都必须恰好出现 FRAMES 次
	integer miss_show;
	initial begin
		wait (done);
		#100;
		miss_cnt  = 0;
		miss_show = 0;
		for (iy = 1; iy <= HEIGHT-2; iy = iy + 1) begin
			for (ix = 1; ix <= WIDTH-2; ix = ix + 1) begin
				if (seen[iy*WIDTH + ix] != FRAMES) begin
					if (miss_show < 20)
						$display("[%0d] 坐标异常: y_o=%0d x_o=%0d 出现 %0d 次 (期望 %0d)",
							WIDTH, iy, ix, seen[iy*WIDTH + ix], FRAMES);
					miss_show = miss_show + 1;
					miss_cnt  = miss_cnt + 1;
				end
			end
		end
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cx      <= 0;
			cy      <= 0;
			cf      <= 0;
			go      <= 0;
			err_cnt <= 0;
			ok_cnt  <= 0;
			shown   <= 0;
			done    <= 0;
			cnt_xmax <= 0;
			cnt_ymax <= 0;
			cnt_xy   <= 0;
			xmin <= {AWIDTH{1'b1}};
			xmax <= 0;
			ymin <= 10'h3FF;
			ymax <= 0;
		end else if (!go) begin
			go <= 1;					// 复位释放后第 2 拍开始
		end else if (!done) begin
			if (cx == period-1) begin
				cx <= 0;
				if (cy == HEIGHT-1) begin
					cy <= 0;
					if (cf == FRAMES-1) begin
						cf   <= cf + 1;
						done <= 1;		// 激励结束
					end else begin
						cf <= cf + 1;
					end
				end else begin
					cy <= cy + 1;
				end
			end else begin
				cx <= cx + 1;
			end
		end
	end

endmodule


//----------------------------------------------------------------------
// 顶层：640 / 1280 两路并跑
//----------------------------------------------------------------------
module line_buffer_3x3_tb;

	reg clk    = 1'b0;
	reg rst_n  = 1'b0;

	always #5 clk = ~clk;			// 100MHz 假设时钟

	wire [31:0] err_640,  ok_640,  err_1280, ok_1280;
	wire        done_640, done_1280;
	wire [31:0] cxm640, cym640, cxy640, cxm1280, cym1280, cxy1280;
	wire [31:0] miss640, miss1280;
	wire [9:0]  xmin640, xmax640, ymin640, ymax640;
	wire [10:0] xmin1280, xmax1280;
	wire [9:0]  ymin1280, ymax1280;

	lb3x3_chk #(.WIDTH(640),  .AWIDTH(10), .HEIGHT(8)) u_640 (
		.clk(clk), .rst_n(rst_n),
		.err_cnt(err_640), .ok_cnt(ok_640), .done(done_640),
		.cnt_xmax(cxm640), .cnt_ymax(cym640), .cnt_xy(cxy640),
		.miss_cnt(miss640),
		.xmin(xmin640), .xmax(xmax640), .ymin(ymin640), .ymax(ymax640)
	);

	lb3x3_chk #(.WIDTH(1280), .AWIDTH(11), .HEIGHT(8)) u_1280 (
		.clk(clk), .rst_n(rst_n),
		.err_cnt(err_1280), .ok_cnt(ok_1280), .done(done_1280),
		.cnt_xmax(cxm1280), .cnt_ymax(cym1280), .cnt_xy(cxy1280),
		.miss_cnt(miss1280),
		.xmin(xmin1280), .xmax(xmax1280), .ymin(ymin1280), .ymax(ymax1280)
	);

	integer exp_640  = (8-2) * (640 -2) * 2;
	integer exp_1280 = (8-2) * (1280-2) * 2;

	initial begin
		#100;
		rst_n = 1'b1;
	end

	initial begin
		// 超时保护
		#2_000_000;
		$display("=== TIMEOUT: 仿真未在预期时间内结束 ===");
		$finish;
	end

	initial begin
		wait (done_640 && done_1280);
		#200;						// 等最后一批比较落地

		$display("");
		$display("================ line_buffer_3x3 结果 ================");
		$display(" WIDTH= 640 : 有效窗口 %0d / 期望 %0d , 错误 %0d", ok_640,  exp_640,  err_640 );
		$display(" WIDTH=1280 : 有效窗口 %0d / 期望 %0d , 错误 %0d", ok_1280, exp_1280, err_1280);
		$display(" 诊断 640 : x_o=[%0d,%0d] y_o=[%0d,%0d] cnt_xmax=%0d cnt_ymax=%0d cnt_xy=%0d",
			xmin640, xmax640, ymin640, ymax640, cxm640, cym640, cxy640);
		$display(" 诊断1280 : x_o=[%0d,%0d] y_o=[%0d,%0d] cnt_xmax=%0d cnt_ymax=%0d cnt_xy=%0d",
			xmin1280, xmax1280, ymin1280, ymax1280, cxm1280, cym1280, cxy1280);
		$display(" 覆盖 640  : 坐标异常个数 = %0d", miss640);
		$display(" 覆盖1280  : 坐标异常个数 = %0d", miss1280);
		if ((err_640 == 0) && (err_1280 == 0) &&
		    (ok_640 == exp_640) && (ok_1280 == exp_1280) &&
		    (miss640 == 0) && (miss1280 == 0))
			$display(" >>> ALL TESTS PASS");
		else
			$display(" >>> TEST FAILED");
		$display("=====================================================");
		$finish;
	end

endmodule
