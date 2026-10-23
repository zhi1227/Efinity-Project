// IO28 / IO35 idle low, pressed high. IO29 and board keys are active low.
// Context is bound at the debounced press; changing mode cancels held actions.
module vision8_key #(parameter DEBOUNCE=1488000,LONG_CYCLES=148800000)(
 input clk,rst_n,key_n,input[3:0]context_i,
 output reg short_o,long_o);
 localparam DB=DEBOUNCE<2?1:$clog2(DEBOUNCE),LB=LONG_CYCLES<2?1:$clog2(LONG_CYCLES);
 (* async_reg="true" *)reg meta,sync;
 reg stable,armed,held,fired,cancel;reg[3:0]bound;
 reg[DB-1:0]deb;reg[LB-1:0]duration;
 always @(posedge clk)begin
  if(!rst_n)begin meta<=0;sync<=0;stable<=0;armed<=0;held<=0;fired<=0;cancel<=0;bound<=0;deb<=0;duration<=0;short_o<=0;long_o<=0;end
  else begin
   meta<=key_n;sync<=meta;short_o<=0;long_o<=0;
   if(held&&context_i!=bound)cancel<=1;
   if(sync==stable)deb<=0;
   else if(deb==DEBOUNCE-1)begin
    deb<=0;stable<=sync;
    if(sync)begin armed<=1;if(held&&!fired&&!cancel&&context_i==bound)short_o<=1;held<=0;duration<=0;end
    else if(armed)begin armed<=0;held<=1;fired<=0;cancel<=0;bound<=context_i;duration<=0;end
   end else deb<=deb+1'b1;
   if(held&&!stable&&!fired&&!cancel&&context_i==bound)begin
    if(duration==LONG_CYCLES-1)begin fired<=1;long_o<=1;end else duration<=duration+1'b1;
   end
  end
 end
endmodule

module vision8_controls #(parameter DEBOUNCE=1488000,LONG_CYCLES=148800000)(
 input clk,rst_n,frame_start,io28,io29,k1_n,k2_n,io35,
 input capture_busy,learning,rx,
 output reg settings_open,output reg[2:0]user_mode,output reg[1:0]capture_alg,
 output reg pip_enable,freeze_request,output reg capture,clear,
 output reg gesture_short,gesture_long,
 output reg[11:0]low,high,output reg[1:0]selected,step_select,
 output reg[11:0]low_active,high_active,output reg[15:0]version,
 output[3:0]backend_mode,output reg pure_o,detect_extra,output reg[7:0]skin_lower);
 wire[3:0]s,l;
 wire threshold_short,threshold_long;
 wire[3:0]key_context={settings_open,user_mode};
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES)) a(clk,rst_n,~io28,key_context,s[0],l[0]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES)) b(clk,rst_n,io29,key_context,s[1],l[1]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES)) c(clk,rst_n,k1_n,key_context,s[2],l[2]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES)) d(clk,rst_n,k2_n,key_context,s[3],l[3]);
 vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES)) threshold_key(clk,rst_n,~io35,key_context,threshold_short,threshold_long);
 wire[11:0]step=step_select==0?12'd1:step_select==1?12'd4:12'd8;
 wire[11:0]inc_limit=selected==0?high-1:12'd2040;
 wire[11:0]dec_limit=selected==1?low+1:12'd1;
 reg[11:0]delta;
 wire serial_valid;wire[7:0]serial_data;reg diagnostic;reg[3:0]diagnostic_mode;
 vision8_uart serial(clk,rst_n,rx,serial_valid,serial_data);
 wire[1:0]algorithm=user_mode==7?capture_alg:user_mode[1:0];
 assign backend_mode=diagnostic?diagnostic_mode:user_mode==5?4'd15:user_mode==4?4'd14:user_mode==6?4'd0:
  algorithm==0?4'd0:algorithm==1?4'd1:algorithm==2?4'd10:4'd9;
 always @(posedge clk)begin
  if(!rst_n)begin user_mode<=0;settings_open<=0;capture_alg<=0;pip_enable<=0;freeze_request<=0;capture<=0;clear<=0;gesture_short<=0;gesture_long<=0;
   low<=40;high<=80;low_active<=40;high_active<=80;selected<=0;step_select<=0;version<=0;delta<=0;pure_o<=0;detect_extra<=0;skin_lower<=10;diagnostic<=0;diagnostic_mode<=0;end
  else begin
   capture<=0;clear<=0;gesture_short<=0;gesture_long<=0;
   if(frame_start)begin
    low_active<=low;high_active<=high;
    if(low!=low_active||high!=high_active)version<=version+1'b1;
   end
   if(s[0])begin user_mode<=user_mode+1'b1;freeze_request<=0;diagnostic<=0;pure_o<=0;settings_open<=0;end
   else if(threshold_short)begin
    // A settings page, independent of the eight processing modes.
    // Keep the HDMI algorithm and freeze state unchanged when opening/closing.
    settings_open<=~settings_open;
   end
   else begin
    if(!settings_open&&l[0]&&user_mode>=1&&user_mode<=3)pip_enable<=~pip_enable;
    if(settings_open)begin
     if(s[2])selected<=selected==2?0:selected+1'b1;
     if(l[2])step_select<=step_select==2?0:step_select+1'b1;
     if(l[1])freeze_request<=~freeze_request;
     if(s[3])begin
      if(selected==2)begin delta=(2040-high<step)?2040-high:step;low<=low+delta;high<=high+delta;end
      else if(selected==0)low<=inc_limit-low<step?inc_limit:low+step;
      else high<=inc_limit-high<step?inc_limit:high+step;
     end else if(s[1])begin
      if(selected==2)begin delta=(low-1<step)?low-1:step;low<=low-delta;high<=high-delta;end
      else if(selected==1)high<=high-dec_limit<step?dec_limit:high-step;
      else low<=low-dec_limit<step?dec_limit:low-step;
     end
    end else if(user_mode==7)begin
     if(s[1]&&!capture_busy)capture<=1;
     if(l[1])clear<=1;
     if(s[3]&&!capture_busy)capture_alg<=capture_alg+1'b1;
    end else if(user_mode==5)begin
     gesture_short<=s[2];gesture_long<=l[2];
     if(l[2])freeze_request<=0;
     else if(s[1]&&!learning)freeze_request<=~freeze_request;
    end else if(s[1])freeze_request<=~freeze_request;
   end
   // UART remains available for maintenance. Human modes are 0..7 here.
   if(serial_valid)begin
    if((serial_data>="0"&&serial_data<="7")||serial_data=="m"||serial_data=="r"||serial_data=="p"||serial_data=="g"||serial_data=="c"||serial_data=="t")settings_open<=0;
    if(serial_data>="0"&&serial_data<="7")begin user_mode<=serial_data-"0";diagnostic<=0;pure_o<=0;freeze_request<=0;end
    else case(serial_data)
     "m":begin user_mode<=user_mode+1'b1;diagnostic<=0;pure_o<=0;freeze_request<=0;end
     "+":begin delta=(2040-high<8)?2040-high:8;low<=low+delta;high<=high+delta;end
     "-":begin delta=(low-1<8)?low-1:8;low<=low-delta;high<=high-delta;end
     "r":begin user_mode<=0;low<=40;high<=80;selected<=0;step_select<=0;pure_o<=0;diagnostic<=0;detect_extra<=0;skin_lower<=10;freeze_request<=0;end
     "p":begin pure_o<=~pure_o;user_mode<=0;diagnostic<=0;end
     "f":detect_extra<=~detect_extra;
     "g":begin user_mode<=0;diagnostic<=1;diagnostic_mode<=5;pure_o<=0;end
     "c":begin user_mode<=0;diagnostic<=1;diagnostic_mode<=12;pure_o<=0;end
     "t":begin user_mode<=0;diagnostic<=1;diagnostic_mode<=8;pure_o<=0;end
     "[":if(skin_lower>5)skin_lower<=skin_lower-5;
     "]":if(skin_lower<85)skin_lower<=skin_lower+5;
    endcase
   end
  end
 end
endmodule
