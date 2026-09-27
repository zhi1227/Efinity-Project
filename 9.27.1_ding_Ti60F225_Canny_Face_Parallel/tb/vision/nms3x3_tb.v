//======================================================================
//  nms3x3_tb.v   —— 自检测试台
//----------------------------------------------------------------------
//  验证目标：
//    [A] 方向 -> 邻接对映射正确（0/45/90/135 各取向，且含能区分映射对错的样本）
//    [B] 抑制判决 keep = (mc >= n1) && (mc >= n2)，含平局边界
//    [C] x / y / valid 透传对齐（1 拍延迟）
//
//  关键：定向用例里，让“被比较的邻居”取大值、而“另一对邻居”取 0，
//        这样如果 dir->邻接对映射写错了，判结果就会和期望不同 ——
//        即能真正暴露映射错误，而不是 RTL 与参考模型同错却同时通过。
//
//  输入流打包：每像素 14bit = {dir[1:0], mag[11:0]}，dir 在高 2 位，
//              窗口 9 x 14 = 126bit，p00 在最高位（与 line_buffer_3x3 一致）。
//  覆盖：10 组定向 + 100000 组随机窗口。
//======================================================================
`timescale 1ns/1ns

module nms3x3_tb;

	reg 				clk = 0;
	reg 				rst_n = 0;
	reg 				win_valid = 0;
	reg  [10:0]			xin = 0;
	reg  [9:0]			yin = 0;
	reg  [125:0]		win = 0;

	wire [11:0]			nmag;
	wire				dvalid;
	wire [10:0]			xout;
	wire [9:0]			yout;

	nms3x3 #(.AWIDTH(11)) u_dut (
		.clk			(clk),
		.rst_n			(rst_n),
		.win_valid_i	(win_valid),
		.x_i			(xin),
		.y_i			(yin),
		.window_i		(win),
		.nms_mag_o		(nmag),
		.valid_o		(dvalid),
		.x_o			(xout),
		.y_o			(yout)
	);

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 打包：单像素 {dir, mag}（14bit）；窗口 = 9 像素拼接，p00 最高位
	//------------------------------------------------------------------
	function [13:0] px;
		input [1:0]  d;
		input [11:0] m;
		begin px = {d, m}; end
	endfunction

	integer err_cnt = 0;
	integer ok_cnt  = 0;
	integer k;
	reg [125:0] w;
	reg [10:0] tagx = 0;
	reg [9:0]  tagy = 0;

	//------------------------------------------------------------------
	// 公共驱动（1 拍延迟）
	//------------------------------------------------------------------
	task drive;
		input [125:0] wv;
		begin
			tagx = tagx + 1;
			if (tagx == 1280) begin tagx = 0; tagy = tagy + 1; end
			@(negedge clk);
			win = wv; win_valid = 1; xin = tagx; yin = tagy;
			@(negedge clk);
			win_valid = 0;
		end
	endtask

	//------------------------------------------------------------------
	// [A/B] 定向用例：期望值手算
	//------------------------------------------------------------------
	task check_exp;
		input [125:0] wv;
		input [11:0]  exp;
		begin
			drive(wv);
			if ((dvalid !== 1'b1) || (nmag !== exp) || (xout !== tagx) || (yout !== tagy)) begin
				err_cnt = err_cnt + 1;
				$display("  [FAIL] win=%h  nms=%0d/%0d  xout=%0d/%0d", wv, nmag, exp, xout, tagx);
			end else begin
				ok_cnt = ok_cnt + 1;
			end
		end
	endtask

	//------------------------------------------------------------------
	// [A/B] 随机用例：独立参考模型
	//------------------------------------------------------------------
	task apply_ref;
		input [125:0] wv;
		reg [11:0] m00,m01,m02,m10,m11,m12,m20,m21,m22,n1,n2,exp;
		reg [1:0]  dc;
		begin
			m00=wv[123:112]; m01=wv[109:98]; m02=wv[95:84];
			m10=wv[81:70];   m11=wv[67:56];  m12=wv[53:42];
			m20=wv[39:28];   m21=wv[25:14];  m22=wv[11:0];
			dc = wv[69:68];
			case (dc)
				2'd0:	 begin n1 = m10; n2 = m12; end
				2'd2:	 begin n1 = m01; n2 = m21; end
				2'd1:	 begin n1 = m00; n2 = m22; end
				default: begin n1 = m02; n2 = m20; end
			endcase
			exp = ((m11 >= n1) && (m11 >= n2)) ? m11 : 12'd0;

			drive(wv);
			if ((dvalid !== 1'b1) || (nmag !== exp)) begin
				err_cnt = err_cnt + 1;
				if (err_cnt <= 8)
					$display("  [FAIL] win=%h  nms=%0d/%0d (dc=%0d)", wv, nmag, exp, dc);
			end else begin
				ok_cnt = ok_cnt + 1;
			end
		end
	endtask

	//------------------------------------------------------------------
	// 主流程
	//------------------------------------------------------------------
	initial begin
		repeat (4) @(negedge clk);
		rst_n = 1;
		@(negedge clk);

		$display("");
		$display("================ nms3x3 自检 ================");

		// dir=0（比 左/右 p10/p12）
		check_exp({px(0,0),px(0,0),px(0,0),   px(0,100),px(0,200),px(0,100),   px(0,0),px(0,0),px(0,0)}, 12'd200); // 中心最大 -> 保留
		check_exp({px(0,0),px(0,0),px(0,0),   px(0,200),px(0,100),px(0,50),    px(0,0),px(0,0),px(0,0)}, 12'd0);   // 左更大 -> 抑制
		// dir=2（比 上/下 p01/p21）
		check_exp({px(0,0),px(0,100),px(0,0), px(0,0),px(2,200),px(0,0),       px(0,0),px(0,100),px(0,0)}, 12'd200);
		check_exp({px(0,0),px(0,200),px(0,0), px(0,0),px(2,100),px(0,0),       px(0,0),px(0,50),px(0,0)}, 12'd0);
		// dir=1（比 左上/右下 p00/p22）
		check_exp({px(0,100),px(0,0),px(0,0), px(0,0),px(1,200),px(0,0),       px(0,0),px(0,0),px(0,100)}, 12'd200);
		check_exp({px(0,0),px(0,0),px(0,0),   px(0,0),px(1,100),px(0,0),       px(0,0),px(0,0),px(0,200)}, 12'd0); // p22 更大（区分映射）
		// dir=3（比 右上/左下 p02/p20）
		check_exp({px(0,0),px(0,0),px(0,100), px(0,0),px(3,200),px(0,0),       px(0,100),px(0,0),px(0,0)}, 12'd200);
		check_exp({px(0,0),px(0,0),px(0,200), px(0,0),px(3,100),px(0,0),       px(0,0),px(0,0),px(0,0)}, 12'd0);   // p02 更大（区分映射）
		// 平局边界（>=，两侧都保留）
		check_exp({px(0,0),px(0,0),px(0,0),   px(0,100),px(0,100),px(0,50),    px(0,0),px(0,0),px(0,0)}, 12'd100); // n1 平局
		check_exp({px(0,0),px(0,0),px(0,0),   px(0,50),px(0,100),px(0,100),    px(0,0),px(0,0),px(0,0)}, 12'd100); // n2 平局

		// 随机窗口
		for (k = 0; k < 100000; k = k + 1) begin
			w = {$random, $random, $random, $random};
			apply_ref(w);
		end

		$display(" 定向 + 随机用例总数 : %0d", ok_cnt + err_cnt);
		$display(" 通过               : %0d", ok_cnt);
		$display(" 错误               : %0d", err_cnt);
		$display("");
		if (err_cnt == 0)
			$display(" >>> ALL TESTS PASS");
		else
			$display(" >>> TEST FAILED  (err=%0d)", err_cnt);
		$display("=================================================");
		$display("");

		$finish;
	end

endmodule
