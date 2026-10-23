`timescale 1ns/1ps
// Write-only SPI mode 0, MSB first. One CS pulse per byte.
// valid/data/dc are sampled only when ready is high. HALF_PERIOD >= 1.
module spi_write_byte #(
    parameter integer HALF_PERIOD = 12
)(
    input wire clk, input wire rst,
    input wire valid, output wire ready,
    input wire [7:0] data, input wire data_dc,
    output reg done,
    output reg sclk, output reg mosi,
    output reg cs_n, output reg dc
);
    localparam IDLE=0, SETUP=1, SHIFT=2, HOLD=3, GAP=4;
    reg [2:0] state;
    reg [7:0] shift_data;
    reg [2:0] bit_index;
    integer divider;
    assign ready = (state == IDLE) && !rst;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; divider <= 0; bit_index <= 0;
            shift_data <= 0; done <= 0;
            sclk <= 0; mosi <= 0; cs_n <= 1; dc <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (valid) begin
                    shift_data <= data;
                    mosi <= data[7]; dc <= data_dc;
                    sclk <= 0; bit_index <= 7;
                    divider <= HALF_PERIOD-1;
                    state <= SETUP;
                end
                // DC/MOSI settle for half a period before selecting the panel.
                SETUP: if (divider != 0) divider <= divider-1;
                else begin
                    cs_n <= 0;
                    divider <= HALF_PERIOD-1;
                    state <= SHIFT;
                end
                SHIFT: if (divider != 0) divider <= divider-1;
                else begin
                    divider <= HALF_PERIOD-1;
                    if (!sclk) sclk <= 1;
                    else begin
                        sclk <= 0;
                        if (bit_index == 0) state <= HOLD;
                        else begin
                            bit_index <= bit_index-3'd1;
                            shift_data <= {shift_data[6:0],1'b0};
                            mosi <= shift_data[6];
                        end
                    end
                end
                HOLD: if (divider != 0) divider <= divider-1;
                else begin
                    cs_n <= 1;
                    divider <= HALF_PERIOD-1;
                    state <= GAP;
                end
                GAP: if (divider != 0) divider <= divider-1;
                else begin done <= 1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
