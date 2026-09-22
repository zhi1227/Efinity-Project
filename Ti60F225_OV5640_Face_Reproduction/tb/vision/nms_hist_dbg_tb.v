`timescale 1ns/1ps
// 调试 TB：全 1000 -> 打印 hist[62]/hist[61]/hist[6]/N/target
module nms_hist_dbg_tb;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0, frame_start=0, frame_end=0;
  reg [3:0] ratio_shift=4'd3;
  reg [11:0] mag=0; reg mag_valid=0;
  reg [7:0] dbg_addr=0; reg dbg_req=0;
  wire [11:0] th_high, th_low; wire th_valid; wire [2:0] dbg;
  wire [15:0] dbg_hist; wire [31:0] n_tot, tgt;
  integer i;
  nms_hist dut(.clk(clk),.rst_n(rst_n),.frame_start(frame_start),.frame_end(frame_end),
    .ratio_shift_i(ratio_shift),.mag_i(mag),.mag_valid_i(mag_valid),
    .th_high_o(th_high),.th_low_o(th_low),.th_valid_o(th_valid),.dbg_state(dbg),
    .dbg_addr_i(dbg_addr),.dbg_req_i(dbg_req),.dbg_hist_o(dbg_hist),
    .dbg_n_total_o(n_tot),.dbg_target_o(tgt));
  task rd(input [7:0] a, output [15:0] v);
    begin @(negedge clk); dbg_addr=a; dbg_req=1; @(negedge clk); dbg_req=0;
          repeat(3) @(negedge clk); v = dbg_hist; end
  endtask
  reg [15:0] h62,h61,h6,h5;
  initial begin
    repeat(10) @(negedge clk); rst_n=1; repeat(5) @(negedge clk);
    // 全 1000：mag=1000 -> bin 62
    @(negedge clk); frame_start=1; @(negedge clk); frame_start=0;
    repeat(300) @(negedge clk);
    for (i=0;i<1000;i=i+1) begin @(negedge clk); mag=12'd1000; mag_valid=1; end
    @(negedge clk); mag_valid=0; repeat(8) @(negedge clk);
    @(negedge clk); frame_end=1; @(negedge clk); frame_end=0;
    repeat(2000) @(negedge clk);
    $display("[DBG] th_high=%0d  n_total=%0d target=%0d", th_high, n_tot, tgt);
    rd(8'd62,h62); rd(8'd61,h61); rd(8'd6,h6); rd(8'd5,h5);
    $display("[DBG] hist[62]=%0d hist[61]=%0d hist[6]=%0d hist[5]=%0d", h62,h61,h6,h5);
    $finish;
  end
endmodule
