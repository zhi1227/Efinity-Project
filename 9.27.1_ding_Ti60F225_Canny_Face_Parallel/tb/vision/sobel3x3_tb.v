//======================================================================
//  sobel3x3_tb.v   —— 自检测试台
//----------------------------------------------------------------------
//  验证目标：
//    [A] Gx / Gy 梯度公式正确        —— 用「手算期望值」的定向边缘用例做真值
//    [B] L1 幅值 mag = |Gx|+|Gy|     —— 定向 + 随机
//    [C] 方向量化 dir                —— 0/45/90/135 各取向 + 因子2边界
//    [D] x / y / valid 透传对齐（1 拍延迟）
//
//  为什么要两套校验：
//    * 随机用例的参考模型与 RTL 用同一套公式，只能抓「实现笔误」
//      （位切片下标错、像素拿错），抓不到「公式本身设计错」。
//    * 定向用例的期望值是**脱离公式、按空间直觉手算**的
//      （竖直边 -> dir=0、水平边 -> dir=90、对角 -> 45/135），
//      即使 RTL 与参考模型同时把公式写错，定向用例也能暴露。
//
//  覆盖：9 组定向 + 100000 组随机窗口。
//======================================================================
`timescale 1ns/1ns

module sobel3x3_tb;

	reg 				clk = 0;
	reg 				rst_n = 0;
	reg 				win_valid = 0;
	reg  [10:0]			xin = 0;
	reg  [9:0]			yin = 0;
	reg  [71:0]			win = 0;

	wire [11:0]			mag;
	wire [1:0]			dir;
	wire				dvalid;
	wire [10:0]			xout;
	wire [9:0]			yout;

	sobel3x3 #(.AWIDTH(11)) u_dut (
		.clk			(clk),
		.rst_n			(rst_n),
		.win_valid_i	(win_valid),
		.x_i			(xin),
		.y_i			(yin),
		.window_i		(win),
		.mag_o			(mag),
		.dir_o			(dir),
		.valid_o		(dvalid),
		.x_o			(xout),
		.y_o			(yout)
	);

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 打包 9 个值：pack9(p00,p01,p02, p10,p11,p12, p20,p21,p22)
	//------------------------------------------------------------------
	function [71:0] pack9;
		input [7:0] v0,v1,v2,v3,v4,v5,v6,v7,v8;
		begin
			pack9 = {v0,v1,v2,v3,v4,v5,v6,v7,v8};
		end
	endfunction

	integer err_cnt = 0;
	integer ok_cnt  = 0;
	integer k;
	reg [71:0] w;
	reg [10:0] tagx = 0;
	reg [9:0]  tagy = 0;

	//------------------------------------------------------------------
	// 公共驱动：施加一个窗口，下一拍读 DUT
	//------------------------------------------------------------------
	task drive;
		input [71:0] wv;
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
	// [A/B/C] 定向用例：期望值手算（公式真值）
	//------------------------------------------------------------------
	task check_exp;
		input [71:0] wv;
		input [11:0] exp_mag;
		input [1:0]  exp_dir;
		begin
			drive(wv);
			if ((dvalid !== 1'b1) || (mag !== exp_mag) || (dir !== exp_dir) ||
			    (xout !== tagx) || (yout !== tagy)) begin
				err_cnt = err_cnt + 1;
				$display("  [FAIL] win=%h  mag=%0d/%0d dir=%0d/%0d  xout=%0d/%0d",
				         wv, mag, exp_mag, dir, exp_dir, xout, tagx);
			end else begin
				ok_cnt = ok_cnt + 1;
			end
		end
	endtask

	//------------------------------------------------------------------
	// [B/C] 随机用例：独立参考模型（同公式，抓实现笔误）
	//------------------------------------------------------------------
	task apply_ref;
		input [71:0] wv;
		integer p00,p01,p02,p10,p12,p20,p21,p22;
		integer gx_r, gy_r, agx_r, agy_r, mag_r;
		integer dir_r;
		begin
			p00=wv[71:64]; p01=wv[63:56]; p02=wv[55:48];
			p10=wv[47:40];               p12=wv[31:24];
			p20=wv[23:16]; p21=wv[15:8];  p22=wv[7:0];

			gx_r = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20);
			gy_r = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02);
			agx_r = (gx_r < 0) ? -gx_r : gx_r;
			agy_r = (gy_r < 0) ? -gy_r : gy_r;
			mag_r = agx_r + agy_r;
			if (agx_r >= 2*agy_r)         dir_r = 0;
			else if (agy_r >= 2*agx_r)    dir_r = 2;
			else if ((gx_r<0)==(gy_r<0))  dir_r = 1;
			else                          dir_r = 3;

			drive(wv);
			if ((dvalid !== 1'b1) || (mag !== mag_r[11:0]) || (dir !== dir_r[1:0])) begin
				err_cnt = err_cnt + 1;
				if (err_cnt <= 8)
					$display("  [FAIL] win=%h  mag=%0d/%0d dir=%0d/%0d",
					         wv, mag, mag_r, dir, dir_r);
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
		$display("================ sobel3x3 自检 ================");

		// 1. 竖直边（亮在右）-> 水平梯度 -> dir=0, mag=1020
		check_exp(pack9(  0,  0,255,   0,  0,255,   0,  0,255), 12'd1020, 2'd0);
		// 2. 竖直边（亮在左）-> dir=0
		check_exp(pack9(255,  0,  0, 255,  0,  0, 255,  0,  0), 12'd1020, 2'd0);
		// 3. 水平边（亮在下）-> 竖直梯度 -> dir=90
		check_exp(pack9(  0,  0,  0,   0,  0,  0, 255,255,255), 12'd1020, 2'd2);
		// 4. 水平边（亮在上）-> dir=90
		check_exp(pack9(255,255,255,   0,  0,  0,   0,  0,  0), 12'd1020, 2'd2);
		// 5. 对角边（亮在右下三角）-> dir=45, mag=1530
		check_exp(pack9(  0,  0,255,   0,255,255, 255,255,255), 12'd1530, 2'd1);
		// 6. 对角边（亮在右上三角）-> dir=135, mag=1530
		check_exp(pack9(  0,255,255,   0,  0,255,   0,  0,  0), 12'd1530, 2'd3);
		// 7. 平坦 -> mag=0, dir=0
		check_exp(pack9(128,128,128, 128,128,128, 128,128,128), 12'd0,    2'd0);
		// 8. 因子2边界：gx=100, gy=50, agx==2agy -> 判 0°
		check_exp(pack9(  0,  0,100,   0,  0,  0,   0, 75,  0), 12'd150,  2'd0);
		// 9. 反对角小梯度：gx=100, gy=-100 -> dir=135, mag=200
		check_exp(pack9(  0,  0,100,   0,  0,  0,   0,  0,  0), 12'd200,  2'd3);

		// 随机窗口
		for (k = 0; k < 100000; k = k + 1) begin
			w = {$random, $random, $random};
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
