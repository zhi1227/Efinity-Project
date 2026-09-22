//======================================================================
//  canny_threshold.v
//----------------------------------------------------------------------
//  Canny 双阈值分类。接在 NMS 之后，把细化后的梯度幅值分成三档：
//
//      mag >= TH_HIGH  ->  2 强边（一定是边缘）
//      mag >= TH_LOW   ->  1 弱边（仅当与强边连通时才是边缘）
//      其余            ->  0 非边
//
//  这是逐像素操作，不需要行缓存 / 窗口，纯组合比较 + 1 级输出寄存器。
//
//  输出编码（2bit，关键约定）：
//      cls_o = 0 : 非边
//      cls_o = 1 : 弱边
//      cls_o = 2 : 强边
//      之所以用 2bit 分类而不是 strong/weak 两个独立标志：
//      后级迟滞（hysteresis_local）需要把分类结果当作“像素”打包进
//      第 4 级 line_buffer_3x3（DWIDTH=2）开 3x3 窗口。
//      窗口内：邻居是强边 <=> (cls==2)，中心是弱边 <=> (cls==1)，
//      一个编码同时承载两种判决，无需额外标志位线。
//      编码 3 不使用（预留）。
//
//  阈值选择（两个来源，由 USE_PORTS 二选一）：
//      USE_PORTS = 0 : 用 TH_HIGH / TH_LOW 参数（编译期常量）
//      USE_PORTS = 1 : 用 th_high_i / th_low_i 端口（留给运行时调参，
//                      例如串口 / 旋转编码器）
//      两者都走同一个 th_hi / th_lo 中间量，分类逻辑只有一份。
//
//  ★ 历史 bug（已修）：本模块原来高阈值取 th_high_i、低阈值却取参数 TH_LOW，
//      导致 th_low_i 端口接了线但完全无效，且 TH_HIGH 参数也从未生效，
//      实际生效的是「端口高阈值 + 写死参数低阈值」的混搭组合。
//
//  mag 满量程 0..2040（|Gx|+|Gy|，Sobel 3x3 的理论最大值）。
//  经验比例 TH_HIGH : TH_LOW = 2:1 ~ 3:1，实拍起点 160 / 80。
//  调参规律：边缘断裂多 -> 降 TH_LOW；噪点多 -> 升 TH_LOW；
//            全黑/边缘丢失 -> 降 TH_HIGH（和 TH_LOW）。
//
//  x / y / valid 同步透传 1 拍。
//======================================================================
`timescale 1ns/1ps

module canny_threshold #(
	parameter [11:0] TH_HIGH = 12'd160,	// 强边阈值（USE_PORTS=0 时生效）
	parameter [11:0] TH_LOW  = 12'd80,	// 弱边阈值（要求 TH_LOW <= TH_HIGH）
	parameter        USE_PORTS = 1'b0,	// 0=用参数；1=用 th_high_i/th_low_i 端口
	parameter AWIDTH = 11				// 列地址位宽（640 用 10，1280 用 11）
)(
	input  wire					clk,
	input  wire					rst_n,		// 同步复位，低有效

	input  wire					valid_i,
	input  wire [AWIDTH-1:0]	x_i,
	input  wire [9:0]			y_i,
	input  wire [11:0]			mag_i,		// NMS 后的幅值
	input  wire [11:0]			th_high_i,	// 运行时高阈值（USE_PORTS=1 时生效）
	input  wire [11:0]			th_low_i,	// 运行时低阈值（USE_PORTS=1 时生效）

	output reg  [1:0]			cls_o,		// 0=非边 1=弱边 2=强边
	output reg					valid_o,
	output reg  [AWIDTH-1:0]	x_o,
	output reg  [9:0]			y_o
);

	//------------------------------------------------------------------
	// 阈值来源二选一（只有一个 th_hi / th_lo，分类逻辑不再分叉）
	//------------------------------------------------------------------
	wire [11:0] th_hi = USE_PORTS ? th_high_i : TH_HIGH;
	wire [11:0] th_lo = USE_PORTS ? th_low_i  : TH_LOW;

	//------------------------------------------------------------------
	// 双阈值分类（纯组合）
	//------------------------------------------------------------------
	wire [1:0] cls = (mag_i >= th_hi) ? 2'd2 :
	                 (mag_i >= th_lo) ? 2'd1 : 2'd0;

	//------------------------------------------------------------------
	// 输出寄存（1 拍流水）
	//------------------------------------------------------------------
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			cls_o   <= 2'd0;
			valid_o <= 1'b0;
			x_o     <= {AWIDTH{1'b0}};
			y_o     <= 10'd0;
		end else begin
			cls_o   <= cls;
			valid_o <= valid_i;
			x_o     <= x_i;
			y_o     <= y_i;
		end
	end

endmodule
