
//
// Verific Verilog Description of module Hello_LED
//

module Hello_LED (clk, rst_n, led_data);
    input clk /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_INPUT=TRUE */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\Hello_LED.v(6)
    input rst_n /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_INPUT=TRUE */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\Hello_LED.v(7)
    output [7:0]led_data /* verific EFX_ATTRIBUTE_PORT__IS_PRIMARY_OUTPUT=TRUE */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\Hello_LED.v(10)
    
    wire [24:0]\u_led_addr_display/n9 ;
    
    wire \u_led_addr_display/add_19/n24 , \u_led_addr_display/add_19/n26 , 
        \u_led_addr_display/add_19/n28 , \u_led_addr_display/add_19/n4 ;
    wire [7:0]\u_led_addr_display/n92 ;
    
    wire \u_led_addr_display/add_25/n2 , \u_led_addr_display/add_19/n2 , 
        \u_led_addr_display/add_19/n22 ;
    wire [24:0]\u_led_addr_display/cnt ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(23)
    
    wire \u_led_addr_display/add_19/n6 , \u_led_addr_display/add_19/n20 , 
        \u_led_addr_display/add_19/n18 , \u_led_addr_display/add_19/n16 , 
        \u_led_addr_display/add_19/n14 , \u_led_addr_display/add_19/n12 , 
        \u_led_addr_display/add_19/n10 , \u_led_addr_display/add_19/n8 , 
        \u_led_addr_display/add_19/n30 , \u_led_addr_display/add_19/n32 , 
        \u_led_addr_display/add_19/n34 , \u_led_addr_display/add_19/n36 , 
        \u_led_addr_display/add_19/n38 , \u_led_addr_display/add_19/n40 , 
        \u_led_addr_display/add_19/n42 , \u_led_addr_display/add_19/n44 , 
        \u_led_addr_display/add_19/n46 , \u_led_addr_display/add_25/n4 , 
        \u_led_addr_display/add_25/n6 , \u_led_addr_display/add_25/n8 , 
        \u_led_addr_display/add_25/n10 , \u_led_addr_display/add_25/n12 , 
        \u_led_addr_display/equal_6/n49 ;
    wire [24:0]\u_led_addr_display/n35 ;
    
    wire n123, n124, n125, n126, n127, n128, n129, n130, n131;
    
    EFX_LUT4 LUT__298 (.I0(\u_led_addr_display/cnt [18]), .I1(\u_led_addr_display/cnt [19]), 
            .I2(\u_led_addr_display/cnt [20]), .I3(\u_led_addr_display/cnt [21]), 
            .O(n124)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__298.LUTMASK = 16'h8000;
    EFX_FF \led_data[0]~FF  (.D(led_data[0]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[0])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[0]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[0]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[0]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[0]~FF .D_POLARITY = 1'b0;
    defparam \led_data[0]~FF .SR_SYNC = 1'b0;
    defparam \led_data[0]~FF .SR_VALUE = 1'b0;
    defparam \led_data[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[1]~FF  (.D(\u_led_addr_display/n35 [1]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [1])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[1]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[1]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[1]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[1]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[1]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[1]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[0]~FF  (.D(\u_led_addr_display/cnt [0]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [0])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b0, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[0]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[0]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[0]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[0]~FF .D_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[0]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[0]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[0]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[1]~FF  (.D(\u_led_addr_display/n92 [1]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[1])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[1]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[1]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[1]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[1]~FF .D_POLARITY = 1'b1;
    defparam \led_data[1]~FF .SR_SYNC = 1'b0;
    defparam \led_data[1]~FF .SR_VALUE = 1'b0;
    defparam \led_data[1]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[2]~FF  (.D(\u_led_addr_display/n92 [2]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[2])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[2]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[2]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[2]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[2]~FF .D_POLARITY = 1'b1;
    defparam \led_data[2]~FF .SR_SYNC = 1'b0;
    defparam \led_data[2]~FF .SR_VALUE = 1'b0;
    defparam \led_data[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[3]~FF  (.D(\u_led_addr_display/n92 [3]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[3])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[3]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[3]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[3]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[3]~FF .D_POLARITY = 1'b1;
    defparam \led_data[3]~FF .SR_SYNC = 1'b0;
    defparam \led_data[3]~FF .SR_VALUE = 1'b0;
    defparam \led_data[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[4]~FF  (.D(\u_led_addr_display/n92 [4]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[4])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[4]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[4]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[4]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[4]~FF .D_POLARITY = 1'b1;
    defparam \led_data[4]~FF .SR_SYNC = 1'b0;
    defparam \led_data[4]~FF .SR_VALUE = 1'b0;
    defparam \led_data[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[5]~FF  (.D(\u_led_addr_display/n92 [5]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[5])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[5]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[5]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[5]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[5]~FF .D_POLARITY = 1'b1;
    defparam \led_data[5]~FF .SR_SYNC = 1'b0;
    defparam \led_data[5]~FF .SR_VALUE = 1'b0;
    defparam \led_data[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[6]~FF  (.D(\u_led_addr_display/n92 [6]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[6])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[6]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[6]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[6]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[6]~FF .D_POLARITY = 1'b1;
    defparam \led_data[6]~FF .SR_SYNC = 1'b0;
    defparam \led_data[6]~FF .SR_VALUE = 1'b0;
    defparam \led_data[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \led_data[7]~FF  (.D(\u_led_addr_display/n92 [7]), .CE(\u_led_addr_display/equal_6/n49 ), 
           .CLK(clk), .SR(rst_n), .Q(led_data[7])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b0, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \led_data[7]~FF .CLK_POLARITY = 1'b1;
    defparam \led_data[7]~FF .CE_POLARITY = 1'b0;
    defparam \led_data[7]~FF .SR_POLARITY = 1'b0;
    defparam \led_data[7]~FF .D_POLARITY = 1'b1;
    defparam \led_data[7]~FF .SR_SYNC = 1'b0;
    defparam \led_data[7]~FF .SR_VALUE = 1'b0;
    defparam \led_data[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[2]~FF  (.D(\u_led_addr_display/n9 [2]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [2])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[2]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[2]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[2]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[2]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[2]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[2]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[2]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[3]~FF  (.D(\u_led_addr_display/n9 [3]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [3])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[3]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[3]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[3]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[3]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[3]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[3]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[3]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[4]~FF  (.D(\u_led_addr_display/n9 [4]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [4])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[4]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[4]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[4]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[4]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[4]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[4]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[4]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[5]~FF  (.D(\u_led_addr_display/n9 [5]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [5])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[5]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[5]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[5]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[5]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[5]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[5]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[5]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[6]~FF  (.D(\u_led_addr_display/n35 [6]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [6])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[6]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[6]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[6]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[6]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[6]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[6]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[6]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[7]~FF  (.D(\u_led_addr_display/n9 [7]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [7])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[7]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[7]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[7]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[7]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[7]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[7]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[7]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[8]~FF  (.D(\u_led_addr_display/n9 [8]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [8])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[8]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[8]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[8]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[8]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[8]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[8]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[8]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[9]~FF  (.D(\u_led_addr_display/n9 [9]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [9])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[9]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[9]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[9]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[9]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[9]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[9]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[9]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[10]~FF  (.D(\u_led_addr_display/n9 [10]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [10])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[10]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[10]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[10]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[10]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[10]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[10]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[10]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[11]~FF  (.D(\u_led_addr_display/n35 [11]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [11])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[11]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[11]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[11]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[11]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[11]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[11]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[11]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[12]~FF  (.D(\u_led_addr_display/n35 [12]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [12])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[12]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[12]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[12]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[12]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[12]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[12]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[12]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[13]~FF  (.D(\u_led_addr_display/n35 [13]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [13])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[13]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[13]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[13]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[13]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[13]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[13]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[13]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[14]~FF  (.D(\u_led_addr_display/n35 [14]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [14])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[14]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[14]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[14]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[14]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[14]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[14]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[14]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[15]~FF  (.D(\u_led_addr_display/n9 [15]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [15])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[15]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[15]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[15]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[15]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[15]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[15]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[15]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[16]~FF  (.D(\u_led_addr_display/n35 [16]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [16])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[16]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[16]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[16]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[16]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[16]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[16]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[16]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[17]~FF  (.D(\u_led_addr_display/n9 [17]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [17])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[17]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[17]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[17]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[17]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[17]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[17]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[17]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[18]~FF  (.D(\u_led_addr_display/n35 [18]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [18])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[18]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[18]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[18]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[18]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[18]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[18]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[18]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[19]~FF  (.D(\u_led_addr_display/n35 [19]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [19])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[19]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[19]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[19]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[19]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[19]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[19]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[19]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[20]~FF  (.D(\u_led_addr_display/n35 [20]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [20])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[20]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[20]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[20]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[20]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[20]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[20]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[20]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[21]~FF  (.D(\u_led_addr_display/n35 [21]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [21])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[21]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[21]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[21]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[21]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[21]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[21]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[21]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[22]~FF  (.D(\u_led_addr_display/n35 [22]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [22])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[22]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[22]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[22]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[22]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[22]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[22]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[22]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[23]~FF  (.D(\u_led_addr_display/n9 [23]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [23])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[23]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[23]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[23]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[23]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[23]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[23]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[23]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_FF \u_led_addr_display/cnt[24]~FF  (.D(\u_led_addr_display/n35 [24]), 
           .CE(1'b1), .CLK(clk), .SR(rst_n), .Q(\u_led_addr_display/cnt [24])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_FF, CLK_POLARITY=1'b1, D_POLARITY=1'b1, CE_POLARITY=1'b1, SR_SYNC=1'b0, SR_SYNC_PRIORITY=1'b1, SR_VALUE=1'b0, SR_POLARITY=1'b0 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/cnt[24]~FF .CLK_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[24]~FF .CE_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[24]~FF .SR_POLARITY = 1'b0;
    defparam \u_led_addr_display/cnt[24]~FF .D_POLARITY = 1'b1;
    defparam \u_led_addr_display/cnt[24]~FF .SR_SYNC = 1'b0;
    defparam \u_led_addr_display/cnt[24]~FF .SR_VALUE = 1'b0;
    defparam \u_led_addr_display/cnt[24]~FF .SR_SYNC_PRIORITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i12  (.I0(\u_led_addr_display/cnt [12]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n22 ), .O(\u_led_addr_display/n9 [12]), 
            .CO(\u_led_addr_display/add_19/n24 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i12 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i12 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i13  (.I0(\u_led_addr_display/cnt [13]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n24 ), .O(\u_led_addr_display/n9 [13]), 
            .CO(\u_led_addr_display/add_19/n26 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i13 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i13 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i14  (.I0(\u_led_addr_display/cnt [14]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n26 ), .O(\u_led_addr_display/n9 [14]), 
            .CO(\u_led_addr_display/add_19/n28 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i14 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i14 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i2  (.I0(\u_led_addr_display/cnt [2]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n2 ), .O(\u_led_addr_display/n9 [2]), 
            .CO(\u_led_addr_display/add_19/n4 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i2 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i1  (.I0(led_data[1]), .I1(led_data[0]), 
            .CI(1'b0), .O(\u_led_addr_display/n92 [1]), .CO(\u_led_addr_display/add_25/n2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i1 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i1  (.I0(\u_led_addr_display/cnt [1]), 
            .I1(\u_led_addr_display/cnt [0]), .CI(1'b0), .O(\u_led_addr_display/n9 [1]), 
            .CO(\u_led_addr_display/add_19/n2 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i1 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i1 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i11  (.I0(\u_led_addr_display/cnt [11]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n20 ), .O(\u_led_addr_display/n9 [11]), 
            .CO(\u_led_addr_display/add_19/n22 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i11 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i11 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i3  (.I0(\u_led_addr_display/cnt [3]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n4 ), .O(\u_led_addr_display/n9 [3]), 
            .CO(\u_led_addr_display/add_19/n6 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i3 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i10  (.I0(\u_led_addr_display/cnt [10]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n18 ), .O(\u_led_addr_display/n9 [10]), 
            .CO(\u_led_addr_display/add_19/n20 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i10 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i10 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i9  (.I0(\u_led_addr_display/cnt [9]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n16 ), .O(\u_led_addr_display/n9 [9]), 
            .CO(\u_led_addr_display/add_19/n18 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i9 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i9 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i8  (.I0(\u_led_addr_display/cnt [8]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n14 ), .O(\u_led_addr_display/n9 [8]), 
            .CO(\u_led_addr_display/add_19/n16 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i8 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i8 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i7  (.I0(\u_led_addr_display/cnt [7]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n12 ), .O(\u_led_addr_display/n9 [7]), 
            .CO(\u_led_addr_display/add_19/n14 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i7 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i7 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i6  (.I0(\u_led_addr_display/cnt [6]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n10 ), .O(\u_led_addr_display/n9 [6]), 
            .CO(\u_led_addr_display/add_19/n12 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i6 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i5  (.I0(\u_led_addr_display/cnt [5]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n8 ), .O(\u_led_addr_display/n9 [5]), 
            .CO(\u_led_addr_display/add_19/n10 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i5 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i4  (.I0(\u_led_addr_display/cnt [4]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n6 ), .O(\u_led_addr_display/n9 [4]), 
            .CO(\u_led_addr_display/add_19/n8 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i4 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i15  (.I0(\u_led_addr_display/cnt [15]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n28 ), .O(\u_led_addr_display/n9 [15]), 
            .CO(\u_led_addr_display/add_19/n30 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i15 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i15 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i16  (.I0(\u_led_addr_display/cnt [16]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n30 ), .O(\u_led_addr_display/n9 [16]), 
            .CO(\u_led_addr_display/add_19/n32 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i16 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i16 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i17  (.I0(\u_led_addr_display/cnt [17]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n32 ), .O(\u_led_addr_display/n9 [17]), 
            .CO(\u_led_addr_display/add_19/n34 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i17 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i17 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i18  (.I0(\u_led_addr_display/cnt [18]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n34 ), .O(\u_led_addr_display/n9 [18]), 
            .CO(\u_led_addr_display/add_19/n36 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i18 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i18 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i19  (.I0(\u_led_addr_display/cnt [19]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n36 ), .O(\u_led_addr_display/n9 [19]), 
            .CO(\u_led_addr_display/add_19/n38 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i19 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i19 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i20  (.I0(\u_led_addr_display/cnt [20]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n38 ), .O(\u_led_addr_display/n9 [20]), 
            .CO(\u_led_addr_display/add_19/n40 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i20 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i20 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i21  (.I0(\u_led_addr_display/cnt [21]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n40 ), .O(\u_led_addr_display/n9 [21]), 
            .CO(\u_led_addr_display/add_19/n42 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i21 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i21 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i22  (.I0(\u_led_addr_display/cnt [22]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n42 ), .O(\u_led_addr_display/n9 [22]), 
            .CO(\u_led_addr_display/add_19/n44 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i22 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i22 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i23  (.I0(\u_led_addr_display/cnt [23]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n44 ), .O(\u_led_addr_display/n9 [23]), 
            .CO(\u_led_addr_display/add_19/n46 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i23 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i23 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_19/i24  (.I0(\u_led_addr_display/cnt [24]), 
            .I1(1'b0), .CI(\u_led_addr_display/add_19/n46 ), .O(\u_led_addr_display/n9 [24])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam \u_led_addr_display/add_19/i24 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_19/i24 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i2  (.I0(led_data[2]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n2 ), .O(\u_led_addr_display/n92 [2]), 
            .CO(\u_led_addr_display/add_25/n4 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i2 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i2 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i3  (.I0(led_data[3]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n4 ), .O(\u_led_addr_display/n92 [3]), 
            .CO(\u_led_addr_display/add_25/n6 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i3 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i3 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i4  (.I0(led_data[4]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n6 ), .O(\u_led_addr_display/n92 [4]), 
            .CO(\u_led_addr_display/add_25/n8 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i4 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i4 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i5  (.I0(led_data[5]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n8 ), .O(\u_led_addr_display/n92 [5]), 
            .CO(\u_led_addr_display/add_25/n10 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i5 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i5 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i6  (.I0(led_data[6]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n10 ), .O(\u_led_addr_display/n92 [6]), 
            .CO(\u_led_addr_display/add_25/n12 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i6 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i6 .I1_POLARITY = 1'b1;
    EFX_ADD \u_led_addr_display/add_25/i7  (.I0(led_data[7]), .I1(1'b0), 
            .CI(\u_led_addr_display/add_25/n12 ), .O(\u_led_addr_display/n92 [7])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_ADD, I0_POLARITY=1'b1, I1_POLARITY=1'b1 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(45)
    defparam \u_led_addr_display/add_25/i7 .I0_POLARITY = 1'b1;
    defparam \u_led_addr_display/add_25/i7 .I1_POLARITY = 1'b1;
    EFX_LUT4 LUT__299 (.I0(\u_led_addr_display/cnt [15]), .I1(\u_led_addr_display/cnt [17]), 
            .I2(\u_led_addr_display/cnt [16]), .I3(\u_led_addr_display/cnt [14]), 
            .O(n125)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h1000 */ ;
    defparam LUT__299.LUTMASK = 16'h1000;
    EFX_LUT4 LUT__300 (.I0(n123), .I1(n124), .I2(n125), .O(n126)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8080 */ ;
    defparam LUT__300.LUTMASK = 16'h8080;
    EFX_LUT4 LUT__301 (.I0(\u_led_addr_display/cnt [1]), .I1(\u_led_addr_display/cnt [0]), 
            .O(n127)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8888 */ ;
    defparam LUT__301.LUTMASK = 16'h8888;
    EFX_LUT4 LUT__302 (.I0(\u_led_addr_display/cnt [2]), .I1(\u_led_addr_display/cnt [3]), 
            .I2(\u_led_addr_display/cnt [4]), .I3(\u_led_addr_display/cnt [5]), 
            .O(n128)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__302.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__303 (.I0(\u_led_addr_display/cnt [10]), .I1(\u_led_addr_display/cnt [11]), 
            .I2(\u_led_addr_display/cnt [12]), .I3(\u_led_addr_display/cnt [13]), 
            .O(n129)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4000 */ ;
    defparam LUT__303.LUTMASK = 16'h4000;
    EFX_LUT4 LUT__304 (.I0(\u_led_addr_display/cnt [6]), .I1(\u_led_addr_display/cnt [7]), 
            .I2(\u_led_addr_display/cnt [8]), .I3(\u_led_addr_display/cnt [9]), 
            .O(n130)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h0001 */ ;
    defparam LUT__304.LUTMASK = 16'h0001;
    EFX_LUT4 LUT__305 (.I0(n127), .I1(n128), .I2(n129), .I3(n130), .O(n131)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h8000 */ ;
    defparam LUT__305.LUTMASK = 16'h8000;
    EFX_LUT4 LUT__306 (.I0(n126), .I1(n131), .O(\u_led_addr_display/equal_6/n49 )) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7777 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(29)
    defparam LUT__306.LUTMASK = 16'h7777;
    EFX_LUT4 LUT__307 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [1]), 
            .O(\u_led_addr_display/n35 [1])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__307.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__308 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [6]), 
            .O(\u_led_addr_display/n35 [6])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__308.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__309 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [11]), 
            .O(\u_led_addr_display/n35 [11])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__309.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__310 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [12]), 
            .O(\u_led_addr_display/n35 [12])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__310.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__311 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [13]), 
            .O(\u_led_addr_display/n35 [13])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__311.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__312 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [14]), 
            .O(\u_led_addr_display/n35 [14])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__312.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__313 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [16]), 
            .O(\u_led_addr_display/n35 [16])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__313.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__314 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [18]), 
            .O(\u_led_addr_display/n35 [18])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__314.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__315 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [19]), 
            .O(\u_led_addr_display/n35 [19])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__315.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__316 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [20]), 
            .O(\u_led_addr_display/n35 [20])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__316.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__317 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [21]), 
            .O(\u_led_addr_display/n35 [21])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__317.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__318 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [22]), 
            .O(\u_led_addr_display/n35 [22])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__318.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__319 (.I0(n131), .I1(n126), .I2(\u_led_addr_display/n9 [24]), 
            .O(\u_led_addr_display/n35 [24])) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h7070 */ ;   // D:\yilingsi_fpga\Efinity_Project\Hello_LED\led_addr_display.v(32)
    defparam LUT__319.LUTMASK = 16'h7070;
    EFX_LUT4 LUT__297 (.I0(\u_led_addr_display/cnt [23]), .I1(\u_led_addr_display/cnt [22]), 
            .I2(\u_led_addr_display/cnt [24]), .O(n123)) /* verific EFX_ATTRIBUTE_CELL_NAME=EFX_LUT4, LUTMASK=16'h4040 */ ;
    defparam LUT__297.LUTMASK = 16'h4040;
    
endmodule

//
// Verific Verilog Description of module EFX_LUT4_307a64c6_0
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF_307a64c6_0
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF_307a64c6_1
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF_307a64c6_2
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_FF_307a64c6_3
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_ADD_307a64c6_0
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_1
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_2
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_3
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_4
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_5
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_6
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_7
// module not written out since it is a black box. 
//


//
// Verific Verilog Description of module EFX_LUT4_307a64c6_8
// module not written out since it is a black box. 
//

