//======================================================================
//  canny_threshold_ports_tb.v —— USE_PORTS=1（端口取阈值）自检测试台
//----------------------------------------------------------------------
//  验证目标：
//    [A] 端口路径定向：参数 TH_HIGH/TH_LOW 故意设成离谱值 1000/1000，
//        阈值**只**由 th_high_i/th_low_i 端口提供（160/80）。
//        → 若 RTL 把低阈值退回成参数，mag=100 会被判成 0 而非 1。
//          这是对历史 bug（低阈值取参数、th_low_i 端口失效）的定向回归。
//    [B] 动态改阈值：运行中把端口改成 240/120、再改成 60/30，必须立刻生效
//        （证明端口是组合读取的，不是复位时锁存一次）。
//    [C] 随机 100000 组固定阈值 + 50000 组随机阈值，与端口驱动的参考模型比对
//    [D] x / y / valid 透传 1 拍
//
//  参考模型用与 RTL **反向的表述**：RTL 用 >= 从高往低判，
//  参考用 < 从低往高判。边界方向写反（> 与 >= 混淆）必然暴露。
//======================================================================
`timescale 1ns/1ns

module canny_threshold_ports_tb;

	reg 				clk = 0;
	reg 				rst_n = 0;
	reg 				valid_i = 0;
	reg  [10:0]			xin = 0;
	reg  [9:0]			yin = 0;
	reg  [11:0]			mag = 0;
	reg  [11:0]			th_h = 12'd160;
	reg  [11:0]			th_l = 12'd80;

	wire [1:0]			cls;
	wire				dvalid;
	wire [10:0]			xout;
	wire [9:0]			yout;

	// ★ 参数故意与端口不一致：只有端口值才是期望值
	canny_threshold #(
		.TH_HIGH	(12'd1000),
		.TH_LOW		(12'd1000),
		.USE_PORTS	(1'b1),
		.AWIDTH		(11)
	) u_dut (
		.clk		(clk),
		.rst_n		(rst_n),
		.valid_i	(valid_i),
		.x_i		(xin),
		.y_i		(yin),
		.mag_i		(mag),
		.th_high_i	(th_h),
		.th_low_i	(th_l),
		.cls_o		(cls),
		.valid_o	(dvalid),
		.x_o		(xout),
		.y_o		(yout)
	);

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 参考模型：用端口阈值，< 从低往高判
	//------------------------------------------------------------------
	function [1:0] ref_cls;
		input [11:0] m;
		begin
			if (m < th_l)      ref_cls = 2'd0;
			else if (m < th_h) ref_cls = 2'd1;
			else               ref_cls = 2'd2;
		end
	endfunction

	integer err_cnt = 0;
	integer ok_cnt  = 0;
	integer k;
	reg [10:0] tagx = 0;
	reg [9:0]  tagy = 0;

	//------------------------------------------------------------------
	// 驱动 + 自检：送一个 mag，1 拍后核对 cls / x / y / valid
	//------------------------------------------------------------------
	task drive_check;
		input [11:0] mv;
		begin
			tagx = tagx + 1;
			if (tagx == 1280) begin tagx = 0; tagy = tagy + 1; end
			@(negedge clk);
			mag = mv; valid_i = 1; xin = tagx; yin = tagy;
			@(negedge clk);
			valid_i = 0;
			if (dvalid !== 1'b1) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] valid_o 未拉高 mag=%0d th=%0d/%0d", mv, th_h, th_l);
			end else if (cls !== ref_cls(mv)) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] mag=%0d th=%0d/%0d cls=%0d expect=%0d",
				         mv, th_h, th_l, cls, ref_cls(mv));
			end else if (xout !== tagx || yout !== tagy) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] 坐标不对齐 mag=%0d", mv);
			end else begin
				ok_cnt = ok_cnt + 1;
			end
		end
	endtask

	initial begin
		repeat (4) @(negedge clk);
		rst_n = 1;
		@(negedge clk);

		//--------------------------------------------------------------
		// [A] 定向边界（端口 160 / 80）
		//--------------------------------------------------------------
		th_h = 12'd160; th_l = 12'd80;
		@(negedge clk);
		drive_check(12'd0);		// -> 0
		drive_check(12'd79);	// -> 0
		drive_check(12'd80);	// -> 1（恰好取下限）
		drive_check(12'd81);	// -> 1
		drive_check(12'd100);	// ★ bug 探测器：旧代码低阈值用参数 1000 -> 误判 0
		drive_check(12'd159);	// -> 1
		drive_check(12'd160);	// -> 2（恰好取上限）
		drive_check(12'd161);	// -> 2
		drive_check(12'd2040);	// -> 2（满量程）

		//--------------------------------------------------------------
		// [B] 动态改阈值，必须立刻生效
		//--------------------------------------------------------------
		th_h = 12'd240; th_l = 12'd120;
		@(negedge clk);
		drive_check(12'd119);	// -> 0
		drive_check(12'd120);	// -> 1
		drive_check(12'd200);	// ★ bug 探测器：应为 1；旧代码(参数1000) -> 误判 0
		drive_check(12'd239);	// -> 1
		drive_check(12'd240);	// -> 2

		th_h = 12'd60; th_l = 12'd30;
		@(negedge clk);
		drive_check(12'd29);	// -> 0
		drive_check(12'd30);	// -> 1
		drive_check(12'd59);	// -> 1
		drive_check(12'd60);	// -> 2

		//--------------------------------------------------------------
		// [C] 随机固定阈值 100000 组
		//--------------------------------------------------------------
		th_h = 12'd160; th_l = 12'd80;
		@(negedge clk);
		for (k = 0; k < 100000; k = k + 1) begin
			drive_check({$random} % 2041);		// 0..2040 全量程
		end

		//--------------------------------------------------------------
		// [D] 随机 mag + 随机阈值（每 1000 组换档）
		//--------------------------------------------------------------
		for (k = 0; k < 50000; k = k + 1) begin
			if (k % 1000 == 0) begin
				@(negedge clk);
				th_l = ({$random} % 200);					// 0..199
				th_h = th_l + (({$random} % 300) + 12'd1);	// th_l+1 .. th_l+300
			end
			drive_check({$random} % 2041);
		end

		//--------------------------------------------------------------
		// 汇总
		//--------------------------------------------------------------
		@(negedge clk);
		$display("==================================================");
		$display("  canny_threshold_ports_tb: ok=%0d err=%0d", ok_cnt, err_cnt);
		if (err_cnt == 0) $display("  *** ALL PASS ***");
		else              $display("  *** FAIL ***");
		$display("==================================================");
		$finish;
	end

endmodule
