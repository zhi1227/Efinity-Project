// 115200 8N1 receiver in pixel domain; two-flop RX synchronization.
// ASCII '0'..'7': mode, 'm': next mode, '+','-': Canny/Sobel thresholds, 'r': reset.
// Face configuration remains compile-time; no expanded RX/TX protocol in stage 1.
`include "vision_config.vh"
module uart_params #(parameter CLKS_PER_BIT=645, parameter KEY_DEBOUNCE_CYCLES=1488000,
 parameter DEFAULT_MODE=`VISION_DEFAULT_MODE,
 parameter DEFAULT_LOW=`VISION_CANNY_LOW,DEFAULT_HIGH=`VISION_CANNY_HIGH,
 parameter MAX_MODE=13)(input clk,rst_n,rx,
 output reg [3:0] mode,output reg [11:0] low,high,input key_n,output reg pure_en,detect,output reg[7:0]skin_lower);

 function [3:0] next_menu_mode;
 input [3:0] current;
 begin case(current)
  0:next_menu_mode=1;1:next_menu_mode=10;10:next_menu_mode=9;
  9:next_menu_mode=14;14:next_menu_mode=15;default:next_menu_mode=0;
 endcase end
 endfunction
 // K1: two-stage synchronizer, ~20 ms stable press AND release.
 // A held button never repeats. Power-up held button must be released first.
 localparam KEY_COUNT_BITS=(KEY_DEBOUNCE_CYCLES<2)?1:$clog2(KEY_DEBOUNCE_CYCLES);
 (* async_reg="true" *) reg key_meta,key_sync;
 reg key_stable,key_armed,key_pulse;
 reg [KEY_COUNT_BITS-1:0] key_count;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
   key_meta<=0;key_sync<=0;key_stable<=0;key_armed<=0;key_pulse<=0;key_count<=0;
 end else begin
   key_meta<=key_n;key_sync<=key_meta;key_pulse<=0;
   if(key_sync==key_stable) key_count<=0;
   else if(key_count==KEY_DEBOUNCE_CYCLES-1) begin
     key_count<=0;key_stable<=key_sync;
     if(key_sync) key_armed<=1;
     else begin key_pulse<=key_armed;key_armed<=0;end
   end else key_count<=key_count+1'b1;
 end
 reg rx_meta,rx_sync;reg [1:0] state;reg [15:0] timer;reg [2:0] bitno;
 reg [7:0] data;reg valid;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin rx_meta<=1;rx_sync<=1;end
 else begin rx_meta<=rx;rx_sync<=rx_meta;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin state<=0;timer<=0;bitno<=0;data<=0;valid<=0;end
 else begin
 valid<=0;
 case(state)
 0:if(!rx_sync) begin state<=1;timer<=CLKS_PER_BIT/2;end
 1:if(timer!=0) timer<=timer-1'b1;else if(!rx_sync) begin state<=2;timer<=CLKS_PER_BIT-1;bitno<=0;end else state<=0;
 2:if(timer!=0) timer<=timer-1'b1;else begin data[bitno]<=rx_sync;timer<=CLKS_PER_BIT-1;if(bitno==7) state<=3;else bitno<=bitno+1'b1;end
 3:if(timer!=0) timer<=timer-1'b1;else begin valid<=rx_sync;state<=0;end
 endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin mode<=DEFAULT_MODE;low<=DEFAULT_LOW;high<=DEFAULT_HIGH;pure_en<=0;detect<=0;skin_lower<=10;end
 else begin
 // A valid UART mode command wins a simultaneous button event;
 // threshold/unknown UART bytes do not swallow the button event.
 if(key_pulse)begin mode<=next_menu_mode(mode);pure_en<=0;end
 if(valid) begin
 if(data>=8'h30&&data<=8'h35)begin
   pure_en<=0;
   case(data)"0":mode<=0;"1":mode<=1;"2":mode<=10;"3":mode<=9;"4":mode<=14;"5":mode<=15;endcase
 end
 else case(data)
 8'h6d:begin mode<=next_menu_mode(mode);pure_en<=0;end
  "p":begin pure_en<=!pure_en;mode<=0;end
  "f":detect<=!detect;
  "g":begin mode<=5;pure_en<=0;end
  "c":begin mode<=12;pure_en<=0;end
  "t":begin mode<=8;pure_en<=0;end
  "[":if(skin_lower>5)skin_lower<=skin_lower-5;
  "]":if(skin_lower<85)skin_lower<=skin_lower+5;
 8'h2b:if(low<1000) begin low<=low+8;high<=high+16;end
 8'h2d:if(low>8) begin low<=low-8;high<=high-16;end
 8'h72:begin mode<=DEFAULT_MODE;low<=DEFAULT_LOW;high<=DEFAULT_HIGH;pure_en<=0;detect<=0;skin_lower<=10;end
 endcase
 end
 end
endmodule
