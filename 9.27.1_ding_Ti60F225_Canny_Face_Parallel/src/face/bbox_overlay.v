// Overlay red bounding boxes on RGB888 stream.
// Verilog-2001, frame-stable double-buffer caching:
// - While drawing with draw-bank from previous frame, fetch current list into fill-bank.
// - When fill-bank is complete, mark pending_swap; actually swap banks only on next VS.
// - Whole frame uses one fixed snapshot -> no in-frame scanning.
// - addr_out issues 1..min(blob_count,MAX_BLOBS); bbox_* latched next cycle when bbox_valid=1.

module bbox_overlay #(
    parameter integer WIDTH      = 1280,
    parameter integer HEIGHT     = 720,
    parameter integer MAX_BLOBS  = 16,
    parameter integer THICKNESS  = 2
)(
    input              clk,
    input              rst_n,

    // video in
    input      [23:0]  rgb_in,
    input              de_in,
    input              vs_in,
    input              hs_in,
    input      [10:0]  x_in,
    input      [9:0]   y_in,

    // bbox list iface (previous frame, compact)
    input      [5:0]   blob_count,
    output reg [5:0]   addr_out,     // 1..blob_count
    input      [10:0]  bbox_min_x,
    input      [10:0]  bbox_max_x,
    input      [9:0]   bbox_min_y,
    input      [9:0]   bbox_max_y,
    input              bbox_valid,

    // video out
    output reg [23:0]  rgb_out,
    output reg         de_out,
    output reg         vs_out,
    output reg         hs_out,
    output reg         pending_swap  // set when fill done; swap on next VS
);

    // VS rising
    reg vs_q;
    wire vs_rise = vs_in & ~vs_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vs_q <= 1'b0;
        else         vs_q <= vs_in;
    end

    // Two banks: A for draw, B for fill (and toggle)
    reg [10:0] a_x0 [0:MAX_BLOBS-1];
    reg [10:0] a_x1 [0:MAX_BLOBS-1];
    reg [9:0]  a_y0 [0:MAX_BLOBS-1];
    reg [9:0]  a_y1 [0:MAX_BLOBS-1];
    reg [5:0]  a_n;

    reg [10:0] b_x0 [0:MAX_BLOBS-1];
    reg [10:0] b_x1 [0:MAX_BLOBS-1];
    reg [9:0]  b_y0 [0:MAX_BLOBS-1];
    reg [9:0]  b_y1 [0:MAX_BLOBS-1];
    reg [5:0]  b_n;

    reg draw_sel;      // 0 => draw A, 1 => draw B
    reg fill_sel;      // 0 => fill A, 1 => fill B

    // fetch control (strict 1-cycle pipeline: request idx, latch last_req next cycle)
    reg        fetching;
    reg [5:0]  to_read_n;
    reg [5:0]  rd_idx;       // next index to request (1..to_read_n)
    reg [5:0]  last_req;     // index requested last cycle (to latch now)
    reg [5:0]  latched_cnt;  // number of entries latched

    integer i;
    reg next_draw_sel;
    reg next_fill_sel;
    reg clear_sel;
    // control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_out <= 6'd1;
            draw_sel <= 1'b0; 
            fill_sel <= 1'b1; 
            pending_swap <= 1'b0;
            a_n <= 6'd0; b_n <= 6'd0;
            to_read_n <= 6'd0; rd_idx <= 6'd0; last_req <= 6'd0; latched_cnt <= 6'd0;
            fetching <= 1'b0;
            for (i=0;i<MAX_BLOBS;i=i+1) begin
                a_x0[i]<=0; a_x1[i]<=0; a_y0[i]<=0; a_y1[i]<=0;
                b_x0[i]<=0; b_x1[i]<=0; b_y0[i]<=0; b_y1[i]<=0;
            end
        end else begin
            addr_out <= 6'd1; // default: no request

            // swap draw bank only at VS when a full fill is pending
            if (vs_rise) begin
                // 预先计算下一帧要填充的 bank（避免用旧 fill_sel 清错 bank）
                // 如果这次要交换，则下一帧填充的是 ~fill_sel；否则仍是 fill_sel
                // 用 clear_sel 来决定清零哪一侧的计数

                next_draw_sel = draw_sel;
                next_fill_sel = fill_sel;
                clear_sel     = fill_sel;
                // 新增：如果本帧无框，立即把两侧计数清零，消除残留
                if (blob_count == 0) begin
                    a_n <= 6'd0;
                    b_n <= 6'd0;
                    pending_swap <= 1'b0;  // 无需等待交换
                end else if (pending_swap) begin
                    next_draw_sel = fill_sel;
                    next_fill_sel = ~fill_sel;
                    clear_sel     = next_fill_sel;
                end

                // 提交寄存器
                draw_sel     <= next_draw_sel;
                fill_sel     <= next_fill_sel;
                if (blob_count != 0) pending_swap <= 1'b0;          // 消耗 pending

                // 计算当前帧需要读取的数量
                to_read_n   <= (blob_count > MAX_BLOBS[5:0]) ? MAX_BLOBS[5:0] : blob_count;
                rd_idx      <= 6'd1;
                last_req    <= 6'd0;
                latched_cnt <= 6'd0;
                fetching    <= (blob_count != 0);

                // 只清零“下一帧要填充”的 bank 的计数，避免把刚切换去显示的 bank 清掉
                if (blob_count != 0) begin
                    if (clear_sel==1'b0) a_n <= 6'd0; else b_n <= 6'd0;
                end
            end

            // fetch runs across the frame until done
            if (fetching) begin
                // latch data for last_req (1-cycle after request)
                if (bbox_valid && (last_req>=6'd1) && (last_req<=to_read_n)) begin
                    if (fill_sel==1'b0) begin
                        a_x0[last_req-1] <= bbox_min_x;
                        a_x1[last_req-1] <= bbox_max_x;
                        a_y0[last_req-1] <= bbox_min_y;
                        a_y1[last_req-1] <= bbox_max_y;
                    end else begin
                        b_x0[last_req-1] <= bbox_min_x;
                        b_x1[last_req-1] <= bbox_max_x;
                        b_y0[last_req-1] <= bbox_min_y;
                        b_y1[last_req-1] <= bbox_max_y;
                    end
                    latched_cnt <= latched_cnt + 6'd1;
                end

                // issue next request (request=rd_idx, latch last_req next cycle)
                if (rd_idx <= to_read_n) begin
                    last_req <= rd_idx;
                    addr_out <= rd_idx;
                    rd_idx   <= rd_idx + 6'd1;
                end

                // done
                if (latched_cnt == to_read_n) begin
                    fetching     <= 1'b0;
                    pending_swap <= 1'b1;               // swap on next VS
                    if (fill_sel==1'b0) a_n <= to_read_n; else b_n <= to_read_n;
                end
            end
        end
    end

    // draw borders from current draw bank
    wire [5:0] dn = (draw_sel==1'b0) ? a_n : b_n;
    reg  [10:0] dx0, dx1; reg [9:0] dy0, dy1;

    reg border_hit;
    integer k;
    always @* begin
        border_hit = 1'b0;
        for (k=0;k<MAX_BLOBS;k=k+1) begin
            if (k < dn) begin
                if (draw_sel==1'b0) begin
                    dx0=a_x0[k]; dx1=a_x1[k]; dy0=a_y0[k]; dy1=a_y1[k];
                end else begin
                    dx0=b_x0[k]; dx1=b_x1[k]; dy0=b_y0[k]; dy1=b_y1[k];
                end
                if ((y_in >= dy0) && (y_in <= dy0 + (THICKNESS-1)) &&
                    (x_in >= dx0) && (x_in <= dx1)) border_hit = 1'b1;
                else if ((y_in + (THICKNESS-1) >= dy1) && (y_in <= dy1) &&
                         (x_in >= dx0) && (x_in <= dx1)) border_hit = 1'b1;
                else if ((x_in >= dx0) && (x_in <= dx0 + (THICKNESS-1)) &&
                         (y_in >= dy0) && (y_in <= dy1)) border_hit = 1'b1;
                else if ((x_in + (THICKNESS-1) >= dx1) && (x_in <= dx1) &&
                         (y_in >= dy0) && (y_in <= dy1)) border_hit = 1'b1;
            end
        end
    end

    // pipeline out
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_out <= 24'h0; de_out <= 1'b0; vs_out <= 1'b0; hs_out <= 1'b0;
        end else begin
            de_out <= de_in; vs_out <= vs_in; hs_out <= hs_in;
            if (de_in && border_hit) rgb_out <= {8'hFF, 8'h00, 8'h00};
            else                     rgb_out <= rgb_in;
        end
    end

endmodule