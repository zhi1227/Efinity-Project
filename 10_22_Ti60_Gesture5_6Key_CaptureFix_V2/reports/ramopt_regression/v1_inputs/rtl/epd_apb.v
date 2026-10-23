`timescale 1ns/1ps
// Software-controlled SPI transmitter, no frame RAM; CPU clock domain.
// F8100100: +0 status {overflow,busy,tx_busy}, +4 reset, +8 TX {dc,data},
// +C milliseconds, +10 firmware application status.
module epd_apb #(parameter integer CLK_HZ=48000000, SPI_HALF_PERIOD=24)(
    input wire clk, reset, input wire [7:0] paddr,
    input wire psel, penable, pwrite, input wire [31:0] pwdata,
    output reg [31:0] prdata, input wire epd_busy,
    output wire epd_clk, epd_din, epd_cs_n, epd_dc, output reg epd_rst_n
);
    localparam integer MS_DIV=CLK_HZ/1000;
    reg [31:0] divider, milliseconds;
    reg pending, overflow;
    reg [8:0] tx_word;
    reg [7:0] app_status;
    (* async_reg="true" *) reg busy_meta, busy_sync;
    wire tx_ready, tx_done;
    wire tx_busy=pending || !tx_ready;
    spi_write_byte #(.HALF_PERIOD(SPI_HALF_PERIOD)) spi(
        .clk(clk),.rst(reset),.valid(pending),.ready(tx_ready),
        .data(tx_word[7:0]),.data_dc(tx_word[8]),.done(tx_done),
        .sclk(epd_clk),.mosi(epd_din),.cs_n(epd_cs_n),.dc(epd_dc));
    always @(posedge clk) begin
        if(reset) begin
            divider<=0; milliseconds<=0; pending<=0; overflow<=0;
            tx_word<=0; epd_rst_n<=1; app_status<=0; busy_meta<=1; busy_sync<=1;
        end else begin
            busy_meta<=epd_busy; busy_sync<=busy_meta;
            if(divider==MS_DIV-1) begin divider<=0; milliseconds<=milliseconds+1'b1; end
            else divider<=divider+1'b1;
            if(pending && tx_ready) pending<=0;
            if(psel && penable && pwrite) begin
                case(paddr)
                    8'h00: if(pwdata[2]) overflow<=0;
                    8'h04: epd_rst_n<=pwdata[0];
                    8'h08: if(!tx_busy) begin tx_word<=pwdata[8:0]; pending<=1; end
                           else overflow<=1;
                    8'h10: app_status<=pwdata[7:0];
                    default: begin end
                endcase
            end
        end
    end
    always @* begin
        case(paddr)
            8'h00: prdata={29'd0,overflow,busy_sync,tx_busy};
            8'h04: prdata={31'd0,epd_rst_n};
            8'h0c: prdata=milliseconds;
            8'h10: prdata={24'd0,app_status};
            default: prdata=0;
        endcase
    end
endmodule
