// IO28, IO29, IO34 and IO35: released high, pressed low.
// K1 toggles PiP; K2 selects Canny BOTH/HIGH/LOW.
// Context is bound at the debounced press; changing mode cancels held actions.
module vision8_key #(parameter DEBOUNCE=1488000,LONG_CYCLES=148800000,CONTEXT_BITS=4)(
 input clk,rst_n,key_n,input[CONTEXT_BITS-1:0]context_i,
 output wire short_o,long_o);
 localparam DB=DEBOUNCE<2?1:$clog2(DEBOUNCE),LB=LONG_CYCLES<2?1:$clog2(LONG_CYCLES);
 (* async_reg="true" *)reg meta,sync;
 reg stable,armed,held,fired,cancel;reg[CONTEXT_BITS-1:0]bound;
 reg short_event,long_event;
 reg[DB-1:0]deb;reg[LB-1:0]duration;
 wire stable_change=(sync!=stable)&&(deb==DEBOUNCE-1);
 // A context may change on the same edge that registers an event. Mask the
 // pending pulse before the controller can consume it in the new context.
 assign short_o=short_event&&!cancel&&(context_i==bound);
 assign long_o=long_event&&!cancel&&(context_i==bound);
 always @(posedge clk)begin
  if(!rst_n)begin meta<=0;sync<=0;stable<=0;armed<=0;held<=0;fired<=0;cancel<=0;bound<=0;deb<=0;duration<=0;short_event<=0;long_event<=0;end
  else begin
   meta<=key_n;sync<=meta;short_event<=0;long_event<=0;
   if(held&&context_i!=bound)cancel<=1;
   if(sync==stable)deb<=0;
   else if(stable_change)begin
    deb<=0;stable<=sync;
    if(sync)begin
     armed<=1;
     if(held&&!fired&&!cancel&&context_i==bound)begin
      // A release on the exact long-press threshold is a long event only.
      if(duration==LONG_CYCLES-1)long_event<=1;
      else short_event<=1;
     end
     held<=0;duration<=0;
    end
    else if(armed)begin armed<=0;held<=1;fired<=0;cancel<=0;bound<=context_i;duration<=0;end
   end else deb<=deb+1'b1;
   // Do not also run the held timer on a debounced press/release cycle.
   if(!stable_change&&held&&!stable&&!fired&&!cancel&&context_i==bound)begin
    if(duration==LONG_CYCLES-1)begin fired<=1;long_event<=1;end else duration<=duration+1'b1;
   end
  end
 end
endmodule

module vision8_controls #(
 parameter DEBOUNCE=1488000,LONG_CYCLES=148800000,UART_CLKS_PER_BIT=645)(
 input clk,rst_n,frame_start,io28,io29,k1_n,k2_n,io34,io35,
 input capture_busy,learning,rx,
 output reg settings_open,output reg[2:0]user_mode,output reg[1:0]capture_alg,
 output reg pip_enable,freeze_request,output reg capture,clear,
 output reg gesture_short,gesture_long,
 output reg[11:0]low,high,output reg[1:0]selected,step_select,
 output reg[11:0]low_active,high_active,output reg[15:0]version,
 output reg[11:0]red,red_active,cyber,cyber_active,
 output[3:0]backend_mode,output reg pure_o,detect_extra,output reg[7:0]skin_lower);
 `include "vision8_modes.vh"
 // Six released-high / pressed-low inputs; selector changes cancel held edits.
 wire[5:0]s,l;
 wire[5:0]key_context={selected,user_mode==5&&learning,user_mode};
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) a(clk,rst_n,io28,key_context,s[0],l[0]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) b(clk,rst_n,io29,key_context,s[1],l[1]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) c(clk,rst_n,io34,key_context,s[2],l[2]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) d(clk,rst_n,io35,key_context,s[3],l[3]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) e(clk,rst_n,k1_n,key_context,s[4],l[4]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) f(clk,rst_n,k2_n,key_context,s[5],l[5]);
 wire[11:0]step=step_select==0?12'd1:step_select==1?12'd4:12'd8;
 wire serial_valid;wire[7:0]serial_data;reg diagnostic;reg[3:0]diagnostic_mode;
 vision8_uart #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) serial(clk,rst_n,rx,serial_valid,serial_data);
 wire[1:0]algorithm=user_mode==7?capture_alg:user_mode[1:0];
 // 0=no editable profile, 1=Canny, 2=raw-Sobel red, 3=8-bit cyber.
 wire[1:0]profile=(user_mode==1||user_mode==4)?2'd1:
                    user_mode==2?2'd2:user_mode==3?2'd3:
                    user_mode==7?capture_alg:2'd0;
 assign backend_mode=diagnostic?diagnostic_mode:user_mode==5?4'd15:user_mode==4?4'd14:user_mode==6?4'd0:
  algorithm==0?4'd0:algorithm==1?4'd1:algorithm==2?4'd10:4'd9;
 function[11:0]increase;
  input[11:0]value,amount,maximum;
  reg[12:0]sum;
  begin sum={1'b0,value}+{1'b0,amount};increase=sum>{1'b0,maximum}?maximum:sum[11:0];end
 endfunction
 function[11:0]decrease;
  input[11:0]value,amount,minimum;
  begin decrease=value<=minimum+amount?minimum:value-amount;end
 endfunction
 function[11:0]canny_low;
  input[11:0]threshold;
  begin canny_low=threshold<2?12'd1:threshold>>1;end
 endfunction
 wire[11:0]up_room=(12'd2040-high)>>1;
 wire[11:0]down_room_low=low-1'b1,down_room_gap=high-low-1'b1;
 wire[11:0]both_up=step<up_room?step:up_room;
 wire[11:0]down_room=down_room_low<down_room_gap?down_room_low:down_room_gap;
 wire[11:0]both_down=step<down_room?step:down_room;
 wire[2:0]next_mode=slot_to_mode(mode_to_slot(user_mode)+3'd1);
 task change_mode;
 input[2:0]target;
 begin
  if(user_mode==7&&target!=7)begin clear<=1;capture_alg<=0;end
  user_mode<=target;freeze_request<=0;diagnostic<=0;pure_o<=0;selected<=0;
 end
 endtask
 // These tasks only assign the pending registers. All active registers are
 // committed together at frame_start, including edits made while frozen.
 task adjust;
  input[1:0]which;input increment;
  begin
   case(which)
    1:begin
     case(selected)
      1:high<=increment?increase(high,step,12'd2040):decrease(high,step,low+1'b1);
      2:low<=increment?increase(low,step,high-1'b1):decrease(low,step,12'd1);
      default:begin low<=increment?low+both_up:low-both_down;high<=increment?high+(both_up<<1):high-(both_down<<1);end
     endcase
    end
    2:red<=increment?increase(red,step,12'd2040):decrease(red,step,12'd1);
    3:cyber<=increment?increase(cyber,step,12'd255):decrease(cyber,step,12'd1);
    default:begin end
   endcase
  end
 endtask
 task restore_profile;
  input[1:0]which;
  begin
   case(which)
    1:begin low<=40;high<=80;selected<=0;end
    2:red<=40;
    3:cyber<=24;
    default:begin end
   endcase
  end
 endtask
 always @(posedge clk)begin
  if(!rst_n)begin
   user_mode<=0;settings_open<=0;capture_alg<=0;pip_enable<=0;freeze_request<=0;
   capture<=0;clear<=0;gesture_short<=0;gesture_long<=0;
   low<=40;high<=80;low_active<=40;high_active<=80;red<=40;red_active<=40;cyber<=24;cyber_active<=24;
   selected<=0;step_select<=0;version<=0;pure_o<=0;detect_extra<=0;skin_lower<=10;diagnostic<=0;diagnostic_mode<=0;
  end else begin
   settings_open<=0;
   capture<=0;clear<=0;gesture_short<=0;gesture_long<=0;
   if(frame_start)begin
    low_active<=low;high_active<=high;red_active<=red;cyber_active<=cyber;
    if(low!=low_active||high!=high_active||red!=red_active||cyber!=cyber_active)version<=version+1'b1;
   end
   // Physical mode events have first priority; other physical events precede
   // UART. Thus a released key cannot also edit the new mode on this edge.
   if(s[0])change_mode(next_mode);
   else if(|s||(|l))begin
    if(s[4]&&user_mode>=1&&user_mode<=3)pip_enable<=~pip_enable;
    if(s[5]&&(user_mode==1||user_mode==4))selected<=selected==2?0:selected+1'b1;
    if(user_mode==7)begin
     if(s[1]&&!capture_busy)capture<=1;
     if(l[1])begin clear<=1;capture_alg<=0;end
     if(s[2]&&!capture_busy)capture_alg<=capture_alg+1'b1;
    end else if(user_mode==5)begin
     gesture_short<=s[2];gesture_long<=l[2];
     if(l[2])freeze_request<=0;
     else if(s[1]&&!learning)freeze_request<=~freeze_request;
    end else begin
     if(s[1])freeze_request<=~freeze_request;
     if(user_mode>=1&&user_mode<=4)begin
      if(l[2])step_select<=step_select==2?0:step_select+1'b1;
      if(s[5])begin end
      else if(l[3])restore_profile(profile);
      else if(s[2])adjust(profile,1'b0);
      else if(s[3])adjust(profile,1'b1);
     end
    end
   end else if(serial_valid)begin
    if(serial_data>="0"&&serial_data<="7")change_mode(slot_to_mode(serial_data[2:0]));
    else case(serial_data)
     "m":change_mode(next_mode);
     "+":adjust(profile,1'b1);
     "-":adjust(profile,1'b0);
     "r":begin change_mode(0);low<=40;high<=80;red<=40;cyber<=24;selected<=0;step_select<=0;pure_o<=0;diagnostic<=0;detect_extra<=0;skin_lower<=10;freeze_request<=0;end
     "p":begin change_mode(0);pure_o<=~pure_o;end
     "f":detect_extra<=~detect_extra;
     "g":begin change_mode(0);diagnostic<=1;diagnostic_mode<=5;pure_o<=0;end
     "c":begin change_mode(0);diagnostic<=1;diagnostic_mode<=12;pure_o<=0;end
     "t":begin change_mode(0);diagnostic<=1;diagnostic_mode<=8;pure_o<=0;end
     "[":if(skin_lower>5)skin_lower<=skin_lower-5;
     "]":if(skin_lower<85)skin_lower<=skin_lower+5;
    endcase
   end
  end
 end
endmodule
