//======================================================================
//  line_buffer_3x3.v
//----------------------------------------------------------------------
//  3x3 滑动窗口行缓存。Canny 链路（高斯 / 中值 / Sobel / NMS）的公共基础。
//
//  设计要点：
//    * 内部 2 块同步读 BRAM：prev_line_1（上一行）、prev_line_2（上两行）。
//      “当前行”不是 BRAM，而是把输入流延迟 1 拍后直接进移位寄存器，
//      这样和 BRAM 的 1 拍同步读延迟天然对齐，省掉 1 块 BRAM。
//    * BRAM 采用“读地址 = 当前列，写地址 = 当前列-1”的错位写法：
//      同一拍内读/写地址永远不同（避免同地址读写冲突），
//      并且读出的永远是“本帧内已经写完整的上/上上行”，不会读到当前行。
//    * 三条流（当前行 / 上一行 / 上两行）在输出拍全部对齐到同一列 k，
//      各自再经过 3 抽头移位寄存器，即得到以列 (k-1) 为中心的 3x3 窗口。
//
//  时序 / 坐标约定（重要，下游模块必须按此对齐）：
//      输入：de_i=1 时 x_i / y_i / data_i 有效（x_i 从 0 开始，y_i 从 0 开始）
//      输出：window_valid 有效那一拍，
//              x_o = 窗口中心列 = 输入列 - 1
//              y_o = 窗口中心行 = 输入行 - 1
//      窗口像素与 window_o 的位序：
//               window_o = {row2_sr, row1_sr, cur_sr}
//               row2_sr  = {p00, p01, p02}   // y_o-1 行，x_o-1 / x_o / x_o+1
//               row1_sr  = {p10, p11, p12}   // y_o   行
//               cur_sr   = {p20, p21, p22}   // y_o+1 行
//         即 p00 在最高位 [9*DW-1 : 8*DW]，p22 在最低位 [DW-1 : 0]。
//         每条行内 3 抽头寄存器均为 {最左(老), 中间, 最右(新)}。
//
//  有效窗口出现条件：
//      window_valid = de 延迟1拍 && (x_d1 >= 2) && (row_ready == 2)
//      x_d1 >= 2   -> 中心列 x_o >= 1，左右邻列都在本行内
//      row_ready==2 -> 本帧已经完整处理过 2 行，上/上上行数据真实有效
//      因此第 0、1 行不产生窗口，第 2 行从 x_o=1 开始产生窗口，
//      最后一行最后一列 x_o = WIDTH-2 仍然有效，最右侧 1 列（x_o=WIDTH-1）
//      因为右邻列越界而不输出（3x3 固有边界，属预期行为）。
//
//  frame_start：
//      每帧开始给 1 个（或以上）clk 的高电平脉冲，用于清 row_ready 计数器。
//      建议直接接 VSync 上升沿打一拍产生的单周期脉冲（de_i=0 期间给出）。
//      若该信号被长时间拉高，则 row_ready 一直为 0，模块不输出有效窗口。
//
//  WIDTH 支持 640 / 1280（AWIDTH 相应取 10 / 11）。
//======================================================================
`timescale 1ns/1ps

module line_buffer_3x3 #(
	parameter WIDTH  = 1280,	// 行宽（像素数）
	parameter DWIDTH = 8,		// 像素位宽
	parameter AWIDTH = 11		// 列地址位宽，需满足 2**AWIDTH >= WIDTH
)(
	input  wire					clk,
	input  wire					rst_n,			// 同步复位，低有效
	input  wire					frame_start,	// 帧起始脉冲（高有效）
	input  wire					de_i,			// 数据使能
	input  wire [AWIDTH-1:0]	x_i,			// 输入列坐标
	input  wire [9:0]			y_i,			// 输入行坐标
	input  wire [DWIDTH-1:0]	data_i,			// 输入像素

	output wire [9*DWIDTH-1:0]	window_o,		// 3x3 窗口
	output reg					window_valid,	// 窗口有效（与 x_o/y_o 同拍）
	output reg  [AWIDTH-1:0]	x_o,			// 窗口中心列
	output reg  [9:0]			y_o				// 窗口中心行
);

	//------------------------------------------------------------------
	// 0. 输入流打 1 拍
	//    cur_d1  : 当前行像素（与 BRAM 同步读输出对齐）
	//    x_d1    : 列坐标延迟 1 拍（同时当作 BRAM 写地址）
	//    y_d1    : 行坐标延迟 1 拍
	//    de_d1   : 数据使能延迟 1 拍（写使能 + 移位使能）
	//------------------------------------------------------------------
	reg [DWIDTH-1:0]	cur_d1;
	reg [AWIDTH-1:0]	x_d1;
	reg [9:0]			y_d1;
	reg					de_d1;

	wire				dv = de_i && (x_i < WIDTH);	// 地址合法保护

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cur_d1 <= {DWIDTH{1'b0}};
			x_d1   <= {AWIDTH{1'b0}};
			y_d1   <= 10'd0;
			de_d1  <= 1'b0;
		end else begin
			if (de_i) begin
				cur_d1 <= data_i;
				x_d1   <= (x_i < WIDTH) ? x_i : {AWIDTH{1'b0}};
				y_d1   <= y_i;
			end
			de_d1 <= dv;
		end
	end

	//------------------------------------------------------------------
	// 1. 两块同步读 BRAM：prev_line_1 / prev_line_2
	//    读地址 = x_i（当拍列），输出延迟 1 拍得到“上一行同列”像素。
	//    写地址 = x_d1（前当拍列），与读地址错开 1，读写不同址。
	//    prev_line_2 的写入数据取 prev_line_1 的读出数据，形成 2 级行延迟链。
	//------------------------------------------------------------------
	(* ram_style = "block" *) (* ramstyle = "block" *)
	reg [DWIDTH-1:0] prev_line_1 [0:WIDTH-1];
	(* ram_style = "block" *) (* ramstyle = "block" *)
	reg [DWIDTH-1:0] prev_line_2 [0:WIDTH-1];

	reg [DWIDTH-1:0] rd1_dout;
	reg [DWIDTH-1:0] rd2_dout;

	always @(posedge clk) begin
		if (de_d1) begin
			prev_line_1[x_d1] <= cur_d1;		// 写入当前行
			prev_line_2[x_d1] <= rd1_dout;		// 级联写入上一行
		end
		rd1_dout <= prev_line_1[x_i];			// 同步读 -> 上一行同列
		rd2_dout <= prev_line_2[x_i];			// 同步读 -> 上两行同列
	end

	//------------------------------------------------------------------
	// 2. 每条行的 3 抽头移位寄存器
	//    sr 位序 = {最左, 中间, 最右}，最右为最新进来的像素。
	//    行首（x_d1==0）先清零，保证不把上一行行尾串进来。
	//    移位只在 de_d1==1 时进行，因此消隐期不会拉入无效数据。
	//------------------------------------------------------------------
	reg [3*DWIDTH-1:0] cur_sr;	// y   行：(x-2, x-1, x)
	reg [3*DWIDTH-1:0] row1_sr;	// y-1 行
	reg [3*DWIDTH-1:0] row2_sr;	// y-2 行

	// Cascaded cropped streams start at x=1,2,3..., not x=0.
	reg previous_valid;
	reg [9:0] previous_y;
	reg [1:0] samples_in_row;
	wire new_line = de_d1 && (!previous_valid || y_d1 != previous_y);
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin previous_valid<=0; previous_y<=0; samples_in_row<=0; end
		else if(frame_start) begin previous_valid<=0; samples_in_row<=0; end
		else begin
			previous_valid<=de_d1;
			if(de_d1) begin
				previous_y<=y_d1;
				if(new_line) samples_in_row<=1;
				else if(samples_in_row<2) samples_in_row<=samples_in_row+1'b1;
			end
		end
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cur_sr  <= {3*DWIDTH{1'b0}};
			row1_sr <= {3*DWIDTH{1'b0}};
			row2_sr <= {3*DWIDTH{1'b0}};
		end else if (de_d1) begin
			if (new_line) begin
				// 行首：填入唯一一个有效样本，其余置 0（本拍窗口必无效）
				cur_sr  <= {{2*DWIDTH{1'b0}}, cur_d1};
				row1_sr <= {{2*DWIDTH{1'b0}}, rd1_dout};
				row2_sr <= {{2*DWIDTH{1'b0}}, rd2_dout};
			end else begin
				// 最新样本进低位，原内容向高位推：丢弃最高 DWIDTH 位（最老的抽头）
				cur_sr  <= {cur_sr[2*DWIDTH-1:0], cur_d1};
				row1_sr <= {row1_sr[2*DWIDTH-1:0], rd1_dout};
				row2_sr <= {row2_sr[2*DWIDTH-1:0], rd2_dout};
			end
		end
	end

	// 窗口输出：移位后一拍，sr 恰好覆盖 (x_o-1, x_o, x_o+1)
	assign window_o = {row2_sr, row1_sr, cur_sr};

	//------------------------------------------------------------------
	// 3. 行就绪计数：每行结束 +1，饱和到 2
	//    只有 row_ready==2 时才说明 prev_line_1/2 里是本帧的真实行。
	//------------------------------------------------------------------
	reg		de_q;
	wire	de_fall = de_q & ~de_i;		// 行结束（DE 下降沿）

	reg [1:0] row_ready;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			de_q      <= 1'b0;
			row_ready <= 2'd0;
		end else begin
			de_q <= de_i;
			if (frame_start) begin
				row_ready <= 2'd0;
			end else if (de_fall && (row_ready != 2'd2)) begin
				row_ready <= row_ready + 2'd1;
			end
		end
	end

	//------------------------------------------------------------------
	// 4. 输出坐标与有效标志（与上面移位后的 sr 同拍）
	//    sr 移位发生在 de_d1 那一拍，输出在下一拍：
	//      x_o = x_d1 - 1,  y_o = y_d1 - 1
	//    组合逻辑产生，保证与 window_o（组合取自 sr）严格同拍。
	//------------------------------------------------------------------
	reg we_next;
	reg [AWIDTH-1:0] x_o_d;
	reg [9:0]        y_o_d;

	always @(*) begin
		we_next = de_d1 && (samples_in_row == 2) && (row_ready == 2'd2) && !new_line && !frame_start;
		x_o_d   = x_d1 - {{(AWIDTH-1){1'b0}}, 1'b1};
		y_o_d   = y_d1 - 10'd1;
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			window_valid <= 1'b0;
			x_o          <= {AWIDTH{1'b0}};
			y_o          <= 10'd0;
		end else begin
			window_valid <= we_next;
			x_o          <= x_o_d;
			y_o          <= y_o_d;
		end
	end

endmodule
