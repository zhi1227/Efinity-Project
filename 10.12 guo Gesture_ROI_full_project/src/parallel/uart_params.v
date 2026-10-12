// 115200 8N1 receiver in pixel domain; two-flop RX synchronization.
// K1 hold: threshold editor. In editor K1/K2 short: -/+, K2 hold: select.
// UART mode commands and paired +/- adjustment remain available.
// Face configuration remains compile-time; no expanded RX/TX protocol in stage 1.
`include "vision_config.vh"
module uart_params #(parameter CLKS_PER_BIT=645, parameter KEY_DEBOUNCE_CYCLES=1488000,
 parameter KEY_LONG_CYCLES=148800000,
 parameter DEFAULT_MODE=`VISION_DEFAULT_MODE,
 parameter DEFAULT_LOW=`VISION_CANNY_LOW,DEFAULT_HIGH=`VISION_CANNY_HIGH,
 parameter MAX_MODE=13)(input clk,rst_n,rx,
 output reg [3:0] mode,output reg [11:0] low,high,input key_n,output reg pure_en,detect,output reg[7:0]skin_lower,
 input key2_n,output reg threshold_edit,select_high,output normal_short,normal_long);

 function [3:0] next_menu_mode;
 input [3:0] current;
 begin case(current)
  0:next_menu_mode=1;1:next_menu_mode=10;10:next_menu_mode=9;
  9:next_menu_mode=14;14:next_menu_mode=15;default:next_menu_mode=0;
 endcase end
 endfunction
 // Short presses fire on release, so a long K1 never advances the mode.
 wire key_short,key_long,key2_short,key2_long,key2_down;
 gesture_key #(.DEBOUNCE(KEY_DEBOUNCE_CYCLES),.LONG_CYCLES(KEY_LONG_CYCLES)) k1(
  .clk(clk),.rst_n(rst_n),.key_n(key_n),.short_press(key_short),.long_press(key_long),.down());
 gesture_key #(.DEBOUNCE(KEY_DEBOUNCE_CYCLES),.LONG_CYCLES(KEY_LONG_CYCLES)) k2(
  .clk(clk),.rst_n(rst_n),.key_n(key2_n),.short_press(key2_short),.long_press(key2_long),.down(key2_down));
 // Remember which context owns a K2 press. Releasing it after exiting the
 // editor cannot accidentally freeze the image or start gesture enrolment.
 reg key2_down_q,key2_editor;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin key2_down_q<=1;key2_editor<=0;end
 else begin
  key2_down_q<=key2_down;
  if(key2_down&&!key2_down_q)key2_editor<=threshold_edit;
 end
 assign normal_short=key2_short&&!threshold_edit&&!key_long&&!key2_editor;
 assign normal_long=key2_long&&!threshold_edit&&!key_long&&!key2_editor;
 function [11:0] up8;
 input [11:0] value;
 begin up8=value>4087?12'd4095:value+12'd8;end
 endfunction
 function [11:0] down8;
 input [11:0] value;
 begin down8=value>8?value-12'd8:12'd1;end
 endfunction
 wire [11:0] uart_low_up=up8(low),uart_high_up=high>4079?12'd4095:high+12'd16;
 wire [11:0] uart_low_down=down8(low),uart_high_down=high>16?high-12'd16:12'd2;
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
 if(!rst_n) begin mode<=DEFAULT_MODE;low<=DEFAULT_LOW;high<=DEFAULT_HIGH;pure_en<=0;detect<=0;skin_lower<=10;threshold_edit<=0;select_high<=0;end
 else begin
 // A valid UART mode command wins a simultaneous button event;
 // threshold/unknown UART bytes do not swallow the button event.
 if(key_long)begin threshold_edit<=!threshold_edit;select_high<=0;end
 else if(threshold_edit)begin
  if(key2_long&&key2_editor)select_high<=!select_high;
  else if(key_short)begin
   if(select_high)high<=down8(high)<=low?low+12'd1:down8(high);
   else low<=down8(low);
  end else if(key2_short&&key2_editor)begin
   if(select_high)high<=up8(high);
   else low<=up8(low)>=high?high-12'd1:up8(low);
  end
 end else if(key_short)begin mode<=next_menu_mode(mode);pure_en<=0;end
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
 8'h2b:begin low<=uart_low_up>=uart_high_up?uart_high_up-12'd1:uart_low_up;high<=uart_high_up;end
 8'h2d:begin low<=uart_low_down;high<=uart_high_down<=uart_low_down?uart_low_down+12'd1:uart_high_down;end
 8'h72:begin mode<=DEFAULT_MODE;low<=DEFAULT_LOW;high<=DEFAULT_HIGH;pure_en<=0;detect<=0;skin_lower<=10;threshold_edit<=0;select_high<=0;end
 endcase
 end
 end
endmodule
