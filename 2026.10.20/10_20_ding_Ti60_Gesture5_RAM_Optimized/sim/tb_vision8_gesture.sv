`timescale 1ns/1ps
module tb_vision8_gesture;
 reg clk=0,rst=0,en=1,mode=1,fs=0,de=0,vs=1,short_key=0,long_key=0;
 reg[31:0]id=1;reg result_pulse=0,class_pulse=0;always #5 clk=~clk;
 wire[2:0]gesture,step,state;wire learning;
 gesture_branch #(.SOURCE_TAGGED(1),.CLOCK_HZ(1600),.WIDTH(128),.HEIGHT(96),.H_TOTAL(160))dut(
 .clk(clk),.rst_n(rst),.enable(en),.rgb(24'hb88b6c),.de(de),.vs(vs),.hs(1'b1),.fs(fs),.x(11'd0),.y(10'd0),.skin_lower(8'd10),
 .box_valid(),.box(),.gesture(gesture),.overflow(),.skin_raw(),.skin_valid(),.debug_raw(),.debug_clean(),.debug_fill(),.debug_ratio(),.debug_reject(),.debug_fault(),.debug_class(),
 .key_short(short_key),.key_long(long_key),.mode_on(mode),.learn_busy(learning),.learn_step(step),.learn_state(state),.learn_error(),.trained(),.learn_countdown(),.preview(),.preview_valid(),.wave_phase(),.source_id_i(id));
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task observe(input integer source);
 begin id=source;de=1;cycles(1);de=0;cycles(3);result_pulse=1;cycles(1);result_pulse=0;cycles(3);class_pulse=1;cycles(1);class_pulse=0;cycles(4);end
 endtask
 integer started,elapsed;
 initial begin
  // Inject committed CCL/classifier observations to isolate the ID/temporal gate.
  force dut.done=result_pulse;force dut.classified=class_pulse;
  force dut.raw_valid=1;force dut.raw_box={10'd80,10'd20,11'd100,11'd20};
  force dut.feature_matches=1;force dut.overflow=0;force dut.debug_class=2;
  cycles(5);rst=1;cycles(5);
  observe(1);repeat(20)observe(1);if(gesture!=0)$fatal(1,"replayed source confirmed gesture");
  observe(2);observe(3);observe(4);if(gesture!=0)$fatal(1,"four unique observations confirmed gesture");
  observe(5);if(gesture!=2)$fatal(1,"five distinct sources did not confirm thumb");
  long_key=1;cycles(1);long_key=0;cycles(3);if(!learning||step!=1||state!=1)$fatal(1,"K1 enrolment start");
  short_key=1;cycles(1);short_key=0;cycles(2);if(state!=2)$fatal(1,"K1 confirm");
  started=$time;wait(state==3);elapsed=($time-started)/10;
  if(elapsed<3080||elapsed>3220)$fatal(1,"countdown used replay frame ticks instead of elapsed clocks %d",elapsed);
  // There are no camera frame starts above. Timeout still runs and rejects capture.
  wait(state==6);if(!learning)$fatal(1,"timeout stopped wizard");
  mode=0;cycles(2);if(learning||state!=0)$fatal(1,"mode exit failed to cancel enrolment");
  $display("PASS: gesture publication gate accepts five distinct camera IDs and rejects replay votes; K1 enrolment uses elapsed-clock countdown/timeout and exits with mode change");$finish;
 end
 initial begin #500000;$fatal(1,"gesture timeout");end
endmodule
