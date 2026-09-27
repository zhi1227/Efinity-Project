//======================================================================
//  hysteresis_local_tb.v   —— 自检测试台
//----------------------------------------------------------------------
//  验证目标：
//    [A] 强边直通：中心=2 时无论邻居如何，edge=1
//    [B] 弱边激活：中心=1 时，8 个邻居位置逐一放置强边，edge 必须=1
//        （逐位置验证，确保 9 个窗口槽位解码没有错位）
//    [C] 弱边抑制：中心=1 且邻居无强边（含邻居有弱边的情况），edge=0
//    [D] 非边不提升：中心=0 时即使邻居全是强边，edge=0
//    [E] x / y / valid 透传对齐（1 拍延迟）
//    [F] 随机：100000 组随机窗口，与独立参考模型比对
//
//  关键：[B] 逐邻居位置定向验证 —— 如果 p00..p22 的位序解错，
//        某个位置上的强边就不会被识别，对应用例必然失败。
//        参考模型用与 RTL 不同的写法（for 循环扫描邻居数组）。
//
//  窗口打包：9 x cls[1:0] = 18bit，p00 在最高位 [17:16]。
//======================================================================
`timescale 1ns/1ns

module hysteresis_local_tb;

	reg 				clk = 0;
	reg 				rst_n = 0;
	reg 				win_valid = 0;
	reg  [10:0]			xin = 0;
	reg  [9:0]			yin = 0;
	reg  [17:0]			win = 0;

	wire				edge_out;
	wire				dvalid;
	wire [10:0]			xout;
	wire [9:0]			yout;

	hysteresis_local #(.AWIDTH(11)) u_dut (
		.clk			(clk),
		.rst_n			(rst_n),
		.win_valid_i	(win_valid),
		.x_i			(xin),
		.y_i			(yin),
		.window_i		(win),
		.edge_o			(edge_out),
		.valid_o		(dvalid),
		.x_o			(xout),
		.y_o			(yout)
	);

	always #5 clk = ~clk;

	//------------------------------------------------------------------
	// 打包：窗口 = 9 个 2bit 分类拼接，下标 0..8 = p00..p22，p00 最高位
	//------------------------------------------------------------------
	function [17:0] pack9;
		input [1:0] c0; input [1:0] c1; input [1:0] c2;
		input [1:0] c3; input [1:0] c4; input [1:0] c5;
		input [1:0] c6; input [1:0] c7; input [1:0] c8;
		begin pack9 = {c0, c1, c2, c3, c4, c5, c6, c7, c8}; end
	endfunction

	//------------------------------------------------------------------
	// 独立参考模型：数组 + for 循环（与 RTL 平铺写法不同）
	//------------------------------------------------------------------
	function ref_edge;
		input [17:0] w;
		reg [1:0] cc [0:8];
		reg       strong_nb;
		integer   i;
		begin
			for (i = 0; i < 9; i = i + 1)
				cc[i] = w[17-2*i -: 2];
			strong_nb = 0;
			for (i = 0; i < 9; i = i + 1)
				if (i != 4 && cc[i] == 2'd2) strong_nb = 1;
			if (cc[4] == 2'd2)      ref_edge = 1'b1;
			else if (cc[4] == 2'd1) ref_edge = strong_nb;
			else                    ref_edge = 1'b0;
		end
	endfunction

	integer err_cnt = 0;
	integer ok_cnt  = 0;
	integer k, pos;
	reg [10:0] tagx = 0;
	reg [9:0]  tagy = 0;
	reg [17:0] w;
	reg [1:0]  cc_r [0:8];

	//------------------------------------------------------------------
	// 驱动 + 自检
	//------------------------------------------------------------------
	task drive_check;
		input [17:0] wv;
		begin
			tagx = tagx + 1;
			if (tagx == 1280) begin tagx = 0; tagy = tagy + 1; end
			@(negedge clk);
			win = wv; win_valid = 1; xin = tagx; yin = tagy;
			@(negedge clk);
			win_valid = 0;
			if (dvalid !== 1'b1) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] valid_o 未拉高 win=%h", wv);
			end else if (edge_out !== ref_edge(wv)) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] win=%h edge=%b expect=%b", wv, edge_out, ref_edge(wv));
			end else if (xout !== xin || yout !== yin) begin
				err_cnt = err_cnt + 1;
				$display("[ERR] 坐标不对齐 win=%h", wv);
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
		// [A] 强边直通：中心=2，邻居分别取 全0 / 全弱 / 全强
		//--------------------------------------------------------------
		drive_check(pack9(0,0,0, 0,2,0, 0,0,0));
		drive_check(pack9(1,1,1, 1,2,1, 1,1,1));
		drive_check(pack9(2,2,2, 2,2,2, 2,2,2));

		//--------------------------------------------------------------
		// [B] 弱边激活：中心=1，8 个邻居位置逐一放强边（其余为 0）
		//     每个位置都必须让 edge=1 —— 验证位序解码
		//--------------------------------------------------------------
		for (pos = 0; pos < 9; pos = pos + 1) begin
			if (pos != 4) begin
				for (k = 0; k < 9; k = k + 1) cc_r[k] = 2'd0;
				cc_r[4]   = 2'd1;	// 中心弱边
				cc_r[pos] = 2'd2;	// 被测邻居位放强边
				w = {cc_r[0],cc_r[1],cc_r[2],cc_r[3],cc_r[4],
				     cc_r[5],cc_r[6],cc_r[7],cc_r[8]};
				drive_check(w);
			end
		end

		//--------------------------------------------------------------
		// [C] 弱边抑制：中心=1，邻居 全0 / 全非边弱边混合（无强边）
		//--------------------------------------------------------------
		drive_check(pack9(0,0,0, 0,1,0, 0,0,0));	// 孤立弱边 -> 0
		drive_check(pack9(1,1,1, 1,1,1, 1,1,1));	// 全是弱边 -> 0
		drive_check(pack9(0,1,0, 1,1,1, 0,1,0));	// 十字弱边 -> 0

		//--------------------------------------------------------------
		// [D] 非边不提升：中心=0，邻居全强边也必须是 0
		//--------------------------------------------------------------
		drive_check(pack9(2,2,2, 2,0,2, 2,2,2));

		//--------------------------------------------------------------
		// [F] 随机：100000 组
		//--------------------------------------------------------------
		for (k = 0; k < 100000; k = k + 1) begin
			// 偏向产生 0/1/2 三类（编码 3 也应按非边处理，顺带覆盖）
			for (pos = 0; pos < 9; pos = pos + 1) begin
				case ($random % 8)
					0,1,2:	cc_r[pos] = 2'd0;
					3,4,5:	cc_r[pos] = 2'd1;
					6:		cc_r[pos] = 2'd2;
					default:cc_r[pos] = 2'd3;	// 预留编码，按非边处理
				endcase
			end
			w = {cc_r[0],cc_r[1],cc_r[2],cc_r[3],cc_r[4],
			     cc_r[5],cc_r[6],cc_r[7],cc_r[8]};
			drive_check(w);
		end

		@(negedge clk);
		$display("==================================================");
		$display("  hysteresis_local_tb: ok=%0d err=%0d", ok_cnt, err_cnt);
		if (err_cnt == 0) $display("  *** ALL PASS ***");
		else              $display("  *** FAIL ***");
		$display("==================================================");
		$finish;
	end

endmodule
