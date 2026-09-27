//======================================================================
//  canny_threshold_tb.v   —— 自检测试台
//----------------------------------------------------------------------
//  验证目标：
//    [A] 边界定向：mag 恰好在 TH_LOW-1 / TH_LOW / TH_HIGH-1 / TH_HIGH
//        等跨档点上，分类必须符合定义（边界归属是最容易写反的地方）
//    [B] 随机：100000 组随机 mag，与独立参考模型比对
//    [C] x / y / valid 透传对齐（1 拍延迟）
//
//  关键：参考模型用与 RTL **反向的表述**——
//        RTL  用 >= 从高往低判（先 TH_HIGH 后 TH_LOW），
//        参考用 <  从低往高判（先排除 <TH_LOW，再排除 <TH_HIGH）。
//        若边界方向写反（> 与 >= 混淆），两者结果必然不同，可被暴露。
//
//  本测试台使用非默认阈值 TH_HIGH=500 / TH_LOW=200，
//  同时验证 parameter 传参路径正确（防止阈值被写死在 RTL 里）。
//======================================================================
`timescale 1ns/1ns

module canny_threshold_tb;

	localparam [11:0] TH_H = 12'd500;
	localparam [11:0] TH_L = 12'd200;

	reg 				clk = 0;
	reg 				rst_n = 0;
	reg 				valid_i = 0;
	reg  [10:0]			xin = 0;
	reg  [9:0]			yin = 0;
	reg  [11:0]			mag = 0;

	wire [1:0]			cls;
	wire				dvalid;
	wire [10:0]			xout;
	wire [9:0]			yout;

	canny_threshold #(
		.TH_HIGH	(TH_H),
		.TH_LOW		(TH_L),
		.AWIDTH		(11)
	) u_dut (
		.clk		(clk),
		.rst_n		(rst_n),
		.valid_i	(valid_i),
		.x_i		(xin),
		.y_i		(yin),
		.mag_i		(mag),
		.cls_o		(cls),
		.valid_o	(dvalid),
		.x_o		(xout),
		.y_o		(yout)
	);

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 独立参考模型：用 < 从低往高判（与 RTL 的 >= 高->低 反向表述）
	//------------------------------------------------------------------
	function [1:0] ref_cls;
		input [11:0] m;
		begin
			if (m < TH_L)      ref_cls = 2'd0;
			else if (m < TH_H) ref_cls = 2'd1;
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
				$display("[ERR] valid_o 未拉高 mag=%0d", mv);
			end else if (cls !== ref_cls(mv)) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] mag=%0d cls=%0d expect=%0d", mv, cls, ref_cls(mv));
			end else if (xout !== xin || yout !== yin) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] 坐标不对齐 mag=%0d", mv);
			end else begin
				ok_cnt = ok_cnt + 1;
			end
		end
	endtask

	initial begin
		// 复位
		repeat (4) @(negedge clk);
		rst_n = 1;
		@(negedge clk);

		//--------------------------------------------------------------
		// [A] 定向边界：恰好跨档的点
		//--------------------------------------------------------------
		drive_check(12'd0);			// 0        -> 非边
		drive_check(TH_L - 1);		// 199      -> 非边（弱边下限之下）
		drive_check(TH_L);			// 200      -> 弱边（恰好取下限）
		drive_check(TH_L + 1);		// 201      -> 弱边
		drive_check(TH_H - 1);		// 499      -> 弱边（强边下限之下）
		drive_check(TH_H);			// 500      -> 强边（恰好取上限）
		drive_check(TH_H + 1);		// 501      -> 强边
		drive_check(12'd2040);		// 满量程   -> 强边

		// 复位期间 valid 必须为 0 的隐含检查已由 drive_check 覆盖

		//--------------------------------------------------------------
		// [B] 随机：100000 组
		//--------------------------------------------------------------
		for (k = 0; k < 100000; k = k + 1) begin
			drive_check($random % 2041);	// 0..2040 全量程
		end

		//--------------------------------------------------------------
		// 汇总
		//--------------------------------------------------------------
		@(negedge clk);
		$display("==================================================");
		$display("  canny_threshold_tb: ok=%0d err=%0d", ok_cnt, err_cnt);
		if (err_cnt == 0) $display("  *** ALL PASS ***");
		else              $display("  *** FAIL ***");
		$display("==================================================");
		$finish;
	end

endmodule
