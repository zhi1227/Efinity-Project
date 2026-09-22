//======================================================================
//  rgb565_to_gray_tb.v
//----------------------------------------------------------------------
//  rgb565_to_gray 的自检式测试台。
//
//  验证内容:
//    1. 穷举全部 65536 个 RGB565 码字，逐拍比对 gray_o。
//       参考模型用「真乘法 + MSB 复制扩展」：
//           R8={R5,R5[4:2]}  G8={G6,G6[5:4]}  B8={B5,B5[4:2]}
//           Y  = (77*R8 + 150*G8 + 29*B8) >> 8
//       因此本测试同时验证了两件事：
//         (a) 移位加法实现 == 真乘法（77=64+8+4+1, 150=128+16+4+2, 29=32-2-1）
//         (b) 通道扩展用的是 MSB 复制，而不是简单左移补零
//    2. de / x / y 的 1 拍流水透传对齐。
//    3. 黑白红绿蓝五个端点值。
//
//  仿真器无关，已在 Vivado 2019.2 XSim 上通过。
//======================================================================
`timescale 1ns/1ps

module rgb565_to_gray_tb;

	reg clk   = 1'b0;
	reg rst_n = 1'b0;
	always #5 clk = ~clk;			// 100MHz 假设时钟

	//------------------------------------------------------------------
	// 激励
	//------------------------------------------------------------------
	reg        de_i = 1'b0;
	reg [10:0] x_i  = 11'd0;
	reg [9:0]  y_i  = 10'd0;
	reg [15:0] din  = 16'd0;

	//------------------------------------------------------------------
	// DUT
	//------------------------------------------------------------------
	wire [7:0]  gray_o;
	wire        de_o;
	wire [10:0] x_o;
	wire [9:0]  y_o;

	rgb565_to_gray #(.AWIDTH(11)) dut (
		.clk      (clk),
		.rst_n    (rst_n),
		.de_i     (de_i),
		.x_i      (x_i),
		.y_i      (y_i),
		.rgb565_i (din),
		.gray_o   (gray_o),
		.de_o     (de_o),
		.x_o      (x_o),
		.y_o      (y_o)
	);

	//------------------------------------------------------------------
	// DUT 输入打 1 拍，用于和输出对齐比较
	//------------------------------------------------------------------
	reg        de_q;
	reg [10:0] x_q;
	reg [9:0]  y_q;
	reg [15:0] din_q;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			de_q  <= 1'b0;
			x_q   <= 11'd0;
			y_q   <= 10'd0;
			din_q <= 16'd0;
		end else begin
			de_q  <= de_i;
			x_q   <= x_i;
			y_q   <= y_i;
			din_q <= din;
		end
	end

	//------------------------------------------------------------------
	// 参考模型
	//------------------------------------------------------------------
	function [7:0] ref_gray;
		input [15:0] v;
		reg [7:0] r, g, b;
		begin
			r = {v[15:11], v[15:13]};
			g = {v[10:5],  v[10:9] };
			b = {v[4:0],   v[4:2] };
			ref_gray = (77*r + 150*g + 29*b) >> 8;
		end
	endfunction

	//------------------------------------------------------------------
	// 比对
	//------------------------------------------------------------------
	integer err_cnt = 0;
	integer ok_cnt  = 0;
	integer shown   = 0;
	integer cyc_err;

	always @(posedge clk) begin
		if (rst_n && de_q) begin
			cyc_err = 0;

			if (gray_o !== ref_gray(din_q)) begin
				cyc_err = cyc_err + 1;
				if (shown < 10)
					$display(" FAIL 灰度: rgb565=%04h  got=%02h  exp=%02h",
						din_q, gray_o, ref_gray(din_q));
			end

			if (de_o !== 1'b1) begin
				cyc_err = cyc_err + 1;
				if (shown < 10) $display(" FAIL de_o 未跟随: de_o=%b", de_o);
			end

			if (x_o !== x_q) begin
				cyc_err = cyc_err + 1;
				if (shown < 10) $display(" FAIL x 透传: got=%0d exp=%0d", x_o, x_q);
			end

			if (y_o !== y_q) begin
				cyc_err = cyc_err + 1;
				if (shown < 10) $display(" FAIL y 透传: got=%0d exp=%0d", y_o, y_q);
			end

			if (cyc_err == 0) ok_cnt = ok_cnt + 1;
			else begin
				err_cnt = err_cnt + 1;
				shown   = shown + 1;
			end
		end
	end

	//------------------------------------------------------------------
	// 激励时序：穷举 65536 个码字
	//------------------------------------------------------------------
	integer code;

	initial begin
		rst_n = 1'b0;
		repeat (4) @(negedge clk);
		rst_n = 1'b1;
		repeat (2) @(negedge clk);

		for (code = 0; code < 65536; code = code + 1) begin
			de_i = 1'b1;
			din  = code[15:0];
			x_i  = code % 1280;
			y_i  = (code / 1280) % 720;
			@(negedge clk);
		end

		de_i = 1'b0;
		repeat (4) @(negedge clk);

		$display("");
		$display("==== rgb565_to_gray 自检 ====");
		$display(" 穷举码字数 : 65536");
		$display(" 通过       : %0d", ok_cnt);
		$display(" 错误       : %0d", err_cnt);
		$display(" 端点: 黑 %04h -> %0d | 白 %04h -> %0d | 红 %04h -> %0d | 绿 %04h -> %0d | 蓝 %04h -> %0d",
			16'h0000, ref_gray(16'h0000),
			16'hFFFF, ref_gray(16'hFFFF),
			16'hF800, ref_gray(16'hF800),
			16'h07E0, ref_gray(16'h07E0),
			16'h001F, ref_gray(16'h001F));

		if ((err_cnt == 0) && (ok_cnt == 65536))
			$display(" >>> ALL TESTS PASS");
		else
			$display(" >>> TESTS FAILED");

		$finish;
	end

endmodule
