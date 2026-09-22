`timescale 1ns/1ps

//`include "ddr3_controller.vh"


module example_top 
(
	////////////////////////////////////////////////////////////////
	//	External Clock & Reset
	//input 			nrst, 			//	Button K2
	input 			clk_24m,			//	24MHz Crystal
	input 			clk_25m,			//	25MHz Crystal 
	
	
	////////////////////////////////////////////////////////////////
	//	System Clock
	output 			sys_pll_rstn_o, 		
	
	input 			clk_sys,			//	Sys PLL 96MHz 
	input 			clk_pixel,			//	Sys PLL 74.25MHz
	input 			clk_pixel_2x,		//	Sys PLL 148.5MHz
	input 			clk_pixel_10x,		//	Sys PLL 742.5MHz
	
	input 			sys_pll_lock,		//	Sys PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	MIPI-DSI Clock & Reset
	output 			dsi_pll_rstn_o,
	
	input 			dsi_refclk_i,		//	48MHz Reference Clock (for DSI PLL)
	input 			dsi_byteclk_i,		//	DSI Byte Clock (1X)
	input 			dsi_serclk_i,		//	DSI Serial Clock (4X 45)
	input 			dsi_txcclk_i,		//	DSI Serial Clock (4X 135)
	
	input 			dsi_pll_lock,
	
	////////////////////////////////////////////////////////////////
	//	DDR Clock
	output 			ddr_pll_rstn_o, 
	
	input 			tdqss_clk,			
	input 			core_clk,			//	DDR PLL 200MHz
	input 			tac_clk,			
	input 			twd_clk,			
	
	input 			ddr_pll_lock,		//	DDR PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	DDR PLL Phase Shift Interface
	output 	[2:0] 	shift,
	output 	[4:0] 	shift_sel,
	output 			shift_ena,
	
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Clock
	output 			lvds_pll_rstn_o, 
	
	input 			clk_lvds_1x, 
	input 			clk_lvds_7x, 
	input 			clk_27m, 			//	RGB 1X Clock (16MHz)
	input 			clk_54m, 			//	RGB 2X Clock (32MHz, for export control)
	
	input 			lvds_pll_lock, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DDR Interface Ports
	output 	[15:0] 	addr,
	output 	[2:0] 	ba,
	output 			we,
	output 			reset,
	output 			ras,
	output 			cas,
	output 			odt,
	output 			cke,
	output 			cs,
	
	//	DQ I/O
	input 	[15:0] 	i_dq_hi,
	input 	[15:0] 	i_dq_lo,
	
	output 	[15:0] 	o_dq_hi,
	output 	[15:0] 	o_dq_lo,
	output 	[15:0] 	o_dq_oe,
	
	//	DM O
	output 	[1:0] 	o_dm_hi,
	output 	[1:0] 	o_dm_lo,
	
	//	DQS I/O
	input 	[1:0] 	i_dqs_hi,
	input 	[1:0] 	i_dqs_lo,
	
	input 	[1:0] 	i_dqs_n_hi,
	input 	[1:0] 	i_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_hi,
	output 	[1:0] 	o_dqs_lo,
	
	output 	[1:0] 	o_dqs_n_hi,
	output 	[1:0] 	o_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_oe,
	output 	[1:0] 	o_dqs_n_oe,
	
	//	CK
	output 			clk_p_hi, 
	output 			clk_p_lo, 
	output 			clk_n_hi, 
	output 			clk_n_lo, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Ctl / I2C
	output 			csi_ctl0_o,
	output 			csi_ctl0_oe,
	input 			csi_ctl0_i,
	
	output 			csi_ctl1_o,
	output 			csi_ctl1_oe,
	input 			csi_ctl1_i,
	
	output 			csi_scl_o,
	output 			csi_scl_oe,
	input 			csi_scl_i,
	
	output 			csi_sda_o,
	output 			csi_sda_oe,
	input 			csi_sda_i,
	
	//	MIPI-CSI RXC 
	input 			csi_rxc_lp_p_i,
	input 			csi_rxc_lp_n_i,
	output 			csi_rxc_hs_en_o,
	output 			csi_rxc_hs_term_en_o,
	input 			csi_rxc_i,
	
	//	MIPI-CSI RXD0
	output 			csi_rxd0_rst_o,
	output 			csi_rxd0_hs_en_o,
	output 			csi_rxd0_hs_term_en_o,
	
	input 			csi_rxd0_lp_p_i,
	input 			csi_rxd0_lp_n_i,
	input 	[7:0] 	csi_rxd0_hs_i,
	
	//	MIPI-CSI RXD1
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	//	MIPI-CSI RXD2
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	//	MIPI-CSI RXD3
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	//output 			csi_rxd0_fifo_rd_o, 
	//input 			csi_rxd0_fifo_empty_i, 
	//output 			csi_rxd1_fifo_rd_o, 
	//input 			csi_rxd1_fifo_empty_i, 
	//output 			csi_rxd2_fifo_rd_o, 
	//input 			csi_rxd2_fifo_empty_i, 
	//output 			csi_rxd3_fifo_rd_o, 
	//input 			csi_rxd3_fifo_empty_i, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DSI PWM & Reset Control 
	output 			dsi_pwm_o,			//	MIPI-DSI LCD PWM
	output 			dsi_resetn_o,		//	MIPI-DSI LCD Reset
	
	//	MIPI-DSI TXC / TXD
	output 			dsi_txc_rst_o,
	output 			dsi_txc_lp_p_oe,
	output 			dsi_txc_lp_p_o,
	output 			dsi_txc_lp_n_oe,
	output 			dsi_txc_lp_n_o,
	output 			dsi_txc_hs_oe,
	output 	[7:0] 	dsi_txc_hs_o,
	
	output 			dsi_txd0_rst_o,
	output 			dsi_txd0_hs_oe,
	output 	[7:0] 	dsi_txd0_hs_o,
	output 			dsi_txd0_lp_p_oe,
	output 			dsi_txd0_lp_p_o,
	output 			dsi_txd0_lp_n_oe,
	output 			dsi_txd0_lp_n_o,
	
	output 			dsi_txd1_rst_o,
	output 			dsi_txd1_lp_p_oe,
	output 			dsi_txd1_lp_p_o,
	output 			dsi_txd1_lp_n_oe,
	output 			dsi_txd1_lp_n_o,
	output 			dsi_txd1_hs_oe,
	output 	[7:0] 	dsi_txd1_hs_o,
	
	output 			dsi_txd2_rst_o,
	output 			dsi_txd2_lp_p_oe,
	output 			dsi_txd2_lp_p_o,
	output 			dsi_txd2_lp_n_oe,
	output 			dsi_txd2_lp_n_o,
	output 			dsi_txd2_hs_oe,
	output 	[7:0] 	dsi_txd2_hs_o,
	
	output 			dsi_txd3_rst_o,
	output 			dsi_txd3_lp_p_oe,
	output 			dsi_txd3_lp_p_o,
	output 			dsi_txd3_lp_n_oe,
	output 			dsi_txd3_lp_n_o,
	output 			dsi_txd3_hs_oe,
	output 	[7:0] 	dsi_txd3_hs_o,
	
	input 			dsi_txd0_lp_p_i,
	input 			dsi_txd0_lp_n_i,
	input 			dsi_txd1_lp_p_i,
	input 			dsi_txd1_lp_n_i,
	input 			dsi_txd2_lp_p_i,
	input 			dsi_txd2_lp_n_i,
	input 			dsi_txd3_lp_p_i,
	input 			dsi_txd3_lp_n_i,
	
	
	////////////////////////////////////////////////////////////////
	//	UART Interface
	input 		 	uart_rx_i,			//	Support 460800-8-N-1. 
	output 		 	uart_tx_o, 
	
	
	output 	[5:0] 	led_o,			//	
	
	
	////////////////////////////////////////////////////////////////
	//	CMOS Sensor
	output 			cmos_sclk,
	input 			cmos_sdat_IN,
	output 			cmos_sdat_OUT,
	output 			cmos_sdat_OE,
	
	//	CMOS Interface
	input 			cmos_pclk,
	input 			cmos_vsync,
	input 			cmos_href,
	input 	[7:0] 	cmos_data,
	
	output 			cmos_ctl1_o, 
	output 			cmos_ctl1_oe, 
	input 			cmos_ctl1_i,
	output 			cmos_ctl2_o,
	output 			cmos_ctl2_oe, 
	input 			cmos_ctl2_i, 
	output 			cmos_ctl3_o,
	output 			cmos_ctl3_oe, 
	input 			cmos_ctl3_i, 
	
	
	////////////////////////////////////////////////////////////////
	//	HDMI Interface
	output 			hdmi_txc_oe,
	output 			hdmi_txd0_oe,
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,
	output 			hdmi_txd0_rst_o,
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,
	output 	[9:0] 	hdmi_txd0_o,
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Interface
	output 			lvds_txc_oe,
	output 	[6:0] 	lvds_txc_o,
	output 			lvds_txc_rst_o,
	
	output 			lvds_txd0_oe,
	output 	[6:0] 	lvds_txd0_o,
	output 			lvds_txd0_rst_o,
	
	output 			lvds_txd1_oe,
	output 	[6:0] 	lvds_txd1_o,
	output 			lvds_txd1_rst_o,
	
	output 			lvds_txd2_oe,
	output 	[6:0] 	lvds_txd2_o,
	output 			lvds_txd2_rst_o,
	
	output 			lvds_txd3_oe,
	output 	[6:0] 	lvds_txd3_o,
	output 			lvds_txd3_rst_o,
	
	
	////////////////////////////////////////////////////////////////
	//	RGB LCD 5Inch 800x480
	output 			lcd_tp_sda_o,		//	TP SDA
	output 			lcd_tp_sda_oe,
	input 			lcd_tp_sda_i,
	
	output 			lcd_tp_scl_o,		//	TP SCL
	output 			lcd_tp_scl_oe,
	input 			lcd_tp_scl_i,
	
	output 			lcd_tp_int_o,		//	TP INT
	output 			lcd_tp_int_oe,
	input 			lcd_tp_int_i,
	
	output 			lcd_tp_rst_o,		//	TP RST
	
	output 			lcd_pwm_o,			//	Backlight
	output 			lcd_blen_o,
	
	//output 			lcd_pclk_o,			//	PCLK & SCK Mux
	output 			lcd_vs_o,			//	VS & SSN Mux. Fixed to 1. Use DE-Only mode. 
	output 			lcd_hs_o,			//	HS. Fixed to 1. Use DE-Only mode. 
	output 			lcd_de_o,			//	DE. 

	output 	[7:0] 	lcd_b7_0_o,			//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_o,			//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_o,			//	R7:R0. 
	
	output 	[7:0] 	lcd_b7_0_oe,		//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_oe,		//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_oe,		//	R7:R0. 

	input 	[7:0] 	lcd_b7_0_i,			//	B7:B0. 
	input 	[7:0] 	lcd_g7_0_i,			//	G7:G0. Must output 8'hFF when access SPI. 
	input 	[7:0] 	lcd_r7_0_i,			//	R7:R0. 
	
	//	SPI Pins
	output 			spi_sck_o, 
	output 			spi_ssn_o 			
);
	
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	
	parameter 	SIM_DATA 	= 0; 
	
	//	Hardware Configuration
	assign clk_p_hi = 1'b0;	//	DDR3 Clock requires 180 degree shifted. 
	assign clk_p_lo = 1'b1;
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; 
	
	assign cmos_ctl1_o = 0; 
	assign cmos_ctl1_oe = 1; 
	assign cmos_ctl2_o = 0; 
	assign cmos_ctl2_oe = 1; 
	assign cmos_ctl3_o = 0; 
	assign cmos_ctl3_oe = 1; 
	
	//	System Clock Tree Control
	assign sys_pll_rstn_o = 1'b1; 	//	nrst; 	//	Reset whole system when nrst (K2) is pressed. 
	
	assign dsi_pll_rstn_o = sys_pll_lock; 
	assign ddr_pll_rstn_o = sys_pll_lock; 
	assign lvds_pll_rstn_o = sys_pll_lock; 
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	
	//	Synchronize System Resets. 
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	//	Clock Gen
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	//	System clock using 96MHz. 
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Flash Burner Control
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 			w_ustick, w_mstick; 
	
	wire  [7:0] 	w_dev_index_o;  
	wire  [7:0] 	w_dev_cmd_o;  
	wire  [31:0] 	w_dev_wdata_o;  
	wire  		w_dev_wvalid_o;  
	wire  		w_dev_rvalid_o;  
	wire 	[31:0] 	w_dev_rdata_i;  
	
	wire 			w_spi_ssn_o, w_spi_sck_o; 
	wire 	[3:0] 	w_spi_data_o, w_spi_data_oe; 
	wire 	[3:0] 	w_spi_data_i; 
	
	//	Flash Control
	reg 			r_flash_en = 0; 		//	0x00:0x00 Enable Flash
	
	always @(posedge clk_sys) begin
		r_flash_en <= (w_dev_wvalid_o && (w_dev_index_o == 8'h00) && (w_dev_cmd_o == 8'h00)) ? w_dev_wdata_o : r_flash_en; 
	end
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	LCD Data Mux
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 	[7:0] 	w_lcd_b_o, w_lcd_g_o, w_lcd_r_o; 
	
	assign lcd_b7_0_o = r_flash_en ? {4'b0, w_spi_data_o[3:2], 2'b0} : w_lcd_b_o; 
	assign lcd_g7_0_o = r_flash_en ? {6'h0, w_spi_data_o[1:0]} : w_lcd_g_o; 
	assign lcd_r7_0_o = r_flash_en ? {8'h00} : w_lcd_r_o; 
	
	assign lcd_b7_0_oe = r_flash_en ? {4'b0, w_spi_data_oe[3:2], 2'b0} : 8'hFF; 
	assign lcd_g7_0_oe = r_flash_en ? {6'h0, w_spi_data_oe[1:0]} : 8'hFF; 
	assign lcd_r7_0_oe = r_flash_en ? {8'h00} : 8'hFF; 
	
	assign spi_sck_o = w_spi_sck_o; 
	assign spi_ssn_o = w_spi_ssn_o; 
	assign w_spi_data_i = {lcd_b7_0_i[3:2], lcd_g7_0_i[1:0]}; 
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	DDR3 Controller
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire			w_ddr3_ui_clk = clk_sys;
	wire			w_ddr3_ui_rst = rst_sys;
	wire			w_ddr3_ui_areset = rst_sys;
	wire			w_ddr3_ui_aresetn = rstn_sys;
	

	//	General AXI Interface 
	wire	[3:0] 	w_ddr3_awid;
	wire	[31:0]	w_ddr3_awaddr;
	wire	[7:0]		w_ddr3_awlen;
	wire			w_ddr3_awvalid;
	wire			w_ddr3_awready;
	
	wire 	[3:0]  	w_ddr3_wid;
	wire 	[127:0] 	w_ddr3_wdata;
	wire 	[15:0]	w_ddr3_wstrb;
	wire			w_ddr3_wlast;
	wire			w_ddr3_wvalid;
	wire			w_ddr3_wready;
	
	wire 	[3:0] 	w_ddr3_bid;
	wire 	[1:0] 	w_ddr3_bresp;
	wire			w_ddr3_bvalid;
	wire			w_ddr3_bready;
	
	wire	[3:0] 	w_ddr3_arid;
	wire	[31:0]	w_ddr3_araddr;
	wire	[7:0]		w_ddr3_arlen;
	wire			w_ddr3_arvalid;
	wire			w_ddr3_arready;
	
	wire 	[3:0] 	w_ddr3_rid;
	wire 	[127:0] 	w_ddr3_rdata;
	wire			w_ddr3_rlast;
	wire			w_ddr3_rvalid;
	wire			w_ddr3_rready;
	wire 	[1:0] 	w_ddr3_rresp;
	
	
	//	AXI Interface Request
	wire 	[3:0] 	w_ddr3_aid;
	wire 	[31:0] 	w_ddr3_aaddr;
	wire 	[7:0]  	w_ddr3_alen;
	wire 	[2:0]  	w_ddr3_asize;
	wire 	[1:0]  	w_ddr3_aburst;
	wire 	[1:0]  	w_ddr3_alock;
	wire			w_ddr3_avalid;
	wire			w_ddr3_aready;
	wire			w_ddr3_atype;
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; 
	
	//	Do not issue DDR read / write when ~cal_done. 
	reg 			r_ddr_unlock = 0; 
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(o_dqs_n_oe),
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid),	//	Enable command only when unlocked. 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_wid),
		.axi_wvalid		(w_ddr3_wvalid),
		.axi_wready		(w_ddr3_wready),
		.axi_wdata		(w_ddr3_wdata),
		.axi_wstrb		(w_ddr3_wstrb),
		.axi_wlast		(w_ddr3_wlast),
		
		.axi_bvalid		(w_ddr3_bvalid),
		.axi_bready		(w_ddr3_bready),
		.axi_bid		(w_ddr3_bid),
		.axi_bresp		(w_ddr3_bresp),
		
		.axi_rvalid		(w_ddr3_rvalid),
		.axi_rready		(w_ddr3_rready),
		.axi_rdata		(w_ddr3_rdata),
		.axi_rid		(w_ddr3_rid),
		.axi_rresp		(w_ddr3_rresp),
		.axi_rlast		(w_ddr3_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	
	assign w_ddr3_bready = 1'b1; 
	assign shift_sel = 5'b00100; 		//	ddr_tac_clk always use PLLOUT[2]. 
	
	
	AXI4_AWARMux #(.AID_LEN(4), .AADDR_LEN(32)) axi4_awar_mux (
		.aclk_i			(w_ddr3_ui_clk), 
		.arst_i			(w_ddr3_ui_rst), 
		
		.awid_i			(w_ddr3_awid),
		.awaddr_i			(w_ddr3_awaddr),
		.awlen_i			(w_ddr3_awlen),
		.awvalid_i			(w_ddr3_awvalid && r_ddr_unlock),
		.awready_o			(w_ddr3_awready),
		
		.arid_i			(w_ddr3_arid),
		.araddr_i			(w_ddr3_araddr),
		.arlen_i			(w_ddr3_arlen),
		.arvalid_i			(w_ddr3_arvalid && r_ddr_unlock),
		.arready_o			(w_ddr3_arready),
		
		.aid_o			(w_ddr3_aid),
		.aaddr_o			(w_ddr3_aaddr),
		.alen_o			(w_ddr3_alen),
		.atype_o			(w_ddr3_atype),
		.avalid_o			(w_ddr3_avalid),
		.aready_i			(w_ddr3_aready)
	);
	
	assign w_ddr3_asize = 4; 		//	Fixed 128 bits (16 bytes, size = 4)
	assign w_ddr3_aburst = 1; 
	assign w_ddr3_alock = 0; 
	
	//assign led_o[1:0] = {w_ddr3_cal_pass, w_ddr3_cal_done}; 
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	I2C Config (OV5640)
	
	//  i2c timing controller module of 16Bit
	wire            [ 7:0]          ov5640_i2c_config_index;
	wire            [23:0]          ov5640_i2c_config_data;
	wire            [ 7:0]          ov5640_i2c_config_size;
	wire                            ov5640_i2c_config_done;
	wire            [15:0]          ov5640_i2c_rdata;                              //  i2c register data

	i2c_timing_ctrl_16bit
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                              //  100 MHz
	    .I2C_FREQ           (50_000    )                               //  10 KHz(<= 400KHz)
	) 
	u_i2c_timing_ctrl_16bit 
	(
	    //global clock
	    .clk                (clk_sys                 ),                          //  96MHz
	    .rst_n              (rstn_sys                ),                          //  system reset

	    //i2c interface
	    .i2c_sclk           (cmos_sclk                  ),                  //  i2c clock
		.i2c_sdat_OUT 	(cmos_sdat_OUT), 
		.i2c_sdat_OE	(cmos_sdat_OE), 
		.i2c_sdat_IN 	(cmos_sdat_IN), 
		
	    //i2c config data
	    .i2c_config_index   (ov5640_i2c_config_index           ),                  //  i2c config reg index, read 2 reg and write xx reg
	    .i2c_config_data    ({8'h78, ov5640_i2c_config_data}   ),                  //  i2c config data
	    .i2c_config_size    (ov5640_i2c_config_size            ),                  //  i2c config data counte
	    .i2c_config_done    (ov5640_i2c_config_done            ),                  //  i2c config timing complete
	    .i2c_rdata          (ov5640_i2c_rdata                  )                   //  i2c register data while read i2c slave
	);
	
	//----------------------------------------------------------------------
	//  I2C Configure Data of OV5640
	I2C_OV5640_1280720_Config u_I2C_OV5640_1280720_Config
	(
	    .LUT_INDEX  (ov5640_i2c_config_index   ),
	    .LUT_DATA   (ov5640_i2c_config_data    ),
	    .LUT_SIZE   (ov5640_i2c_config_size    )
	); 
	
	
	//	CMOS Interface
	//input 			cmos_pclk,
	//input 			cmos_vsync,
	//input 			cmos_href,
	//input 	[7:0] 	cmos_data,
	
	wire 			w_cmos_pclk = cmos_pclk; 
	
	
	
	//	Output LED
	reg 	[3:0]		r_cmos_fv_o = 0; 
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; 
	always @(posedge w_cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	assign led_o[5] = r_cmos_fv_o[3]; 
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	System Control. Can be removed for public. 
	
	localparam 	CLK_FREQ 	= 96_000_000; 	//	clk_sys is 96MHz. 
	localparam 	BAUD_RATE 	= 460_800; 		//	Use 460800-8-N-1. 
	
	
	//	SFR I/O Interface
	wire 	[7:0] 	w_sfr_addr_o; 	//	SFR Address (0xFF00 ~ 0xFFFF). 00:Power; 40~5F:Stream0; 60~7F:Stream1. 
	wire 	[7:0] 	w_sfr_wdata_o; 	//	SFR Write Data. 
	wire 			w_sfr_we_o; 		//	SFR WE. 
	reg 	[7:0] 	w_sfr_rdata_i; 	//	Must be valid after sfr_rd_o. 
	wire 			w_sfr_rd_o; 		//	SFR RD. 
	
	
	//	System Control Registers
	reg 			r_dsi_tx_rstn = 0; 	//	DSI TX Reset
	reg 	[7:0] 	r_dsi_pwm = 64; 		//	[6:0]PWM, [7]Pol
	reg 			r_dsi_resetn_o = 0; 	//	DSI Panel Reset
	reg 			r_dsi_data_rstn = 0; 	//	DSI TX Reset
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	//	AXI-Lite Interface Bridge
	localparam 	CSI_AXILITE_ID 	= 0; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	localparam 	DSI_AXILITE_ID 	= 1; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		//	0xE0 (RW)
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	//	0xE1~0xE4 (RW)
	wire 	[31:0] 	w_axi_rdata; 			//	0xE5~0xE8 (RO)
	reg 	[0:0] 	r_axi_sel = 1; 			//	0xE9[7:2] (RW)
	reg 			r_axi_r1w0 = 0; 			//	0xE9[1] (RW)
	reg 			r_axi_req = 0; 			//	0xE9[0] (WO, Single Cycle)
	reg 			r_axi_req_o = 0; 			//	Delayed of r_axi_req. 
	
	
	//	Buffered AXI Read Data
	reg 	[31:0] 	r_axi_rdata = 0; 		//	Use state machine
	reg 			r_axi_idle = 0; 		//	AXI Idle 
	
	reg 	[3:0] 	rs_axilite = 0; 		//	AXI Access
	wire 	[3:0] 	ws_axilite_idle = 0; 		
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin
			r_dsi_tx_rstn <= 0; 
			r_dsi_pwm <= 64; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; 
	
	assign csi_ctl0_oe = 0; 
	assign csi_ctl1_oe = 0; 
	
	
	assign dsi_pwm_o = 1'b0;   // DSI unused in HDMI-only edge-detection build.






	////////////////////////////////////////////////////////////////
	//	MIPI CSI RX
	
	//	The CSI RXC shall not be inverted. Data can be inverted with swapped LP data and flipped HS data. 
	localparam 	CSI_RXD_INV 	= 4'b1111; 
	localparam 	CSI_DATA_WIDTH 	= 8; 			
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; 

	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Crop
	
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[63:0]	XYCrop_frame_Gray;

	Sensor_Image_XYCrop
	#(
		//	RGB width doubled. 
		.IMAGE_HSIZE_SOURCE (1280 * 2 / CSI_STRB_WIDTH),
		.IMAGE_VSIZE_SOURCE (720	 ),
		.IMAGE_HSIZE_TARGET (1280 * 2 / CSI_STRB_WIDTH),
		.IMAGE_YSIZE_TARGET (720 	 ),
		.PIXEL_DATA_WIDTH	(CSI_DATA_WIDTH) 		//	32		 )
	)
	u_Sensor_Image_XYCrop
	(
		//	globel clock
		.clk			(w_cmos_pclk),			//	image pixel clock
		.rst_n		(rstn_sys),			//	system reset
		
		//CMOS Sensor interface
		.image_in_vsync (cmos_vsync		),			//H : Data Valid; L : Frame Sync(Set it by register)
		.image_in_href	(cmos_href		),			//H : Data vaild, L : Line Sync
		.image_in_de	(cmos_href		), 			//H : Data Enable, L : Line Sync
		.image_in_data	(cmos_data),			//8 bits cmos data input
		
		.image_out_vsync(XYCrop_frame_vsync ),			//H : Data Valid; L : Frame Sync(Set it by register)
		.image_out_href (XYCrop_frame_href	),			//H : Data vaild, L : Line Sync
		.image_out_de	(XYCrop_frame_de	), 			//H : Data Enable, L : Line Sync
		.image_out_data (XYCrop_frame_Gray	)			//8 bits cmos data input	
	);

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_cmos_pclk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	//	Data Write Assignment
	wire			cmos_frame_vsync = r_XYCrop_frame_vsync;                     //  cmos frame data vsync valid signal
	wire			cmos_frame_href = r_XYCrop_frame_href && r_XYCrop_frame_de;	 //  cmos frame data href vaild  signal
	wire	[63:0]	cmos_frame_Gray = r_XYCrop_frame_Gray; 
	wire 			cmos_vsync_end;

	












	////////////////////////////////////////////////////////////////
	//	DDR R/W Control
	

	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire 	[11:0] 			lcd_xpos;
	wire 	[11:0] 			lcd_ypos;
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [15:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
	//	Write in 8 bits. Read in 16 bits. 
	axi4_ctrl #(.C_RD_END_ADDR(1280 * 2 * 720), .C_W_WIDTH(CSI_DATA_WIDTH), .C_R_WIDTH(16), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),

		.axi_awaddr     (w_ddr3_awaddr       ),
		.axi_awlen      (w_ddr3_awlen        ),
		.axi_awvalid    (w_ddr3_awvalid      ),
		.axi_awready    (w_ddr3_awready      ),

		.axi_wdata      (w_ddr3_wdata        ),
		.axi_wstrb      (w_ddr3_wstrb        ),
		.axi_wlast      (w_ddr3_wlast        ),
		.axi_wvalid     (w_ddr3_wvalid       ),
		.axi_wready     (w_ddr3_wready       ),

		.axi_bid        (0          ),
		.axi_bresp      (0        ),
		.axi_bvalid     (1       ),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_ddr3_araddr       ),
		.axi_arlen      (w_ddr3_arlen        ),
		.axi_arvalid    (w_ddr3_arvalid      ),
		.axi_arready    (w_ddr3_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (0        ),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_ddr3_rvalid       ),
		.axi_rready     (w_ddr3_rready       ),

		.wframe_pclk    (w_cmos_pclk          ),
		.wframe_vsync   (cmos_frame_vsync), //w_wframe_vsync   ),		//	Writter VSync. Flush on rising edge. Connect to EOF. 
		.wframe_data_en (cmos_frame_href   ),
		.wframe_data    (cmos_frame_Gray),
		
		.rframe_pclk    (clk_pixel            ),
		.rframe_vsync   (~lcd_vs             ),		//	Reader VSync. Flush on rising edge. Connect to ~EOF. 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),
		
		.tp_o 		(w_axi_tp)
	);
	assign led_o[3:0] = w_axi_tp; 
	
	
	
	
	////////////////////////////////////////////////////////////////
	//  LCD Timing Driver
	//  note: 原实现用左移补零 {R5, 3'b0} 扩展，白色只能到 248，
	//        已改为交给 rgb565_to_rgb888 做 MSB 复制扩展（可达 255）。
	////////////////////////////////////////////////////////////////
	//	----------------------------------------------------------------
	//	RGB565 -> RGB888 显示级扩展（MSB 复制）
	//	TMDS 三通道各 8bit 是硬约束，16bit 模式不存在，故必须扩到 24bit。
	//	----------------------------------------------------------------
	wire 	[23:0]	w_expand_rgb888;
	wire 	[7:0] 	rgb666_r;
	wire 	[7:0] 	rgb666_g;
	wire 	[7:0] 	rgb666_b;
	
	rgb565_to_rgb888 u_rgb565_to_rgb888_disp
	(
		.rgb565_i	(lcd_data        ),
		.rgb888_o	(w_expand_rgb888 )
	);
	assign rgb666_r = w_expand_rgb888[23:16];
	assign rgb666_g = w_expand_rgb888[15:8];
	assign rgb666_b = w_expand_rgb888[7:0];
	
	wire 	[7:0] 	lcd_data_r = rgb666_r[7:0];
	wire 	[7:0] 	lcd_data_g = rgb666_g[7:0];
	wire 	[7:0] 	lcd_data_b = rgb666_b[7:0];
	
	lcd_driver u_lcd_driver
	(
	    //  global clock
	    .clk        (clk_pixel   ),
	    .rst_n      (rstn_pixel), 
	    
	    //  lcd interface
	    .lcd_dclk   (               ),
	    .lcd_blank  (               ),
	    .lcd_sync   (               ),
	    .lcd_request(lcd_request    ), 	//	Request data 1 cycle ahead. 
	    .lcd_hs     (lcd_hs         ),
	    .lcd_vs     (lcd_vs         ),
	    .lcd_en     (lcd_de         ),
	    .lcd_rgb    ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	    //  user interface
	    .lcd_xpos   (lcd_xpos       ),
	    .lcd_ypos   (lcd_ypos       ),
	    .lcd_data   ({lcd_data_r, lcd_data_g, lcd_data_b}  )
	);
	
	
	
	////////////////////////////////////////////////////////////////
	//  Canny 边缘检测链路（中值滤波替代高斯）
	//	----------------------------------------------------------------
	//	数据流：
	//	  lcd_data(RGB565) → rgb565_to_gray → [LB#1] → median3x3
	//	  → [LB#2] → sobel3x3 → [LB#3,{dir,mag}14b] → nms3x3
	//	  → canny_threshold → [LB#4,cls 2b] → hysteresis_local
	//	  → 边缘二值图 → 显示
	//
	//	输入源说明：用 lcd_data（DDR 读回的原始 RGB565）而不是
	//	lcd_red/green/blue —— 后两者已被 lcd_driver 打包成 {R,G,B,0} 的
	//	48bit 交错格式，取出来拼回 565 反而绕。lcd_data 就是纯净的 565。
	//
	//	坐标：lcd_driver 的 lcd_xpos/lcd_ypos 在 lcd_request 有效时计数，
	//	比 lcd_de 提前 1 拍、比 lcd_data 提前 1 拍。这里统一用 lcd_request
	//	作 valid 源，并同步延迟 lcd_data / lcd_de 各 1 拍对齐。
	//
	//	窗口化级共 4 个，每级一个 line_buffer_3x3 实例。
	////////////////////////////////////////////////////////////////

	//----------------------------------------------------------------
	// 0. 对齐：lcd_request 当拍 → data/de 在下一拍
	//    lcd_driver 内部：lcd_request 提前 1 拍，r_lcd_rgb <= lcd_data，
	//    故 lcd_data 与 (lcd_request 延迟 1 拍) 同拍。
	//----------------------------------------------------------------
	reg [15:0] canny_rgb565_d;
	reg        canny_valid_d;
	reg [11:0] canny_x_d;
	reg [11:0] canny_y_d;

	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) begin
			canny_rgb565_d <= 16'd0;
			canny_valid_d  <= 1'b0;
			canny_x_d      <= 12'd0;
			canny_y_d      <= 12'd0;
		end else begin
			canny_rgb565_d <= lcd_data;
			canny_valid_d  <= lcd_request;
			canny_x_d      <= lcd_xpos;
			canny_y_d      <= lcd_ypos;
		end
	end

	//	帧起始脉冲：lcd_vs 的上升沿（rframe_vsync 用的是 ~lcd_vs）
	reg lcd_vs_q;
	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) lcd_vs_q <= 1'b0;
		else             lcd_vs_q <= lcd_vs;
	end
	wire canny_frame_start = lcd_vs & ~lcd_vs_q;

	//	帧结束脉冲：lcd_vs 的下降沿单拍。
	//	人脸链路（CCL 冲刷）需要一个“本帧像素已全部送完”的时刻，
	//	在此时刻注入若干虚拟零行，强制 finalize 贴边的连通域。
	//	之所以不用 lcd_vs 直接当 frame_end，是因为 lcd_vs 是电平，
	//	不是单拍脉冲；CCL 的冲刷状态机只认一个周期的触发。
	reg  lcd_vs_qq;
	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) lcd_vs_qq <= 1'b0;
		else             lcd_vs_qq <= lcd_vs_q;
	end
	wire lcd_vs_fall = lcd_vs_q & ~lcd_vs_qq;

	//----------------------------------------------------------------
	// 1. 灰度化（RGB565 -> 8bit）
	//----------------------------------------------------------------
	wire [7:0]  gray_w;
	wire        gray_de;
	wire [10:0] gray_x;
	wire [9:0]  gray_y;

	rgb565_to_gray #(.AWIDTH(11)) u_canny_gray
	(
		.clk		(clk_pixel     ),
		.rst_n		(rstn_pixel    ),
		.de_i		(canny_valid_d ),
		.x_i		(canny_x_d[10:0]),
		.y_i		(canny_y_d[9:0] ),
		.rgb565_i	(canny_rgb565_d),
		.gray_o		(gray_w        ),
		.de_o		(gray_de       ),
		.x_o		(gray_x        ),
		.y_o		(gray_y        )
	);

	//----------------------------------------------------------------
	// 2. 行缓存 #1 + 中值滤波
	//----------------------------------------------------------------
	wire [71:0] med_win;
	wire        med_win_v;
	wire [10:0] med_win_x;
	wire [9:0]  med_win_y;

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(11)) u_canny_lb1
	(
		.clk			(clk_pixel     ),
		.rst_n			(rstn_pixel    ),
		.frame_start	(canny_frame_start),
		.de_i			(gray_de       ),
		.x_i			(gray_x        ),
		.y_i			(gray_y        ),
		.data_i			(gray_w        ),
		.window_o		(med_win       ),
		.window_valid	(med_win_v     ),
		.x_o			(med_win_x     ),
		.y_o			(med_win_y     )
	);

	wire [7:0]  med_w;
	wire        med_de;
	wire [10:0] med_x;
	wire [9:0]  med_y;

	median3x3 #(.AWIDTH(11)) u_canny_median
	(
		.clk		(clk_pixel ),
		.rst_n		(rstn_pixel),
		.win_valid_i(med_win_v ),
		.x_i		(med_win_x ),
		.y_i		(med_win_y ),
		.window_i	(med_win   ),
		.med_o		(med_w     ),
		.med_valid_o(med_de    ),
		.x_o		(med_x     ),
		.y_o		(med_y     )
	);

	//----------------------------------------------------------------
	// 3. 行缓存 #2 + Sobel
	//----------------------------------------------------------------
	wire [71:0] sob_win;
	wire        sob_win_v;
	wire [10:0] sob_win_x;
	wire [9:0]  sob_win_y;

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(8), .AWIDTH(11)) u_canny_lb2
	(
		.clk			(clk_pixel ),
		.rst_n			(rstn_pixel),
		.frame_start	(canny_frame_start),
		.de_i			(med_de    ),
		.x_i			(med_x     ),
		.y_i			(med_y     ),
		.data_i			(med_w     ),
		.window_o		(sob_win   ),
		.window_valid	(sob_win_v ),
		.x_o			(sob_win_x ),
		.y_o			(sob_win_y )
	);

	wire [11:0] sob_mag;
	wire [1:0]  sob_dir;
	wire        sob_de;
	wire [10:0] sob_x;
	wire [9:0]  sob_y;

	sobel3x3 #(.AWIDTH(11)) u_canny_sobel
	(
		.clk		(clk_pixel ),
		.rst_n		(rstn_pixel),
		.win_valid_i(sob_win_v ),
		.x_i		(sob_win_x ),
		.y_i		(sob_win_y ),
		.window_i	(sob_win   ),
		.mag_o		(sob_mag   ),
		.dir_o		(sob_dir   ),
		.valid_o	(sob_de    ),
		.x_o		(sob_x     ),
		.y_o		(sob_y     )
	);

	//----------------------------------------------------------------
	// 4. 行缓存 #3（DWIDTH=14，{dir,mag} 打包）+ NMS
	//----------------------------------------------------------------
	wire [13:0] sob_px = {sob_dir, sob_mag};
	wire [125:0] nms_win;
	wire         nms_win_v;
	wire [10:0]  nms_win_x;
	wire [9:0]   nms_win_y;

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(14), .AWIDTH(11)) u_canny_lb3
	(
		.clk			(clk_pixel ),
		.rst_n			(rstn_pixel),
		.frame_start	(canny_frame_start),
		.de_i			(sob_de    ),
		.x_i			(sob_x     ),
		.y_i			(sob_y     ),
		.data_i			(sob_px    ),
		.window_o		(nms_win   ),
		.window_valid	(nms_win_v ),
		.x_o			(nms_win_x ),
		.y_o			(nms_win_y )
	);

	wire [11:0] nms_mag;
	wire        nms_de;
	wire [10:0] nms_x;
	wire [9:0]  nms_y;

	nms3x3 #(.AWIDTH(11)) u_canny_nms
	(
		.clk		(clk_pixel ),
		.rst_n		(rstn_pixel),
		.win_valid_i(nms_win_v ),
		.x_i		(nms_win_x ),
		.y_i		(nms_win_y ),
		.window_i	(nms_win   ),
		.nms_mag_o	(nms_mag   ),
		.valid_o	(nms_de    ),
		.x_o		(nms_x     ),
		.y_o		(nms_y     )
	);

	//----------------------------------------------------------------
	// 5. 双阈值（逐像素，无窗口）—— 固定阈值
	//
	//	mag 满量程 0..2040（=|Gx|+|Gy|，满对比边缘约 1020）。
	//	★ 调参只改下面两个 localparam，保持 2:1 比例。
	//	  全黑 / 边缘太少 -> 两个一起往小改（如 120/60、100/50、80/40）
	//	  噪点太多       -> 两个一起往大改（如 200/100、240/120）
	//	注：P2 帧级自适应阈值（原 nms_hist 实例）已按需求移除。
	//	    canny_threshold 的 USE_PORTS=1 走端口取值，将来接串口 / 编码器
	//	    只需把这两个 localparam 换成寄存器，其余不动。
	//----------------------------------------------------------------
	localparam [11:0] CANNY_TH_HIGH = 12'd160;
	localparam [11:0] CANNY_TH_LOW  = 12'd80;

	wire [1:0]  th_cls;
	wire        th_de;
	wire [10:0] th_x;
	wire [9:0]  th_y;

canny_threshold #(
		.TH_HIGH	(12'd160 ),
		.TH_LOW		(12'd80  ),
		.USE_PORTS	(1'b1    ),
		.AWIDTH		(11      )
	) u_canny_threshold
	(
		.clk		(clk_pixel ),
		.rst_n		(rstn_pixel),
		.valid_i	(nms_de    ),
		.x_i		(nms_x     ),
		.y_i		(nms_y     ),
		.mag_i		(nms_mag   ),
		.th_high_i	(CANNY_TH_HIGH),
		.th_low_i	(CANNY_TH_LOW ),
		.cls_o		(th_cls    ),
		.valid_o	(th_de     ),
		.x_o		(th_x      ),
		.y_o		(th_y      )
	);

	//----------------------------------------------------------------
	// 6. 行缓存 #4（DWIDTH=2，cls 打包）+ 迟滞连接
	//----------------------------------------------------------------
	wire [17:0] hys_win;
	wire        hys_win_v;
	wire [10:0] hys_win_x;
	wire [9:0]  hys_win_y;

	line_buffer_3x3 #(.WIDTH(1280), .DWIDTH(2), .AWIDTH(11)) u_canny_lb4
	(
		.clk			(clk_pixel ),
		.rst_n			(rstn_pixel),
		.frame_start	(canny_frame_start),
		.de_i			(th_de     ),
		.x_i			(th_x      ),
		.y_i			(th_y      ),
		.data_i			(th_cls    ),
		.window_o		(hys_win   ),
		.window_valid	(hys_win_v ),
		.x_o			(hys_win_x ),
		.y_o			(hys_win_y )
	);

	wire        canny_edge;
	wire        canny_edge_de;

	//	Canny 对齐 x/y：hysteresis 的 x_o/y_o 与 edge 同拍，
	//	canny_rgb_out 是 edge 的下一拍 → 再打 1 拍供 overlay 判框
	wire [10:0] hys_x;
	wire [9:0]  hys_y;
	wire        clean_edge, clean_de;
	wire [10:0] clean_x;
	wire [9:0]  clean_y;
	reg  [10:0] hys_x_d = 0;
	reg  [9:0]  hys_y_d = 0;
	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) begin hys_x_d <= 11'd0; hys_y_d <= 10'd0; end
		else begin hys_x_d <= clean_x; hys_y_d <= clean_y; end
	end


	hysteresis_local #(.AWIDTH(11)) u_canny_hysteresis
	(
		.clk		(clk_pixel ),
		.rst_n		(rstn_pixel),
		.win_valid_i(hys_win_v  ),
		.x_i		(hys_win_x ),
		.y_i		(hys_win_y ),
		.window_i	(hys_win   ),
		.edge_o		(canny_edge),
		.valid_o	(canny_edge_de),
		.x_o		(hys_x     ),
		.y_o		(hys_y     ));

	//----------------------------------------------------------------
	// 7. 边缘图 -> RGB888（黑底白边）
	//	edge=1 → 白(0xFFFFFF)；edge=0 → 黑(0x000000)。
	//	需要同步对齐 DE / VS / HS：链路共 16 拍延迟，
	//	用移位链把原始 lcd_de / lcd_vs / lcd_hs 延迟同样拍数。
	//
	//	延迟逐级核算（每级均为 1 输出寄存器）：
	//	  canny_valid_d 对齐      1
	//	  rgb565_to_gray          1
	//	  line_buffer #1 内+外    2
	//	  median3x3               1
	//	  line_buffer #2          2
	//	  sobel3x3                1
	//	  line_buffer #3          2
	//	  nms3x3                  1
	//	  canny_threshold         1
	//	  line_buffer #4          2
	//	  hysteresis_local        1
	//	  输出处理级(edge->rgb)   1
	//	  --------------------------- 合计 16
	//	注意：line_buffer_3x3 的窗口输出相对输入是 2 拍（内部 sr 移位 1 拍
	//	      + 输出寄存 1 拍），不是 1 拍，容易少算。
	//----------------------------------------------------------------
	//---- 边缘图去孤立点（方案 D）：清点、留线，2 行内容位移 + 3 拍流水 ----
	edge_despeckle #(.AWIDTH(11), .WIDTH(1280)) u_edge_despeckle (
		.clk         (clk_pixel       ),
		.rst_n       (rstn_pixel      ),
		.thresh_i    (4'd2            ),   // 预留：后续由编码器/param_ctrl 驱动
		.frame_start (canny_frame_start),
		.de_i        (canny_edge_de   ),
		.x_i         (hys_x           ),
		.y_i         (hys_y           ),
		.edge_i      (canny_edge      ),
		.edge_o      (clean_edge      ),
		.de_o        (clean_de        ),
		.x_o         (clean_x         ),
		.y_o         (clean_y         )
	);

	localparam CANNY_LATENCY = 19;	// 16 + 去噪级 3 拍

	reg [23:0] canny_rgb_out = 24'h000000;
	reg        canny_de_out  = 1'b0;
	reg        canny_vs_out  = 1'b0;
	reg        canny_hs_out  = 1'b0;

	//	同步信号延迟链（与数据链路同深度）
	reg [CANNY_LATENCY-1:0] de_sr;
	reg [CANNY_LATENCY-1:0] vs_sr;
	reg [CANNY_LATENCY-1:0] hs_sr;

	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) begin
			de_sr <= {CANNY_LATENCY{1'b0}};
			vs_sr <= {CANNY_LATENCY{1'b0}};
			hs_sr <= {CANNY_LATENCY{1'b0}};
		end else begin
			de_sr <= {de_sr[CANNY_LATENCY-2:0], lcd_de};
			vs_sr <= {vs_sr[CANNY_LATENCY-2:0], lcd_vs};
			hs_sr <= {hs_sr[CANNY_LATENCY-2:0], lcd_hs};
		end
	end

	always @(posedge clk_pixel or negedge rstn_pixel) begin
		if (!rstn_pixel) begin
			canny_rgb_out <= 24'h000000;
			canny_de_out  <= 1'b0;
			canny_vs_out  <= 1'b0;
			canny_hs_out  <= 1'b0;
		end else begin
			canny_rgb_out <= clean_edge ? 24'hFFFFFF : 24'h000000;
			canny_de_out  <= de_sr[CANNY_LATENCY-1];
			canny_vs_out  <= vs_sr[CANNY_LATENCY-1];
			canny_hs_out  <= hs_sr[CANNY_LATENCY-1];
		end
	end

	////////////////////////////////////////////////////////////////
	//	人脸轮廓检测链路（肤色 → 形态学 → CCL → bbox → 叠加）
	//	----------------------------------------------------------------
	//	数据流：
	//	  lcd_data(RGB565) → rgb565_to_rgb888 → face_reader_720p (U=R-G 肤色)
	//	  → low_pass_realtime (7x7 圆盘低通，去斑点)
	//	  → morph_erode3x3_stream (3x3 腐蚀 / 竖直开运算，break_en 自适应)
	//	  → streaming_connected_components (贴边冲刷 + 双缓冲表)
	//	  → bbox_filter_720p (尺寸/紧凑度/轴比/填充率/位置过滤)
	//	  → bbox_overlay (画红框，帧稳定双缓冲)
	//	  → 显示输出
	//
	//	与 Canny 链的关系：完全并行，互不喂数据。
	//	  Canny 链在 lcd_data / lcd_request 上分叉，走灰度+Sobel 路线；
	//	  人脸链在同一组信号上分叉，走颜色路线。两条链各自维护
	//	  自己的行缓存与延迟，互不干扰，因此后续调人脸参数
	//	  不会影响已经验证过的边缘检测结果。
	//
	//	输入源：同 Canny 链，用 lcd_data + lcd_request + lcd_xpos/lcd_ypos，
	//	  理由见 Canny 段注释（lcd_red/green/blue 是打包过的交错格式）。
	//
	//	坐标位宽注意：
	//	  lcd_xpos/lcd_ypos 是 12bit，1280x720 下有效范围 0..1279 / 0..719。
	//	  face_reader_720p 声明 11bit 的 pixel_x 与 pixel_y，
	//	  直接截位在消隐期会回绕（1024→0），故加条件钳位；
	//	  有效范围内原样透传，不影响正常像素。
	//
	//	延迟链（各级均为 1 输出寄存器）：
	//	  rgb565_to_rgb888 (组合)                                0
	//	  face_reader_720p                                       1
	//	  low_pass_realtime (line_delay_bit 同步读 1 + gating 1)  2
	//	  morph_erode3x3_stream                                  1
	//	  bbox_overlay (边框判定后的输出寄存)                     1
	//	  -------------------------------------------------- 合计 5
	//	  对 2px 宽的红框来说 5 拍 ≈ 5 像素的右移，肉眼不可辨，
	//	  故此处不做同步信号延迟链补偿（与 Canny 链的 16 拍不同）。
	////////////////////////////////////////////////////////////////

	//	坐标钳位：12bit → 11bit / 10bit，超范围记为 0
	wire [10:0] face_x = (lcd_xpos >= 12'd2048) ? 11'd0 : lcd_xpos[10:0];
	wire [9:0]  face_y = (lcd_ypos >= 12'd1024) ? 10'd0 : lcd_ypos[9:0];

	//----------------------------------------------------------------
	// 2. 肤色判读（RGB888 → 1bit 二值）
	//----------------------------------------------------------------
	wire        face_bin;
	wire        face_bin_v;

	face_reader_720p #(.COLOR_DEPTH(8)) u_face_reader
	(
		.image_in_R	(w_expand_rgb888[23:16]),
		.image_in_G	(w_expand_rgb888[15:8] ),
		.image_in_B	(w_expand_rgb888[7:0]  ),
		.pixel_x	(face_x        ),
		.pixel_y	(face_y        ),
		.pixel_valid	(lcd_request   ),
		.clk		(clk_pixel     ),
		.binary_output	(face_bin      ),
		.output_valid	(face_bin_v    )
	);

	//----------------------------------------------------------------
	// 3. 7x7 圆盘低通（二值域，去孤立斑点）
	//----------------------------------------------------------------
	wire        face_lp;
	wire        face_lp_v;

	low_pass_realtime #(.WIDTH(1280), .DEPTH(720), .RADIUS(3), .THRESH(15)) u_face_lowpass
	(
		.clk		(clk_pixel   ),
		.pixel_valid	(face_bin_v  ),
		.binary_input	(face_bin    ),
		.pixel_x	(face_x      ),
		.pixel_y	(face_y      ),
		.filtered_output(face_lp     ),
		.output_valid	(face_lp_v   )
	);

	//----------------------------------------------------------------
	// 4. 形态学腐蚀 / 竖直开运算
	//	break_en_i 由 CCL 的 break_en_o（上一帧是否出现符合阈值的
	//	大块）驱动：常态做 3x3 腐蚀，检测到大块时切竖直开运算
	//	以断开“脸-脖”的竖向粘连。
	//----------------------------------------------------------------
	wire        face_morph;
	wire        face_morph_v;
	wire        face_break_en;

	morph_erode3x3_stream #(.WIDTH(1280), .V_OPEN_LEN(11)) u_face_morph
	(
		.clk		(clk_pixel     ),
		.rst_n		(rstn_pixel    ),
		.vs_in		(lcd_vs        ),
		.de_in		(face_lp_v     ),
		.bin_in		(face_lp       ),
		.break_en_i	(face_break_en ),
		.erode_out	(face_morph    ),
		.erode_valid	(face_morph_v  )
	);

	//----------------------------------------------------------------
	// 5. 连通域标记 + bbox 表（贴边冲刷 + 双缓冲）
	//----------------------------------------------------------------
	wire [5:0]  face_blob_n;
	wire [5:0]  face_ccl_raddr;
	wire [10:0] face_ccl_min_x, face_ccl_max_x;
	wire [9:0]  face_ccl_min_y, face_ccl_max_y;
	wire        face_ccl_rvalid;
	wire [21:0] face_ccl_area;

	streaming_connected_components #(
		.Wb(11), .Hb(10), .Nb(10),
		.MAX_BLOBS(64),
		.MIN_W(40), .MIN_H(40), .MIN_AREA(2500),
		.BREAK_MIN_W(100), .BREAK_MIN_H(140), .BREAK_AR_MIN_X10(12),
		.AREA_W(22),
		.FLUSH_ROWS(2),
		.WIDTH(1280)
	) u_face_ccl
	(
		.clk		(clk_pixel        ),
		.rst_n		(rstn_pixel       ),
		.in_valid	(face_morph_v     ),
		.in_bin		(face_morph       ),
		.in_x		(11'd0            ),	// 接口保留，内部未使用
		.in_y		(10'd0            ),	// 接口保留，内部未使用
		.frame_start	(canny_frame_start),
		.frame_end	(lcd_vs_fall      ),
		.blob_count	(face_blob_n      ),
		.raddr		(face_ccl_raddr   ),
		.r_min_x	(face_ccl_min_x   ),
		.r_max_x	(face_ccl_max_x   ),
		.r_min_y	(face_ccl_min_y   ),
		.r_max_y	(face_ccl_max_y   ),
		.r_valid	(face_ccl_rvalid  ),
		.r_area_pix	(face_ccl_area    ),
		.break_en_o	(face_break_en    ),
		.led		(                 )
	);

	//----------------------------------------------------------------
	// 6. bbox 过滤（尺寸/紧凑度/轴比/填充率/位置）
	//	CCL 的读端口是"给地址出上一帧 bbox"。过滤级需要把
	//	1..blob_count 全读一遍，故把过滤级的读请求直接回连到
	//	CCL 的 raddr，形成串联随机读链。
	//----------------------------------------------------------------
	wire [10:0] face_flt_min_x, face_flt_max_x;
	wire [9:0]  face_flt_min_y, face_flt_max_y;
	wire [5:0]  face_flt_n;
	wire        face_flt_valid;
	wire [5:0]  face_rd_addr;	//	叠加级的读地址，回连到过滤级的 addr_in

	bbox_filter_720p #(
		.WIDTH(1280), .HEIGHT(720),
		.MAX_IN_BLOBS(64), .MAX_OUT_BLOBS(1),
	.MIN_W(60), .MAX_W(640), .MIN_H(60), .MAX_H(560),
	.MIN_COMPACTNESS(4), .MIN_AREA_PIX(6000),
		.MIN_RATIO_X10(8), .MAX_RATIO_X10(17),
		.EXTENT_MIN_X100(40), .EXTENT_MAX_X100(90),
		.AREA_W(22),
		.LARGE_W_THR(200), .LARGE_H_THR(200), .LARGE_AREA_BBOX_THR(25000),
		.MIN_COMPACTNESS_LARGE(1), .MIN_RATIO_X10_LARGE(8), .MAX_RATIO_X10_LARGE(18),
		.EXTENT_MIN_X100_LARGE(45),
		.EDGE_KEEP_EN(1), .EDGE_MIN_AREA_PIX(1800),
		.LOWER_REGION_THRESHOLD(600),
		.MAX_WIDTH_HEIGHT_RATIO_X10(13),
		.BYPASS(0)
	) u_face_bbox_filter
	(
		.clk		(clk_pixel        ),
		.rst_n		(rstn_pixel       ),
		.vs_in		(lcd_vs           ),
		.in_blob_count	(face_blob_n      ),
		.in_addr_out	(face_ccl_raddr   ),
		.in_bbox_min_x	(face_ccl_min_x   ),
		.in_bbox_max_x	(face_ccl_max_x   ),
		.in_bbox_min_y	(face_ccl_min_y   ),
		.in_bbox_max_y	(face_ccl_max_y   ),
		.in_area_pix	(face_ccl_area    ),
		.in_bbox_valid	(face_ccl_rvalid  ),
		.blob_count	(face_flt_n       ),
		.addr_in	(face_rd_addr     ),
		.bbox_min_x	(face_flt_min_x   ),
		.bbox_max_x	(face_flt_max_x   ),
		.bbox_min_y	(face_flt_min_y   ),
		.bbox_max_y	(face_flt_max_y   ),
		.bbox_valid	(face_flt_valid   ),
		.fetching_active(                 )
	);

	//----------------------------------------------------------------
	// 7. 红框叠加（帧稳定双缓冲，读取上一帧过滤结果）
	//----------------------------------------------------------------
	wire [23:0] face_overlay_rgb;
	wire        face_overlay_de;
	wire        face_overlay_vs;
	wire        face_overlay_hs;

	bbox_overlay #(.WIDTH(1280), .HEIGHT(720), .MAX_BLOBS(16), .THICKNESS(2)) u_face_overlay
	(
		.clk		(clk_pixel        ),
		.rst_n		(rstn_pixel       ),
		.rgb_in		(canny_rgb_out    ),
		.de_in		(canny_de_out     ),
		.vs_in		(canny_vs_out     ),
		.hs_in		(canny_hs_out     ),
		.x_in		(hys_x_d          ),
		.y_in		(hys_y_d          ),
		.blob_count	(face_flt_n       ),
		.addr_out	(face_rd_addr     ),
		.bbox_min_x	(face_flt_min_x   ),
		.bbox_max_x	(face_flt_max_x   ),
		.bbox_min_y	(face_flt_min_y   ),
		.bbox_max_y	(face_flt_max_y   ),
		.bbox_valid	(face_flt_valid   ),
		.rgb_out	(face_overlay_rgb ),
		.de_out		(face_overlay_de  ),
		.vs_out		(face_overlay_vs  ),
		.hs_out		(face_overlay_hs  ),
		.pending_swap	(                 )
	);

	////////////////////////////////////////////////////////////////
	//	HDMI Interface. 
	
	//	HDMI requires specific timing, thus is not compatible with LCD & LVDS & DSI. Must implement standalone. 
	
	assign hdmi_txd0_rst_o = rst_pixel; 
	assign hdmi_txd1_rst_o = rst_pixel; 
	assign hdmi_txd2_rst_o = rst_pixel; 
	assign hdmi_txc_rst_o = rst_pixel; 
	
	assign hdmi_txd0_oe = 1'b1; 
	assign hdmi_txd1_oe = 1'b1; 
	assign hdmi_txd2_oe = 1'b1; 
	assign hdmi_txc_oe = 1'b1; 
	
	//-------------------------------------
	//Digilent HDMI-TX IP Modified by CB elec.
	rgb2dvi #(.ENABLE_OSERDES(0)) u_rgb2dvi 
	(
		//.TMDS_Clk_p		(hdmio_txc_p_o), 	//	w_hdmio_txc), 
		//.TMDS_Clk_n		(hdmio_txc_n_o), 
		//.TMDS_Data_p	(hdmio_txd_p_o), 	//	w_hdmio_txd), 
		//.TMDS_Data_n 	(hdmio_txd_n_o), 
		
		.oe_i 		(1), 			//	Always enable output
		.bitflip_i 		(4'b0000), 		//	Reverse clock & data lanes. 
		
		.aRst			(1'b0), 
		.aRst_n		(1'b1), 
		
		.PixelClk		(clk_pixel        ),//pixel clk = 74.25M
		.SerialClk		(     ),//pixel clk *5 = 371.25M
		
		.vid_pVSync		(face_overlay_vs), 
		.vid_pHSync		(face_overlay_hs), 
		.vid_pVDE		(face_overlay_de), 
		.vid_pData		(face_overlay_rgb), 
		
		.txc_o			(hdmi_txc_o), 
		.txd0_o			(hdmi_txd0_o), 
		.txd1_o			(hdmi_txd1_o), 
		.txd2_o			(hdmi_txd2_o)
	); 
		
	






	
	
endmodule

