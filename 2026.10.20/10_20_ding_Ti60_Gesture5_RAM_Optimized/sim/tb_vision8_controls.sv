`timescale 1ns/1ps
module tb_vision8_controls;
 reg clk=0,rst=0,fs=0;always #5 clk=~clk;
 reg[3:0]keys=4'b1111;reg io35=0;reg busy=0,learning=0;
 wire[2:0]mode;wire[1:0]alg,sel,step;wire settings,pip,held,cap,clear,gs,gl;
 wire[11:0]lo,hi,la,ha;wire[15:0]ver;wire[3:0]backend;
 integer captures=0,clears=0,longs=0,pip_changes=0;reg previous_pip=0;
 vision8_controls #(.DEBOUNCE(3),.LONG_CYCLES(24)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.io35(io35),.io28(keys[0]),.io29(keys[1]),.k1_n(keys[2]),.k2_n(keys[3]),
 .capture_busy(busy),.learning(learning),.rx(1'b1),.settings_open(settings),.user_mode(mode),.capture_alg(alg),.pip_enable(pip),.freeze_request(held),.capture(cap),.clear(clear),
 .gesture_short(gs),.gesture_long(gl),.low(lo),.high(hi),.selected(sel),.step_select(step),.low_active(la),.high_active(ha),.version(ver),.backend_mode(backend),.pure_o(),.detect_extra(),.skin_lower());
 always @(posedge clk)begin if(cap)captures=captures+1;if(clear)clears=clears+1;if(gl)longs=longs+1;end
 always @(posedge clk)begin
  #1;
  if(!rst)begin pip_changes=0;previous_pip=0;end
  else begin
   if(pip!==previous_pip)pip_changes=pip_changes+1;
   previous_pip=pip;
   if(|(dut.s&dut.l)||(dut.threshold_short&&dut.threshold_long))$fatal(1,"short and long events overlapped");
  end
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 // IO28, IO29, K1 and K2 are low-active; IO35 remains high-active.
 task press(input integer k,input integer n);begin keys[k]=0;cycles(n);keys[k]=1;cycles(12);end endtask
 task nextmode;press(0,10);endtask
 task pip_long_once;
  reg before_pip;integer before_changes,before_mode;
  begin
   before_pip=pip;before_changes=pip_changes;before_mode=mode;
   keys[0]=0;cycles(40);
   if(pip!==!before_pip||mode!=before_mode)$fatal(1,"PiP long did not toggle in supported mode %0d",before_mode);
   // LONG_CYCLES=24 represents 2s; 60 held clocks represent 5s.
   cycles(20);
   if(pip!==!before_pip||pip_changes!=before_changes+1||mode!=before_mode)$fatal(1,"5s PiP hold repeated or switched mode");
   keys[0]=1;cycles(12);
   if(pip!==!before_pip||pip_changes!=before_changes+1||mode!=before_mode)$fatal(1,"long release leaked a short mode switch");
  end
 endtask
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
  repeat(6)begin keys[0]=0;cycles(1);keys[0]=1;cycles(1);end cycles(12);if(mode!=0)$fatal(1,"bounce switched mode");
  press(0,60);if(mode!=0||pip)$fatal(1,"RAW mode accepted PiP or leaked short");
  nextmode();if(mode!=1||backend!=1)$fatal(1,"Canny mapping");
  pip_long_once();pip_long_once();if(pip)$fatal(1,"Canny PiP did not close");
  nextmode();if(mode!=2||backend!=10)$fatal(1,"red mapping");pip_long_once();pip_long_once();
  nextmode();if(mode!=3||backend!=9)$fatal(1,"cyber mapping");pip_long_once();pip_long_once();
  nextmode();if(mode!=4||backend!=14)$fatal(1,"mode 5 color/edge comparison mapping");
  press(1,10);if(!held||captures)$fatal(1,"color/edge comparison must freeze, not capture");
  nextmode();if(mode!=5||backend!=15||held)$fatal(1,"mode 6 gesture mapping");
  press(2,40);if(longs!=1)$fatal(1,"mode 6 K1 enrolment");
  learning=1;press(1,10);if(held)$fatal(1,"freeze during enrolment");learning=0;press(1,10);if(!held)$fatal(1,"gesture freeze");
  nextmode();if(mode!=6||backend!=0||held)$fatal(1,"mode 7 face mapping");
  nextmode();if(mode!=7)$fatal(1,"mode 8 four-frame comparison");press(1,10);if(captures!=1)$fatal(1,"mode 8 capture action");
  busy=1;press(1,10);if(captures!=1)$fatal(1,"queued busy capture");press(1,40);if(clears!=1)$fatal(1,"clear action");busy=0;
  press(3,10);if(alg!=1||backend!=1)$fatal(1,"four-frame algorithm selection");
  nextmode();if(mode!=0||held||settings)$fatal(1,"eight-mode wrap");
  // IO35 opens a distinct page without changing the processing mode or freeze.
  repeat(6)begin io35=1;cycles(1);io35=0;cycles(1);end cycles(12);
  if(settings)$fatal(1,"IO35 bounce switched page");
  press(1,10);if(!held)$fatal(1,"freeze before settings");
  io35=1;cycles(10);if(settings)$fatal(1,"IO35 must fire on release");
  io35=0;cycles(12);if(!settings||mode!=0||backend!=0||!held)$fatal(1,"independent settings entry preserves algorithm/freeze");
  press(3,10);if(lo!=41||la!=40)$fatal(1,"pending threshold");fs=1;cycles(1);fs=0;cycles(1);if(la!=41||ver!=1)$fatal(1,"frame commit");
  press(2,10);if(sel!=1)$fatal(1,"HIGH selection");press(3,10);if(hi!=81)$fatal(1,"high increment");
  press(2,10);if(sel!=2)$fatal(1,"LINK selection");press(2,40);if(step!=1)$fatal(1,"step 4");
  press(3,10);if(lo!=45||hi!=85)$fatal(1,"linked change");
  repeat(550)press(3,10);if(hi!=2040||lo!=2000)$fatal(1,"upper saturation %d %d",lo,hi);
  repeat(550)press(1,10);if(lo!=1||hi!=41)$fatal(1,"lower saturation");
  press(2,10);if(sel!=0)$fatal(1,"LOW selection");repeat(30)press(3,10);if(lo!=40||hi!=41)$fatal(1,"LOW<HIGH clamp");
  // A held key is cancelled across page changes, even though mode is unchanged.
  keys[2]=0;cycles(8);io35=1;cycles(10);io35=0;cycles(12);keys[2]=1;cycles(15);
  if(settings||mode!=0||sel!=0||step!=1||!held)$fatal(1,"page context leaked K1 action");
  io35=1;cycles(40);io35=0;cycles(12);if(settings)$fatal(1,"IO35 long release leaked short");
  // Every algorithm can open/close settings; no ninth mode or lost selection.
  for(integer m=0;m<8;m=m+1)begin
   if(m==0||m>=4)begin
    press(0,60);if(mode!=m||pip)$fatal(1,"unsupported mode %0d accepted PiP",m);
   end
   io35=1;cycles(10);io35=0;cycles(12);
   if(!settings||mode!=m)$fatal(1,"settings changed user mode %0d",m);
   if(m==1&&backend!=1||m==4&&backend!=14||m==5&&backend!=15)$fatal(1,"settings changed algorithm");
   press(0,60);if(!settings||mode!=m||pip)$fatal(1,"settings page accepted PiP or mode switch");
   press(2,10);if(gs||gl||captures!=1||clears!=1)$fatal(1,"settings key leaked to algorithm");
   io35=1;cycles(10);io35=0;cycles(12);if(settings||mode!=m)$fatal(1,"settings return");
   nextmode();
  end
  // A mode press exits settings, advances once, and invalidates held page keys.
  io35=1;cycles(10);io35=0;cycles(12);
  keys[3]=0;cycles(8);nextmode();keys[3]=1;cycles(15);
  if(mode!=1||settings||lo!=40||hi!=41)$fatal(1,"mode/page transition leaked threshold edit");
  io35=1;cycles(8);nextmode();io35=0;cycles(12);if(mode!=2||settings)$fatal(1,"IO35 held context leaked");
  rst=0;keys[0]=0;cycles(4);rst=1;cycles(60);
  if(mode!=0||pip||settings)$fatal(1,"IO28 boot-held generated action");
  keys[0]=1;cycles(12);if(mode!=0||pip)$fatal(1,"IO28 boot-held release generated action");
  nextmode();if(mode!=1)$fatal(1,"IO28 did not rearm after boot-held release");
  rst=0;io35=1;cycles(4);rst=1;cycles(60);io35=0;cycles(12);
  if(mode!=0||settings)$fatal(1,"IO35 boot-held release triggered entry");

  // Close settings on the edge that generates IO28's real long event. The
  // pending event belongs to the old settings context and must not enable PiP.
  nextmode();if(mode!=1||pip)$fatal(1,"same-edge page test setup mode");
  io35=1;cycles(10);io35=0;cycles(12);
  if(!settings)$fatal(1,"same-edge page test setup settings");
  keys[0]=0;cycles(12);io35=1;cycles(11);io35=0;
  while(!dut.threshold_short)cycles(1);
  if(!settings||!dut.a.held||dut.a.duration!=23||dut.a.fired||dut.l[0])
   $fatal(1,"page close and long-generation edges were not aligned");
  @(posedge clk);#2;
  if(settings||pip||dut.l[0])$fatal(1,"page close leaked old-context pending PiP long");
  @(negedge clk);cycles(4);
  if(pip||mode!=1)$fatal(1,"new page consumed old-context PiP event");
  keys[0]=1;cycles(12);
  if(pip||mode!=1)$fatal(1,"cancelled long release changed PiP or mode");
  pip_long_once();pip_long_once();
  $display("PASS: IO35 active-high shortcut, independent page for all eight algorithms, no mode/freeze loss, page context cancellation, boot/bounce/long suppression");
  $display("PASS: IO28 active-low, modes 2/3/4 PiP on/off, 5s holds toggle once, unsupported/settings gating, startup-held and no short after long");
  $display("PASS: IO35 settings close coincident with IO28 long generation masks pending PiP event; fresh later presses still work");
  $display("PASS: Vision8 requested 1 RAW / 2 Canny / 3 RED / 4 CYBER / 5 SPLIT / 6 GESTURE / 7 FACE / 8 FOUR-FRAME mapping, frame threshold commits and all clamps");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
