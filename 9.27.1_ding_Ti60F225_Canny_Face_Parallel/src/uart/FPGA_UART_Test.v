/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2013-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		www.crazyfpga.com
Email Address 		: 		crazyfpga@vip.qq.com
Filename			:		PC2FPGA_UART_Test.v
Date				:		2013-10-31
Description			:		Test UART Communication between PC and FPGA. + 发送框数量改造
Modification History	:
Date			By			Version			Change Description
=========================================================================
13/10/31		CrazyBingo	1.0				Original
25/11/04		User		1.1				增加发送框数量功能
-------------------------------------------------------------------------
|                                     Oooo								|
+------------------------------oooO--(   )-----------------------------+
                              (   )   ) /
                               \ (   (_/
                                \_)
----------------------------------------------------------------------*/   

`timescale 1ns/1ns
module FPGA_UART_Test
(
	//global clock
//	input				clk,                //24MHz
//	input				rst_n,
    input               pll_inst1_CLKOUT0,  //96MHz
    input               pll_inst1_LOCKED,
	
	//user interface
	input				fpga_rxd,		//pc 2 fpga uart receiver
	output				fpga_txd,		//fpga 2 pc uart transfer	

    // 新增接口
    input       [7:0]   ccl_count,    // 连通域数量
    input               frame_end      // 每帧结束脉冲 (高电平一个周期即可)
);

wire    clk_ref = pll_inst1_CLKOUT0;    //96MHz
wire    sys_rst_n = pll_inst1_LOCKED;


//------------------------------------
//Precise clk divider
wire	divide_clken;
integer_divider	
#(
	.DEVIDE_CNT	(52)	//115200bps * 16
//	.DEVIDE_CNT	(625)	//9600bps * 16
)
u_integer_devider
(
	//global
	.clk				(clk_ref),		//96MHz clock
	.rst_n				(sys_rst_n),    //global reset
	
	//user interface
	.divide_clken		(divide_clken)
);

wire	clken_16bps = divide_clken;

//---------------------------------
//Data receive for PC to FPGA.
wire			rxd_flag;
wire	[7:0]	rxd_data;
uart_receiver	u_uart_receiver
(
	//gobal clock
	.clk			(clk_ref),
	.rst_n			(sys_rst_n),
	
	//uart interface
	.clken_16bps	(clken_16bps),	//clk_bps * 16
	.rxd			(fpga_rxd),		//uart txd interface
	
	//user interface
	.rxd_data		(rxd_data),		//uart data receive
	.rxd_flag		(rxd_flag)  	//uart data receive done
);

//---------------------------------
// 优先级状态机：优先发送框数，其次回显PC发的数据
reg [7:0] txd_data_mux = 0;
reg txd_en_mux = 0;
reg txd_flag_mux = 0; // 发送完成消隐（建议可加可不加，部分 uart_transfer 支持 txd_flag）

always @(posedge clk_ref or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        txd_data_mux <= 8'd0;
        txd_en_mux   <= 1'b0;
        txd_flag_mux <= 1'b0;
    end else if (frame_end) begin
        txd_data_mux <= ccl_count;
        txd_en_mux   <= 1'b1;
    end else if (rxd_flag) begin
        txd_data_mux <= rxd_data;
        txd_en_mux   <= 1'b1;
    end else begin
        txd_en_mux   <= 1'b0;
    end
end

// 串口发送模块，发送txd_data_mux而不是原始rxd_data
uart_transfer	u_uart_transfer
(
	//gobal clock
	.clk			(clk_ref),
	.rst_n			(sys_rst_n),
	
	//uaer interface
	.clken_16bps	(clken_16bps),	//clk_bps * 16
	.txd			(fpga_txd),  	//uart txd interface
           
	//user interface   
	.txd_en			(txd_en_mux),	//优先级选择后的发送使能
	.txd_data		(txd_data_mux), //优先级选择后的数据
	.txd_flag		()              //uart data transfer done, 可接txd_flag_mux用作消隐（通常不需特殊处理）
);

endmodule