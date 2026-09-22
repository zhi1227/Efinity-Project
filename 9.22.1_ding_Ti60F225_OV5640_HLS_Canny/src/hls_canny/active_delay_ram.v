// Active-pixel delay backed by inferred block RAM. Blanking cycles do not
// advance the address, so DELAY=WIDTH is exactly one video line.
module active_delay_ram #(
    parameter DATA_WIDTH = 8,
    parameter DELAY = 1280,
    parameter ADDR_WIDTH = $clog2(DELAY)
)(
    input                       clk,
    input                       rst_n,
    input                       en,
    input      [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DELAY-1];
    reg [ADDR_WIDTH-1:0] addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr <= {ADDR_WIDTH{1'b0}};
            dout <= {DATA_WIDTH{1'b0}};
        end else if (en) begin
            dout <= mem[addr];
            mem[addr] <= din;
            if (addr == DELAY - 1)
                addr <= {ADDR_WIDTH{1'b0}};
            else
                addr <= addr + 1'b1;
        end
    end
endmodule
