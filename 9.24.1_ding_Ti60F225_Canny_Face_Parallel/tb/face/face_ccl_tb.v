`timescale 1ns/1ps
//======================================================================
//  face_ccl_tb.v —— Task 3 验收：streaming_connected_components（含 true_ccl）
//
//  合成帧 1280x64，三个目标：
//    A: 200x40 大方块  @ (300,10)-(499,49)   面积 8000  → 必须报出
//    B: 20x40 细长条  @ (600,10)-(619,49)   宽 20     → 被 MIN_W 过滤
//    C: 60x60 贴边块  @ (1200,4)-(1259,63)  贴下边界 → 必须报出（FLUSH_ROWS 生效）
//
//  判定：blob_count==2；A/C 的 bbox 误差 <=1px；C 的 y_max 必须到 63（贴边不丢）。
//  说明：为控制仿真规模用 1280x64 + 缩小门限（MIN_W/H=30, MIN_AREA=900），
//        门限语义与 720p 时一致（见 RULING）。
//======================================================================
module face_ccl_tb;

  localparam integer W = 1280;
  localparam integer H = 64;
  localparam integer AW = 11, HB = 10, NB = 10;
  localparam integer MINW = 30, MINH = 30, MINA = 900;

  reg clk = 0; always #5 clk = ~clk;
  reg rst_n = 0;

  reg mask [0:W*H-1];
  integer x, y, i, j, k, f;
  integer err;
  integer got_count;
  integer bx0,bx1,by0,by1, ba;
  integer seen_A, seen_B, seen_C;
  integer exp_A, exp_C;

  // DUT 端口
  reg  in_valid, in_bin; reg [AW-1:0] in_x; reg [HB-1:0] in_y;
  reg  frame_start, frame_end;
  reg  [5:0] raddr;
  wire [5:0] blob_count;
  wire [AW-1:0] r_min_x, r_max_x;
  wire [HB-1:0] r_min_y, r_max_y;
  wire r_valid;
  wire [21:0] r_area_pix;
  wire break_en_o, led;

  streaming_connected_components #(
    .Wb(AW), .Hb(HB), .Nb(NB), .MAX_BLOBS(8), .RST_CYCLES(8),
    .MIN_W(MINW), .MIN_H(MINH), .MIN_AREA(MINA),
    .BREAK_MIN_W(100), .BREAK_MIN_H(140), .BREAK_AR_MIN_X10(12),
    .AREA_W(22), .FLUSH_ROWS(2), .WIDTH(W)
  ) dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid), .in_bin(in_bin), .in_x(in_x), .in_y(in_y),
    .frame_start(frame_start), .frame_end(frame_end),
    .blob_count(blob_count), .raddr(raddr),
    .r_min_x(r_min_x), .r_max_x(r_max_x), .r_min_y(r_min_y), .r_max_y(r_max_y),
    .r_valid(r_valid), .r_area_pix(r_area_pix),
    .break_en_o(break_en_o), .led(led)
  );

  initial begin
    for (i=0;i<W*H;i=i+1) mask[i]=0;
    in_valid=0; in_bin=0; in_x=0; in_y=0; frame_start=0; frame_end=0; raddr=0;

    // ---- 图案 ----
    for (y=10;y<=49;y=y+1) for (x=300;x<=499;x=x+1) mask[y*W+x]=1;      // A 200x40
    for (y=10;y<=49;y=y+1) for (x=600;x<=619;x=x+1) mask[y*W+x]=1;      // B 20x40
    for (y=4;y<=63;y=y+1)  for (x=1200;x<=1259;x=x+1) mask[y*W+x]=1;    // C 60x60 贴下边
    $display("[TB] pattern: A(300,10)-(499,49) B(600,10)-(619,49) C(1200,4)-(1259,63)");

    repeat(10) @(negedge clk);
    rst_n = 1;
    repeat(10) @(negedge clk);

    // 双缓冲表：必须送两帧，第二帧末表中才有「上一帧」的结果
    for (f=0; f<2; f=f+1) begin

    // ---- 帧起始脉冲 ----
    @(negedge clk); frame_start = 1'b1;
    @(negedge clk); frame_start = 1'b0;
    repeat(8) @(negedge clk);

    // ---- 逐行送 mask（行间 30 拍消隐，满足 true_ccl 的 DL=3 行间隔要求）----
    for (y=0;y<H;y=y+1) begin
      for (x=0;x<W;x=x+1) begin
        @(negedge clk);
        in_valid = 1'b1; in_bin = mask[y*W+x]; in_x = x[AW-1:0]; in_y = y[HB-1:0];
      end
      @(negedge clk); in_valid = 1'b0; in_bin = 1'b0;
      repeat(30) @(negedge clk);
    end

    // ---- 帧结束脉冲（单拍）----
    @(negedge clk); frame_end = 1'b1;
    @(negedge clk); frame_end = 1'b0;

    // ---- 等冲刷(FLUSH_ROWS=2 行) + 复位 + 表切换 ----
    repeat(2*W + 64) @(negedge clk);
    end // for f

    // ---- 读表 ----
    got_count = blob_count;
    $display("[CCL] blob_count=%0d (expect 2)", got_count);
    seen_A=0; seen_B=0; seen_C=0;
    for (k=1;k<=8;k=k+1) begin
      raddr = k[5:0];
      repeat(8) @(negedge clk);
      bx0=r_min_x; bx1=r_max_x; by0=r_min_y; by1=r_max_y; ba=r_area_pix;
      if (r_valid) begin
        $display("  blob[%0d] x=(%0d,%0d) y=(%0d,%0d) area=%0d", k, bx0,bx1,by0,by1, ba);
        if (bx0>=299 && bx0<=301 && bx1>=498 && bx1<=500 && by0>=9 && by0<=11 && by1>=48 && by1<=50) seen_A=1;
        if (bx0>=1199 && bx0<=1201 && bx1>=1258 && bx1<=1260 && by0<=5 && by1>=62) seen_C=1;
        if (bx0>=599 && bx0<=621 && by0>=9 && by1<=50) seen_B=1;
      end
    end
    raddr = 0; repeat(4) @(negedge clk);

    // ---- 判定 ----
    err = 0;
    if (got_count != 2)  begin $display("FAIL: blob_count=%0d，期望 2", got_count); err=err+1; end
    if (!seen_A)         begin $display("FAIL: 未找到 200x40 大方块 A"); err=err+1; end
    if (!seen_C)         begin $display("FAIL: 未找到贴边方块 C（FLUSH_ROWS 未生效？）"); err=err+1; end
    if (seen_B)          begin $display("FAIL: 20x40 细长条 B 未被 MIN_W 过滤"); err=err+1; end

    if (err==0) $display("PASS: face_ccl_tb | blob_count=2 | A/C bbox 正确 | B 被过滤 | 贴边 C 已 finalize");
    else        $display("FAILED: %0d 项未通过", err);
    $finish;
  end

endmodule

