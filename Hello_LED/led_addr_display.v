`timescale 1ns/1ns

module led_addr_display
#(
    parameter LED_WIDTH = 8
)
(
    //global clock
    input                       clk,
    input                       rst_n,

    //user led output
    output reg [LED_WIDTH-1:0]  led_data
);

//-------------------------------------
//Delay for 0.3s
localparam DELAY_TOP = 24'hff_ffff;
//localparam DELAY_TOP = 24'hf;      //Just for test

reg [23:0] delay_cnt;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        delay_cnt <= 0;
    else if(delay_cnt < DELAY_TOP)
        delay_cnt <= delay_cnt + 1'b1;
    else
        delay_cnt <= 0;
end

wire delay_done = (delay_cnt == DELAY_TOP) ? 1'b1 : 1'b0;


//-------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        led_data <= 0;
    else if(delay_done)
        led_data <= led_data + 1'b1;
    else
        led_data <= led_data;
end

endmodule