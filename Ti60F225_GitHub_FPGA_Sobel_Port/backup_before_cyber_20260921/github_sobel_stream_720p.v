// Port of the streaming algorithm from:
//   D:/Github_Project/Efinity-Project/FPGA_Sobel/rtl/sobel/
//
// The original project targets an Altera Cyclone IV and depends on the
// Quartus fifo_sobel IP.  This version keeps its weighted grayscale and
// |Gx|+|Gy| saturated-magnitude display behaviour, while using the verified
// Efinix/Ti60F225 active-pixel line delay and post-DDR 1280x720 RGB stream.
module github_sobel_stream_720p #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720
)(
    input             clk,
    input             rst_n,
    input      [23:0] rgb_in,
    input             de_in,
    input             vs_in,
    input             hs_in,
    input      [10:0] x_in,
    input      [9:0]  y_in,
    output reg [23:0] rgb_out,
    output reg        de_out,
    output reg        vs_out,
    output reg        hs_out
);

    // Intended RGB luminance weighting from the source project:
    // Y = (77*R + 150*G + 29*B) / 256.  Shift/add expressions avoid
    // vendor-specific multiplier IP and keep this source portable.
    wire [15:0] r_weight = {2'b0, rgb_in[23:16], 6'b0}
                         + {5'b0, rgb_in[23:16], 3'b0}
                         + {6'b0, rgb_in[23:16], 2'b0}
                         + {8'b0, rgb_in[23:16]};
    wire [16:0] g_weight = {2'b0, rgb_in[15:8], 7'b0}
                         + {5'b0, rgb_in[15:8], 4'b0}
                         + {7'b0, rgb_in[15:8], 2'b0}
                         + {8'b0, rgb_in[15:8], 1'b0};
    wire [13:0] b_weight = {2'b0, rgb_in[7:0], 4'b0}
                         + {3'b0, rgb_in[7:0], 3'b0}
                         + {4'b0, rgb_in[7:0], 2'b0}
                         + {6'b0, rgb_in[7:0]};
    wire [17:0] gray_weighted = {2'b0, r_weight}
                              + {1'b0, g_weight}
                              + {4'b0, b_weight};
    wire [7:0] gray_now = gray_weighted[15:8];

    wire [15:0] line_taps;
    wire [7:0] gray_y1 = line_taps[7:0];
    wire [7:0] gray_y2 = line_taps[15:8];

    sobel_line_delay #(
        .DISTANCE(WIDTH),
        .DWIDTH(8),
        .TAPS_NUM(2)
    ) u_line_delay (
        .clken(de_in),
        .clock(clk),
        .shiftin(gray_now),
        .shiftout(),
        .taps(line_taps)
    );

    reg [7:0] top_l, top_c;
    reg [7:0] mid_l, mid_c;
    reg [7:0] bot_l, bot_c;

    // Sobel kernels, implemented as unsigned positive/negative sums so the
    // absolute value needs no signed vendor primitive.
    wire [9:0] gx_pos = {2'b00, gray_y2}
                       + {1'b0, mid_c, 1'b0}
                       + {2'b00, gray_now};
    wire [9:0] gx_neg = {2'b00, top_l}
                       + {1'b0, mid_l, 1'b0}
                       + {2'b00, bot_l};
    wire [9:0] gy_pos = {2'b00, bot_l}
                       + {1'b0, bot_c, 1'b0}
                       + {2'b00, gray_now};
    wire [9:0] gy_neg = {2'b00, top_l}
                       + {1'b0, top_c, 1'b0}
                       + {2'b00, gray_y2};
    wire [9:0] gx_abs = (gx_pos >= gx_neg) ? (gx_pos - gx_neg)
                                           : (gx_neg - gx_pos);
    wire [9:0] gy_abs = (gy_pos >= gy_neg) ? (gy_pos - gy_neg)
                                           : (gy_neg - gy_pos);
    wire [10:0] magnitude = {1'b0, gx_abs} + {1'b0, gy_abs};

    // The GitHub source clamps magnitude above 255 instead of generating a
    // binary threshold image.  This retains weak/strong edge intensity.
    wire [7:0] edge_pixel = (magnitude > 11'd255)
                          ? 8'hff : magnitude[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_l <= 8'd0;
            top_c <= 8'd0;
            mid_l <= 8'd0;
            mid_c <= 8'd0;
            bot_l <= 8'd0;
            bot_c <= 8'd0;
            rgb_out <= 24'd0;
            de_out <= 1'b0;
            vs_out <= 1'b0;
            hs_out <= 1'b0;
        end else begin
            de_out <= de_in;
            vs_out <= vs_in;
            hs_out <= hs_in;

            if (de_in) begin
                if (x_in == 0) begin
                    top_l <= 8'd0;
                    top_c <= gray_y2;
                    mid_l <= 8'd0;
                    mid_c <= gray_y1;
                    bot_l <= 8'd0;
                    bot_c <= gray_now;
                end else begin
                    top_l <= top_c;
                    top_c <= gray_y2;
                    mid_l <= mid_c;
                    mid_c <= gray_y1;
                    bot_l <= bot_c;
                    bot_c <= gray_now;
                end

                if ((x_in >= 2) && (y_in >= 2) &&
                    (x_in < WIDTH) && (y_in < HEIGHT))
                    rgb_out <= {edge_pixel, edge_pixel, edge_pixel};
                else
                    rgb_out <= 24'h000000;
            end else begin
                rgb_out <= 24'h000000;
            end
        end
    end
endmodule
