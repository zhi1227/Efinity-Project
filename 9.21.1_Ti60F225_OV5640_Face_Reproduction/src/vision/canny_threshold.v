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
//  阈值选择：
//      mag 满量程 0..2040（|Gx|+|Gy|，Sobel 3x3 的理论最大值）。
//      经验比例 TH_HIGH : TH_LOW = 2:1 ~ 3:1。
//      默认 160 / 80，作为 1280x720 实拍的起始值，后续按效果调。
//      调参规律：边缘断裂多 -> 降 TH_LOW；噪点多 -> 升 TH_LOW；
//                边缘丢失   -> 降 TH_HIGH。
//
//  x / y / valid 同步透传 1 拍。
//======================================================================
`timescale 1ns/1ps

module canny_threshold #(
	parameter [11:0] TH_HIGH = 12'd160,	// 强边阈值
	parameter [11:0] TH_LOW  = 12'd80,	// 弱边阈值（要求 TH_LOW <= TH_HIGH）
	parameter AWIDTH = 11				// 列地址位宽（640 用 10，1280 用 11）
)(
	input  wire					clk,
	input  wire					rst_n,		// 同步复位，低有效

	input  wire					valid_i,
	input  wire [AWIDTH-1:0]	x_i,
	input  wire [9:0]			y_i,
	input  wire [11:0]			mag_i,		// NMS 后的幅值

	output reg  [1:0]			cls_o,		// 0=非边 1=弱边 2=强边
	output reg					valid_o,
	output reg  [AWIDTH-1:0]	x_o,
	output reg  [9:0]			y_o
);

	//------------------------------------------------------------------
	// 双阈值分类（纯组合）
	//------------------------------------------------------------------
	wire [1:0] cls = (mag_i >= TH_HIGH) ? 2'd2 :
	                 (mag_i >= TH_LOW ) ? 2'd1 : 2'd0;

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
