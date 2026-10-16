`timescale 1ns/1ps
module tb_cache_stress;
 reg clk=0,reset=1;always #5 clk=~clk;
 wire[15:0]addr;wire sel,en,wr;wire[31:0]wd;
 EfxSapphireSoc dut(.io_systemClk(clk),.io_asyncReset(reset),
 .jtagCtrl_tck(1'b0),.jtagCtrl_tdi(1'b0),.jtagCtrl_enable(1'b0),.jtagCtrl_capture(1'b0),.jtagCtrl_shift(1'b0),.jtagCtrl_update(1'b0),.jtagCtrl_reset(1'b0),
 .system_uart_0_io_rxd(1'b1),.io_apbSlave_0_PADDR(addr),.io_apbSlave_0_PSEL(sel),.io_apbSlave_0_PENABLE(en),.io_apbSlave_0_PWRITE(wr),.io_apbSlave_0_PWDATA(wd),
 .io_apbSlave_0_PRDATA(32'd0),.io_apbSlave_0_PREADY(1'b1),.io_apbSlave_0_PSLVERROR(1'b0),
 .system_spi_0_io_data_0_read(1'b1),.system_spi_0_io_data_1_read(1'b1),.system_spi_0_io_data_2_read(1'b1),.system_spi_0_io_data_3_read(1'b1));
 integer cycles=0;
 initial begin repeat(10)@(negedge clk);reset=0;end
 always @(posedge clk)begin cycles<=cycles+1;if(cycles>2000000)$fatal(1,"Cache stress timeout");
 if(sel&&en&&wr&&addr==16'h0008)begin
 if(wd!==32'h600dcafe)$fatal(1,"Cache alias/byte/halfword/instruction/fence failure %h",wd);
 $display("PASS: real CPU cache stress: 1KiB index aliases, full address tags, byte/halfword masks, instruction conflict misses, fence; cycles=%0d",cycles);$finish;end end
endmodule
