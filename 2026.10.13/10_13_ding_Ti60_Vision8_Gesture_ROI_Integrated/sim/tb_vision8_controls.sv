`timescale 1ns/1ps
module tb_vision8_controls;
 reg clk=0,rst=0,fs=0;always #5 clk=~clk;
 reg[3:0]keys=4'b1110;reg busy=0,learning=0;
 wire[2:0]mode;wire[1:0]alg,sel,step;wire pip,held,cap,clear,gs,gl;
 wire[11:0]lo,hi,la,ha;wire[15:0]ver;wire[3:0]backend;
 integer captures=0,clears=0,longs=0;
 vision8_controls #(.DEBOUNCE(3),.LONG_CYCLES(24)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.io28(keys[0]),.io29(keys[1]),.k1_n(keys[2]),.k2_n(keys[3]),
 .capture_busy(busy),.learning(learning),.rx(1'b1),.user_mode(mode),.capture_alg(alg),.pip_enable(pip),.freeze_request(held),.capture(cap),.clear(clear),
 .gesture_short(gs),.gesture_long(gl),.low(lo),.high(hi),.selected(sel),.step_select(step),.low_active(la),.high_active(ha),.version(ver),.backend_mode(backend),.pure_o(),.detect_extra(),.skin_lower());
 always @(posedge clk)begin if(cap)captures=captures+1;if(clear)clears=clears+1;if(gl)longs=longs+1;end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task press(input integer k,input integer n);begin keys[k]=k==0;cycles(n);keys[k]=k!=0;cycles(12);end endtask
 task nextmode;press(0,10);endtask
 initial begin
  cycles(4);rst=1;cycles(15);if(mode!==0||lo!==40||hi!==80)$fatal(1,"reset state");
  cycles(60);if(mode!=0||held||captures||clears)$fatal(1,"released IO29 generated idle events");
  rst=0;keys[1]=0;cycles(4);rst=1;cycles(60);
  if(held||captures||clears)$fatal(1,"IO29 held during reset generated an action");
  keys[1]=1;cycles(12);if(held)$fatal(1,"IO29 boot-held release generated freeze");
  // IO29 idle=1, press=0: no false boot event, bounce or held-key repeat.
  if(held)$fatal(1,"IO29 idle high falsely froze frame");
  repeat(6)begin keys[1]=0;cycles(1);keys[1]=1;cycles(1);end cycles(12);
  if(held)$fatal(1,"IO29 bounce froze frame");
  keys[1]=0;cycles(10);if(held)$fatal(1,"IO29 short must fire on release");
  keys[1]=1;cycles(12);if(!held)$fatal(1,"IO29 active-low freeze");
  press(1,10);if(held)$fatal(1,"IO29 active-low resume");
  press(1,40);if(held)$fatal(1,"IO29 long release leaked short freeze");
  // Bouncing external mode key does not cause a switch.
  repeat(6)begin keys[0]=1;cycles(1);keys[0]=0;cycles(1);end cycles(12);if(mode!=0)$fatal(1,"bounce switched mode");
  nextmode();if(mode!=1||backend!=1)$fatal(1,"Canny mapping");
  press(0,40);if(!pip||mode!=1)$fatal(1,"long PiP repeated short");
  nextmode();if(mode!=2||backend!=10)$fatal(1,"red mapping");nextmode();if(mode!=3||backend!=9)$fatal(1,"cyber mapping");
  nextmode();if(mode!=4)$fatal(1,"compare mode");press(1,10);if(captures!=1)$fatal(1,"capture action");
  busy=1;press(1,10);if(captures!=1)$fatal(1,"queued busy capture");press(1,40);if(clears!=1)$fatal(1,"clear action");busy=0;
  press(3,10);if(alg!=1)$fatal(1,"context algorithm");nextmode();if(mode!=5||backend!=1)$fatal(1,"threshold mode");
  press(3,10);if(lo!=41||la!=40)$fatal(1,"pending threshold");fs=1;cycles(1);fs=0;cycles(1);if(la!=41||ver!=1)$fatal(1,"frame commit");
  press(2,10);if(sel!=1)$fatal(1,"HIGH selection");press(3,10);if(hi!=81)$fatal(1,"high increment");
  press(2,10);if(sel!=2)$fatal(1,"LINK selection");press(2,40);if(step!=1)$fatal(1,"step 4");
  press(3,10);if(lo!=45||hi!=85)$fatal(1,"linked change");
  repeat(550)press(3,10);if(hi!=2040||lo!=2000)$fatal(1,"upper saturation %d %d",lo,hi);
  repeat(550)press(1,10);if(lo!=1||hi!=41)$fatal(1,"lower saturation");
  press(2,10);if(sel!=0)$fatal(1,"LOW selection");repeat(30)press(3,10);if(lo!=40||hi!=41)$fatal(1,"LOW<HIGH clamp");
  // Hold a context key across a mode change: its release has no action.
  keys[3]=0;cycles(8);nextmode();keys[3]=1;cycles(15);if(mode!=6||lo!=40)$fatal(1,"context leaked");
  nextmode();if(mode!=7||backend!=15)$fatal(1,"gesture mapping");press(2,40);if(longs!=1)$fatal(1,"board K1 enrolment");
  learning=1;press(1,10);if(held)$fatal(1,"freeze during enrolment");learning=0;press(1,10);if(!held)$fatal(1,"gesture freeze");
  nextmode();if(mode!=0||held)$fatal(1,"mode wrap");
  $display("PASS: Vision8 unchanged IO28 mode/PiP, IO29 active-low freeze/resume/capture/clear/threshold, four keys, bounce, long suppression, context binding, frame threshold commits and all clamps");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
