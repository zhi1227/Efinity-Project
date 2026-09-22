`timescale 1ns/1ps
// TB：单峰 + 双峰，验证"按占比定阈值"
module nms_hist_tb;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0, frame_start=0, frame_end=0;
  reg [3:0] ratio_shift=4'd3;
  reg [11:0] mag=0; reg mag_valid=0;
  wire [11:0] th_high, th_low; wire th_valid; wire [2:0] dbg;
  integer i, err, r1, r2, r3;
  nms_hist dut(.clk(clk),.rst_n(rst_n),.frame_start(frame_start),.frame_end(frame_end),
    .ratio_shift_i(ratio_shift),.mag_i(mag),.mag_valid_i(mag_valid),
    .th_high_o(th_high),.th_low_o(th_low),.th_valid_o(th_valid),.dbg_state(dbg));

  task run(input [3:0] sh, input [11:0] m, input integer cnt, output [11:0] got);
    begin
      ratio_shift = sh;
      @(negedge clk); frame_start=1; @(negedge clk); frame_start=0;
      repeat(300) @(negedge clk);
      for (i=0;i<cnt;i=i+1) begin @(negedge clk); mag=m; mag_valid=1; end
      @(negedge clk); mag_valid=0;
      repeat(8) @(negedge clk);
      @(negedge clk); frame_end=1; @(negedge clk); frame_end=0;
      repeat(2000) @(negedge clk);
      got = th_high;
      $display("[TB] shift=%0d mag=%0d cnt=%0d -> th_high=%0d th_low=%0d valid=%b",
               sh, m, cnt, th_high, th_low, th_valid);
    end
  endtask

  initial begin
    err=0;
    repeat(10) @(negedge clk); rst_n=1; repeat(5) @(negedge clk);
    run(4'd3, 12'd1000, 1000, r1);   // 预热帧（复位后首帧，走 fallback，不判）
    run(4'd3, 12'd1000, 1000, r1);   // 全 1000 -> 应 ~1000
    run(4'd3, 12'd100,  1000, r2);   // 全 100  -> 应 ~104
    // 双峰：25% 在 1000，75% 在 100；保留前 1/8 -> 应落在 1000 附近
    begin
      ratio_shift = 4'd3;
      @(negedge clk); frame_start=1; @(negedge clk); frame_start=0;
      repeat(300) @(negedge clk);
      for (i=0;i<1000;i=i+1) begin
        @(negedge clk); mag = (i<250) ? 12'd1000 : 12'd100; mag_valid=1;
      end
      @(negedge clk); mag_valid=0; repeat(8) @(negedge clk);
      @(negedge clk); frame_end=1; @(negedge clk); frame_end=0;
      repeat(2000) @(negedge clk);
      r3 = th_high;
      $display("[TB] 双峰(25%%@1000,75%%@100) shift=3 -> th_high=%0d", r3);
    end
    if (r1 < 960 || r1 > 1030) begin $display("FAIL: 单峰1000 th=%0d", r1); err=err+1; end
    if (r2 < 80  || r2 > 130)  begin $display("FAIL: 单峰100  th=%0d", r2); err=err+1; end
    if (r3 < 960 || r3 > 1030) begin $display("FAIL: 双峰 th=%0d 应落在高bin", r3); err=err+1; end
    if (err==0) $display("PASS: nms_hist_tb | 单峰/双峰 按占比自适应阈值 均正确");
    else        $display("FAILED: %0d", err);
    $finish;
  end
endmodule
