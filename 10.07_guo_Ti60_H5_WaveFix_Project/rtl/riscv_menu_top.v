`timescale 1ns/1ps
module riscv_menu_top (
    input [12:0] status_i,
    output lcd_reset,
    input tx_slowclk,             // 48 MHz from Interface Designer PLL
    input txpll_locked,
    output [6:0] lvds_tx_clk_TX_DATA,
    output [6:0] lvds_tx0_TX_DATA,
    output [6:0] lvds_tx1_TX_DATA,
    output [6:0] lvds_tx2_TX_DATA,
    output [6:0] lvds_tx3_TX_DATA
);
    wire reset;
    assign lcd_reset=reset;
    wire [15:0] paddr;
    wire psel, penable, pwrite;
    wire [31:0] pwdata, prdata;
    wire [23:0] rgb;
    wire de;

    EfxSapphireSoc soc (
        .io_systemClk(tx_slowclk), .io_asyncReset(~txpll_locked),
        .io_systemReset(reset),
        .jtagCtrl_tck(1'b0), .jtagCtrl_tdi(1'b0), .jtagCtrl_enable(1'b0),
        .jtagCtrl_capture(1'b0), .jtagCtrl_shift(1'b0),
        .jtagCtrl_update(1'b0), .jtagCtrl_reset(1'b0), .jtagCtrl_tdo(),
        .system_uart_0_io_rxd(1'b1), .system_uart_0_io_txd(),
        .io_apbSlave_0_PADDR(paddr), .io_apbSlave_0_PSEL(psel),
        .io_apbSlave_0_PENABLE(penable), .io_apbSlave_0_PWRITE(pwrite),
        .io_apbSlave_0_PWDATA(pwdata), .io_apbSlave_0_PRDATA(prdata),
        .io_apbSlave_0_PREADY(1'b1), .io_apbSlave_0_PSLVERROR(1'b0),
        .system_spi_0_io_sclk_write(), .system_spi_0_io_ss(),
        .system_spi_0_io_data_0_read(1'b1),
        .system_spi_0_io_data_1_read(1'b1),
        .system_spi_0_io_data_2_read(1'b1),
        .system_spi_0_io_data_3_read(1'b1),
        .system_spi_0_io_data_0_write(), .system_spi_0_io_data_0_writeEnable(),
        .system_spi_0_io_data_1_write(), .system_spi_0_io_data_1_writeEnable(),
        .system_spi_0_io_data_2_write(), .system_spi_0_io_data_2_writeEnable(),
        .system_spi_0_io_data_3_write(), .system_spi_0_io_data_3_writeEnable()
    );

    menu_lcd_apb display (
        .status_i(status_i),
        .clk(tx_slowclk), .reset(reset),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .rgb(rgb), .de(de)
    );

    // Same RGB888 / DE-only lane mapping and bit order as the screen demo.
    wire [7:0] r = rgb[23:16], g = rgb[15:8], b = rgb[7:0];
    wire [6:0] d0 = {g[0], r[5:0]};
    wire [6:0] d1 = {b[1:0], g[5:1]};
    wire [6:0] d2 = {de, 2'b00, b[5:2]};
    wire [6:0] d3 = {1'b0, b[7:6], g[7:6], r[7:6]};
    function [6:0] reverse7;
        input [6:0] v;
        begin reverse7 = {v[0],v[1],v[2],v[3],v[4],v[5],v[6]}; end
    endfunction
    assign lvds_tx_clk_TX_DATA = reverse7(7'b1100011);
    assign lvds_tx0_TX_DATA = reverse7(d0);
    assign lvds_tx1_TX_DATA = reverse7(d1);
    assign lvds_tx2_TX_DATA = reverse7(d2);
    assign lvds_tx3_TX_DATA = reverse7(d3);
endmodule
