// Active-pixel shift RAM with taps at exact line intervals.
module sobel_line_delay #(
    parameter DISTANCE = 1280,
    parameter DWIDTH = 8,
    parameter TAPS_NUM = 2
)(
    input                         clken,
    input                         clock,
    input      [DWIDTH-1:0]       shiftin,
    output     [DWIDTH-1:0]       shiftout,
    output     [TAPS_NUM*DWIDTH-1:0] taps
);
    reg [DWIDTH-1:0] shift_ram [0:TAPS_NUM*DISTANCE-1];
    integer i;

    always @(posedge clock) begin
        if (clken) begin
            shift_ram[0] <= shiftin;
            for (i = 1; i < TAPS_NUM*DISTANCE; i = i + 1)
                shift_ram[i] <= shift_ram[i-1];
        end
    end

    genvar t;
    generate
        for (t = 0; t < TAPS_NUM; t = t + 1) begin : gen_tap
            assign taps[(t+1)*DWIDTH-1 -: DWIDTH] = shift_ram[(t+1)*DISTANCE-1];
        end
    endgenerate

    assign shiftout = taps[TAPS_NUM*DWIDTH-1 -: DWIDTH];
endmodule
