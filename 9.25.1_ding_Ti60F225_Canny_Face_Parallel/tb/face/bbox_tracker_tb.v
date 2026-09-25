`timescale 1ns/1ps
//======================================================================
//  bbox_tracker_tb.v —— Task 4 验收：S1~S6 六段时序场景
//    S1 静止 10 帧        → 收敛且抖动 0
//    S2 每帧右移 2px x40  → 平滑跟随（单调、不丢）
//    S3 单帧跳变 -300px   → 被连续性门限拒绝，输出保持
//    S4 丢失 10 帧        → 保持最后位置，out_valid 仍为 1
//    S5 继续丢到 20 帧    → 第 16 帧起 out_valid=0
//    S6 重新出现          → 立即捕获，1 帧内 out_valid=1 且位置=目标
//======================================================================
module bbox_tracker_tb;

  localparam SMOOTH_SHIFT = 3, HOLD = 15, SCAN_WAIT = 3;

  reg clk=0; always #5 clk=~clk;
  reg rst_n=0;

  // DUT 端口
  reg  vs_rise;
  reg  [5:0] tbl_count;                  // 本帧候选数（TB 模型）
  reg  [10:0] t_min_x, t_max_x;  reg [9:0] t_min_y, t_max_y;  reg t_valid;
  wire [5:0] in_addr;
  wire [10:0] in_min_x, in_max_x;  wire [9:0] in_min_y, in_max_y;  wire in_valid;
  wire [10:0] out_min_x, out_max_x;  wire [9:0] out_min_y, out_max_y;
  wire out_valid;  wire [2:0] dbg_state;

  // ---- 表源模型：与 SCAN_WAIT=3 匹配的读延迟 ----
  reg [5:0] ra1, ra2, ra3;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin ra1<=0; ra2<=0; ra3<=0; end
    else begin ra1<=in_addr; ra2<=ra1; ra3<=ra2; end
  end
  assign in_valid = (ra3 != 6'd0) && (ra3 <= tbl_count) && t_valid;
  assign in_min_x = t_min_x; assign in_max_x = t_max_x;
  assign in_min_y = t_min_y; assign in_max_y = t_max_y;

  bbox_tracker #(
    .AWIDTH(11), .HB(10), .SMOOTH_SHIFT(SMOOTH_SHIFT), .HOLD_FRAMES(HOLD),
    .MIN_W(20), .MIN_H(20), .MIN_AR_X10(6), .MAX_AR_X10(20), .SCAN_WAIT(SCAN_WAIT)
  ) dut (
    .clk(clk), .rst_n(rst_n), .vs_rise(vs_rise),
    .in_blob_count(tbl_count), .in_addr(in_addr),
    .in_min_x(in_min_x), .in_max_x(in_max_x), .in_min_y(in_min_y), .in_max_y(in_max_y),
    .in_valid(in_valid),
    .out_min_x(out_min_x), .out_max_x(out_max_x), .out_min_y(out_min_y), .out_max_y(out_max_y),
    .out_valid(out_valid), .dbg_state(dbg_state)
  );

  integer i, err;
  integer prev_x0, prev_x1, prev_y0, prev_y1, prev_v;
  integer jitter, last_x0, last_x1;

  // 跑一帧：设置候选 → vs 脉冲 → 等待
  task frame(input v, input [10:0] x0, input [10:0] x1, input [9:0] y0, input [9:0] y1);
    begin
      t_valid = v; t_min_x = x0; t_max_x = x1; t_min_y = y0; t_max_y = y1;
      tbl_count = v ? 6'd1 : 6'd0;
      repeat(4) @(negedge clk);
      vs_rise = 1'b1; @(negedge clk); vs_rise = 1'b0;
      repeat(40) @(negedge clk);
    end
  endtask

  initial begin
    vs_rise=0; tbl_count=0; t_min_x=0; t_max_x=0; t_min_y=0; t_max_y=0; t_valid=0;
    err=0;
    repeat(10) @(negedge clk); rst_n=1; repeat(10) @(negedge clk);

    // ---------------- S1 静止 10 帧 ----------------
    for (i=0;i<10;i=i+1) frame(1'b1, 300, 449, 100, 299);
    $display("[S1] out=(%0d,%0d)-(%0d,%0d) valid=%b  (expect 300,449,100,299 valid=1)",
             out_min_x,out_min_y,out_max_x,out_max_y,out_valid);
    if (!out_valid) err=err+1;
    if (out_min_x!==300 || out_max_x!==449 || out_min_y!==100 || out_max_y!==299) begin
      $display("  FAIL S1: 未收敛到目标"); err=err+1; end

    // ---------------- S2 每帧右移 2px，40 帧 ----------------
    last_x0 = out_min_x;
    for (i=0;i<40;i=i+1) begin
      frame(1'b1, 300 + 2*(i+1), 449 + 2*(i+1), 100, 299);
      if (out_min_x < last_x0) begin $display("  FAIL S2: 第 %0d 帧位置回退", i); err=err+1; end
      last_x0 = out_min_x;
    end
    $display("[S2] 40 帧后 out_x=(%0d,%0d) 目标=(%0d,%0d) (每帧目标 +2)",
             out_min_x,out_max_x, 300+2*40, 449+2*40);
    if (!out_valid) begin $display("  FAIL S2: out_valid 丢失"); err=err+1; end
    if (out_min_x < (300+2*40-20)) begin $display("  FAIL S2: 跟随落后过多"); err=err+1; end
    last_x0 = out_min_x; last_x1 = out_max_x;

    // ---------------- S3 单帧跳变（远离 300px） ----------------
    frame(1'b1, 1200, 1349, 500, 699);
    $display("[S3] 跳变后 out_x=(%0d,%0d) (expect 保持 %0d,%0d)", out_min_x,out_max_x,last_x0,last_x1);
    if ((out_min_x - last_x0 > 5) || (last_x0 - out_min_x > 5)) begin
      $display("  FAIL S3: 跳变未被拒绝"); err=err+1; end

    // ---------------- S4 丢失 10 帧 ----------------
    prev_x0 = out_min_x; prev_x1 = out_max_x; prev_y0 = out_min_y; prev_y1 = out_max_y;
    for (i=0;i<10;i=i+1) frame(1'b0, 0,0,0,0);
    $display("[S4] 丢失 10 帧后 valid=%b out_x=(%0d,%0d) (expect valid=1 且位置不变)",
             out_valid, out_min_x, out_max_x);
    if (!out_valid) begin $display("  FAIL S4: 10 帧内不应清除"); err=err+1; end
    if ((out_min_x!==prev_x0) || (out_max_x!==prev_x1)) begin
      $display("  FAIL S4: 位置发生了漂移"); err=err+1; end

    // ---------------- S5 继续丢到 20 帧 ----------------
    for (i=0;i<10;i=i+1) frame(1'b0, 0,0,0,0);
    $display("[S5] 丢失 20 帧后 valid=%b (expect 0)", out_valid);
    if (out_valid) begin $display("  FAIL S5: 超时未清除"); err=err+1; end

    // ---------------- S6 重新出现 ----------------
    frame(1'b1, 600, 759, 200, 399);
    $display("[S6] 重捕获 out=(%0d,%0d)-(%0d,%0d) valid=%b (expect 600,759,200,399 valid=1)",
             out_min_x,out_min_y,out_max_x,out_max_y,out_valid);
    if (!out_valid) begin $display("  FAIL S6: 未重新捕获"); err=err+1; end
    if (out_min_x!==600 || out_max_x!==759 || out_min_y!==200 || out_max_y!==399) begin
      $display("  FAIL S6: 首次捕获不平滑（应直接等于目标）"); err=err+1; end

    if (err==0) $display("PASS: bbox_tracker_tb | S1~S6 全部通过");
    else        $display("FAILED: %0d 项", err);
    $finish;
  end

endmodule
