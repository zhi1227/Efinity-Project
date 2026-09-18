// Debug display mux with button toggle (active-low key_n)
// Mode: 0=overlay_rgb, 1=test_fr_data, 2=test_display_data, 3=test_met_data
module display_debug_mux #(
    parameter integer CLK_HZ       = 74_250_000, // pixel clock
    parameter integer DEBOUNCE_MS  = 10          // debounce window
)(
    input  wire        clk,
    input  wire        rst_n,

    // active-low mechanical button
    input  wire        key_n,

    // timing reference (use overlay timing)
    input  wire        vs_in,
    input  wire        hs_in,
    input  wire        de_in,

    // sources
    input  wire [23:0] rgb0_overlay,     // overlay_rgb
    input  wire [23:0] rgb1_fr,          // test_fr_data
    input  wire [23:0] rgb2_filtered,    // test_display_data
    input  wire [23:0] rgb3_morph,       // test_met_data

    // outputs (timing is pass-through)
    output wire        vs_out,
    output wire        hs_out,
    output wire        de_out,
    output wire [23:0] rgb_out,

    // current mode (for LEDs/debug)
    output reg  [1:0]  mode
);
    // -----------------------
    // Synchronize and debounce key_n (active-low)
    // -----------------------
    // 2-FF sync
    reg [1:0] key_sync_n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_sync_n <= 2'b11;
        else        key_sync_n <= {key_sync_n[0], key_n};
    end
    wire key_sample = ~key_sync_n[1]; // active-high pressed

    localparam integer DB_TICKS = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer DBW      = (DB_TICKS <= 1) ? 1 : $clog2(DB_TICKS);
    reg [DBW-1:0] cnt;
    reg stable_state;     // debounced state (active-high)
    reg last_sample;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt          <= {DBW{1'b0}};
            stable_state <= 1'b0;
            last_sample  <= 1'b0;
        end else begin
            if (key_sample != last_sample) begin
                // edge on raw sample -> restart debounce
                last_sample <= key_sample;
                cnt         <= {DBW{1'b0}};
            end else begin
                // same sample -> integrate
                if (cnt != DB_TICKS[DBW-1:0])
                    cnt <= cnt + {{DBW-1{1'b0}}, 1'b1};
                else
                    stable_state <= key_sample;
            end
        end
    end

    // rising-edge one-shot on pressed (active-high)
    reg stable_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) stable_q <= 1'b0;
        else        stable_q <= stable_state;
    end
    wire pressed_pulse = stable_state & ~stable_q;

    // -----------------------
    // Mode counter 0..3
    // -----------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mode <= 2'd0;
        else if (pressed_pulse) mode <= mode + 2'd1;
    end

    // -----------------------
    // Align sources to overlay timing
    // overlay path: no extra latency
    // other debug paths: +1T to match overlay's de_out/vs_out (which are 1T later than inputs inside bbox_overlay)
    // -----------------------
    reg [23:0] rgb1_fr_d, rgb2_filtered_d, rgb3_morph_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb1_fr_d       <= 24'h0;
            rgb2_filtered_d <= 24'h0;
            rgb3_morph_d    <= 24'h0;
        end else begin
            rgb1_fr_d       <= rgb1_fr;
            rgb2_filtered_d <= rgb2_filtered;
            rgb3_morph_d    <= rgb3_morph;
        end
    end

    // Timing pass-through
    assign vs_out = vs_in;
    assign hs_out = hs_in;
    assign de_out = de_in;

    // RGB select (combinational)
    assign rgb_out = (mode==2'd0) ? rgb0_overlay :
                     (mode==2'd1) ? rgb1_fr_d    :
                     (mode==2'd2) ? rgb2_filtered_d :
                                     rgb3_morph_d;

endmodule