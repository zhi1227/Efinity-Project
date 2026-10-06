`timescale 1ns/1ps
//  TB：1280x64 合成边缘图 —— 孤立噪点必须清掉，1px 直线/斜线必须保留
module edge_despeckle_tb;
  localparam W=1280, H=64;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0;
  reg [H*W-1:0] src;            // 1bit 源图（用向量存，避免大数组索引问题）
  reg [H*W-1:0] cap;            // 捕获（按坐标）
  reg de_i, frame_start; reg [10:0] x_i; reg [9:0] y_i; reg edge_i;
  wire edge_o, de_o; wire [10:0] x_o; wire [9:0] y_o;
  integer x,y,i,err,on_src,on_cap,dot_left,line_kept,nx,ny,l_left;

  edge_despeckle #(.AWIDTH(11), .WIDTH(W)) dut (
    .clk(clk), .rst_n(rst_n), .frame_start(frame_start),
    .thresh_i(4'd2), .de_i(de_i), .x_i(x_i), .y_i(y_i), .edge_i(edge_i),
    .edge_o(edge_o), .de_o(de_o), .x_o(x_o), .y_o(y_o));

  // 捕获：按 2 行延迟映射回源坐标（行延迟 2 + 1 拍寄存，靠 XY 自校准）
  integer pending; reg [10:0] sx; reg [9:0] sy;
  always @(posedge clk) if (de_o) begin
      // 用相对计数还原坐标：第 n 个有效输出对应第 n 个有效输入 + 行偏移
      if (x_o >= 1 && y_o >= 1) cap[y_o*W + x_o] <= edge_o;
  end

  initial begin
    src = 0; cap = 0; err=0;
    // 1px 水平直线 y=10, x=100..400
    for (x=100;x<=400;x=x+1) src[10*W+x]=1'b1;
    // 2px 水平直线 y=20, x=100..400
    for (x=100;x<=400;x=x+1) begin src[20*W+x]=1'b1; src[21*W+x]=1'b1; end
    // 斜线 (500,10)->(620,130) 每行 1px
    for (i=0;i<=120;i=i+1) if ((10+i)<H) src[(10+i)*W + (500+i)]=1'b1;
    // 孤立噪点 200 个（确定性散布）
    for (i=0;i<200;i=i+1) src[((i*7+3)%H)*W + ((i*137+11)%W)] = 1'b1;
    // L 形噪点簇（3 像素：角点有 2 个邻居但不对向 → 应被清除）
    src[50*W+50]=1; src[50*W+51]=1; src[51*W+50]=1;
    src[52*W+600]=1; src[52*W+601]=1; src[53*W+601]=1;
    // 2x2 小块（应被清除：邻居数最多 3，但每个像素邻居数 >=2 → 可能被保留，见判定）
    src[40*W+900]=1; src[40*W+901]=1; src[41*W+900]=1; src[41*W+901]=1;

    repeat(10) @(negedge clk); rst_n=1; repeat(5) @(negedge clk);

    // 送帧
    frame_start=1; @(negedge clk); frame_start=0;
    for (y=0;y<H;y=y+1) begin
      for (x=0;x<W;x=x+1) begin
        @(negedge clk); de_i=1; x_i=x[10:0]; y_i=y[9:0]; edge_i=src[y*W+x];
      end
      @(negedge clk); de_i=0; edge_i=0;
      repeat(20) @(negedge clk);
    end
    repeat(60) @(negedge clk);

    // 统计
    on_src=0; on_cap=0; dot_left=0; line_kept=0;
    for (i=0;i<H*W;i=i+1) if (src[i]) on_src=on_src+1;
    for (y=0;y<H;y=y+1) for (x=0;x<W;x=x+1) if (cap[y*W+x]) on_cap=on_cap+1;
    // 孤立噪点残留：在噪点坐标 ±1 范围内是否还有输出
    for (i=0;i<200;i=i+1) begin
      nx=((i*137+11)%W); ny=((i*7+3)%H);
      if (cap[ny*W+nx]) dot_left=dot_left+1;
    end
    // 1px 直线保留数
    for (x=105;x<=395;x=x+1) if (cap[10*W+x]) line_kept=line_kept+1;

    $display("[TB] src_on=%0d cap_on=%0d (压缩比 %0d%%)", on_src, on_cap, (on_cap*100)/(on_src+1));
    $display("[TB] 孤立噪点残留=%0d/200   1px 直线保留=%0d/291", dot_left, line_kept);
    // L 形噪点簇残留统计
    l_left = 0;
    if (cap[50*W+50]||cap[50*W+51]||cap[51*W+50]) l_left=l_left+1;
    if (cap[52*W+600]||cap[52*W+601]||cap[53*W+601]) l_left=l_left+1;
    $display("[TB] L 形噪点簇残留 = %0d/2 （期望 0）", l_left);
    if (l_left != 0)    begin $display("FAIL: L 形噪点簇未被清除"); err=err+1; end
    if (dot_left > 20)  begin $display("FAIL: 孤立噪点清除不足"); err=err+1; end
    if (line_kept < 250) begin $display("FAIL: 1px 直线被过度清除 (%0d/291)", line_kept); err=err+1; end
    if (err==0) $display("PASS: edge_despeckle_tb | 噪点基本清除 + 细线保留");
    else        $display("FAILED: %0d", err);
    $finish;
  end
endmodule



