`timescale 1ns/1ps
//======================================================================
//  bbox_overlay_tb.v —— Task 5 验收：矩形框叠加
//  覆盖：1) 四条边 2px 红框、框内为黑、框外为黑
//        2) de/vs/hs 相位透传
//        3) 边界用例：贴边 bbox、bbox_valid=0（不画）
//  做法：只采样关心的 (x,y) 坐标（模块对光栅完整性无状态依赖），把仿真压到毫秒级。
//======================================================================
module bbox_overlay_tb;
  localparam THICK = 2;

  reg clk=0; always #5 clk=~clk;
  reg rst_n=0;

  reg  [23:0] rgb_in; reg de_in, vs_in, hs_in; reg [10:0] x_in; reg [9:0] y_in;
  wire [23:0] rgb_out; wire de_out, vs_out, hs_out, pending_swap;
  wire [5:0] addr_out;
  reg  [5:0] blob_count; reg [10:0] bbox_min_x, bbox_max_x; reg [9:0] bbox_min_y, bbox_max_y; reg bbox_valid;

  // 表源模型：模块发 addr_out，下一拍数据有效（与源码注释一致）
  reg [5:0] addr_d;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) addr_d <= 6'd0; else addr_d <= addr_out;
  end
  reg [10:0] t_x0, t_x1; reg [9:0] t_y0, t_y1; reg t_en;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin bbox_valid<=0; bbox_min_x<=0; bbox_max_x<=0; bbox_min_y<=0; bbox_max_y<=0; end
    else begin
      bbox_valid <= t_en && (addr_d==6'd1) && (blob_count!=0);
      bbox_min_x <= t_x0; bbox_max_x <= t_x1; bbox_min_y <= t_y0; bbox_max_y <= t_y1;
    end
  end

  bbox_overlay #(.WIDTH(1280), .HEIGHT(720), .MAX_BLOBS(16), .THICKNESS(THICK)) dut (
    .clk(clk), .rst_n(rst_n),
    .rgb_in(rgb_in), .de_in(de_in), .vs_in(vs_in), .hs_in(hs_in), .x_in(x_in), .y_in(y_in),
    .blob_count(blob_count), .addr_out(addr_out),
    .bbox_min_x(bbox_min_x), .bbox_max_x(bbox_max_x), .bbox_min_y(bbox_min_y), .bbox_max_y(bbox_max_y),
    .bbox_valid(bbox_valid),
    .rgb_out(rgb_out), .de_out(de_out), .vs_out(vs_out), .hs_out(hs_out), .pending_swap(pending_swap)
  );

  integer err;
  reg [23:0] got;

  // 采样一个像素：返回 rgb_out
  task pix(input [10:0] xx, input [9:0] yy, output [23:0] o);
    begin
      @(negedge clk); x_in=xx; y_in=yy; rgb_in=24'h000000; de_in=1'b1;
      @(posedge clk); #1;
      @(negedge clk); o = rgb_out;
    end
  endtask

  task new_frame(input v);
    begin
      @(negedge clk); de_in=1'b0; vs_in=v; hs_in=1'b0;
      @(negedge clk); vs_in=1'b0;
      repeat(4) @(negedge clk);
    end
  endtask

  initial begin
    rgb_in=0; de_in=0; vs_in=0; hs_in=0; x_in=0; y_in=0;
    blob_count=0; bbox_min_x=0; bbox_max_x=0; bbox_min_y=0; bbox_max_y=0; bbox_valid=0;
    t_x0=0; t_x1=0; t_y0=0; t_y1=0; t_en=0; err=0;

    repeat(8) @(negedge clk); rst_n=1; repeat(8) @(negedge clk);

    // ---------------- 装载 bbox (300,200)-(500,400) ----------------
    t_x0=300; t_x1=500; t_y0=200; t_y1=400; t_en=1'b1; blob_count=6'd1;
    new_frame(1'b1);                       // 帧1：VS 触发抓表
    repeat(40) @(negedge clk);             // 等 fill 完成 -> pending_swap
    $display("[TB] 装载完成 pending_swap=%b", pending_swap);
    new_frame(1'b1);                       // 帧2：VS 触发 bank 交换
    repeat(8) @(negedge clk);

    // ---------------- 采样 ----------------
    pix(300,200,got); if (got!==24'hFF0000) begin $display("FAIL 左上角(300,200)=%h 应为红",got); err=err+1; end
    pix(301,201,got); if (got!==24'hFF0000) begin $display("FAIL 框内2px边(301,201)=%h 应为红",got); err=err+1; end
    pix(302,202,got); if (got!==24'h000000) begin $display("FAIL 框内部(302,202)=%h 应为黑",got); err=err+1; end
    pix(400,300,got); if (got!==24'h000000) begin $display("FAIL 框中心(400,300)=%h 应为黑",got); err=err+1; end
    pix(500,400,got); if (got!==24'hFF0000) begin $display("FAIL 右下角(500,400)=%h 应为红",got); err=err+1; end
    pix(498,200,got); if (got!==24'hFF0000) begin $display("FAIL 右边(498,200)=%h 应为红",got); err=err+1; end
    pix(299,200,got); if (got!==24'h000000) begin $display("FAIL 框外左(299,200)=%h 应为黑",got); err=err+1; end
    pix(400,300,got); if (de_out!==1'b1) begin $display("FAIL de 未透传"); err=err+1; end

    // ---------------- 边界：bbox_valid=0（t_en=0）----------------
    t_en=1'b0; blob_count=6'd0;
    new_frame(1'b1); repeat(40) @(negedge clk); new_frame(1'b1); repeat(8) @(negedge clk);
    pix(300,200,got); if (got!==24'h000000) begin $display("FAIL valid=0 时仍画框 %h",got); err=err+1; end

    // ---------------- 边界：贴到画面右下角 ----------------
    t_en=1'b1; blob_count=6'd1; t_x0=1200; t_x1=1279; t_y0=600; t_y1=719;
    new_frame(1'b1); repeat(40) @(negedge clk); new_frame(1'b1); repeat(8) @(negedge clk);
    pix(1200,600,got); if (got!==24'hFF0000) begin $display("FAIL 贴边左上(1200,600)=%h",got); err=err+1; end
    pix(1279,719,got); if (got!==24'hFF0000) begin $display("FAIL 贴边右下(1279,719)=%h",got); err=err+1; end
    pix(1276,700,got); if (got!==24'h000000) begin $display("FAIL 贴边框内(1276,700)=%h 应为黑",got); err=err+1; end

    if (err==0) $display("PASS: bbox_overlay_tb | 2px 红框/框内黑/框外黑/valid=0不画/贴边 全部通过");
    else        $display("FAILED: %0d 项", err);
    $finish;
  end
endmodule

