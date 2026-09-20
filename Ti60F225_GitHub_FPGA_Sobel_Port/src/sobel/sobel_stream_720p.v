// Streaming 1280x720 Sobel edge detector for the verified OV5640 display path.
// Pixels are accepted only when de_in is high. Two active-video line delays
// provide the 3x3 window; timing outputs are delayed by one pixel clock.
module sobel_stream_720p #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter THRESHOLD = 40
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

    // Low-cost luminance approximation: Y = R/4 + G/2 + B/4.
    wire [9:0] gray_sum = {2'b00, rgb_in[23:16] >> 2}
                         + {2'b00, rgb_in[15:8]  >> 1}
                         + {2'b00, rgb_in[7:0]   >> 2};
    wire [7:0] gray_now = gray_sum[7:0];

    wire [15:0] line_taps;
    wire [7:0]  gray_y1 = line_taps[7:0];
    wire [7:0]  gray_y2 = line_taps[15:8];

    sobel_line_delay #(
        .DISTANCE(WIDTH), .DWIDTH(8), .TAPS_NUM(2)
    ) u_line_delay (
        .clken(de_in),
        .clock(clk),
        .shiftin(gray_now),
        .shiftout(),
        .taps(line_taps)
    );

    reg [7:0] top_l, top_c;
    reg [7:0] mid_l,  mid_c;
    reg [7:0] bot_l,  bot_c;

    wire [9:0] gx_pos = {2'b00, gray_y2} + {1'b0, mid_c, 1'b0} + {2'b00, gray_now};
    wire [9:0] gx_neg = {2'b00, top_l}  + {1'b0, mid_l, 1'b0} + {2'b00, bot_l};
    wire [9:0] gy_pos = {2'b00, bot_l}  + {1'b0, bot_c, 1'b0} + {2'b00, gray_now};
    wire [9:0] gy_neg = {2'b00, top_l}  + {1'b0, top_c, 1'b0} + {2'b00, gray_y2};
    wire [9:0] gx_abs = (gx_pos >= gx_neg) ? (gx_pos - gx_neg) : (gx_neg - gx_pos);
    wire [9:0] gy_abs = (gy_pos >= gy_neg) ? (gy_pos - gy_neg) : (gy_neg - gy_pos);
    wire [10:0] magnitude = {1'b0, gx_abs} + {1'b0, gy_abs};
    wire [7:0] edge_pixel = (magnitude >= THRESHOLD) ? 8'hff : 8'h00;

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

                if ((x_in >= 2) && (y_in >= 2) && (x_in < WIDTH) && (y_in < HEIGHT))
                    rgb_out <= {edge_pixel, edge_pixel, edge_pixel};
                else
                    rgb_out <= 24'h000000;
            end else begin
                rgb_out <= 24'h000000;
            end
        end
    end
endmodule
