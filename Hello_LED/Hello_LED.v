`timescale 1ns/1ns

module Hello_LED
(
    //global clock
    input               clk,
    input               rst_n,

    //user interface
    output      [7:0]    led_data
);

//-------------------------------------
//led display for addr
led_addr_display
#(
    .LED_WIDTH  (8)
)
u_led_addr_display
(
    //global clock
    .clk        (clk),
    .rst_n      (rst_n),

    //user led output
    .led_data   (led_data)
);

endmodule