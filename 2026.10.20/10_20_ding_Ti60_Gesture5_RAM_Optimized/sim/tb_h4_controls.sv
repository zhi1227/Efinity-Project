`timescale 1ns/1ps
module tb_h4_controls;
 reg clk=0,rst=0,key=0,on=1,frame=0,sd=0,so=0,cd=0,co=0;always #5 clk=~clk;
 wire sp,lp,busy,clear,ss;wire[2:0]learn,step,state;wire[1:0]err;wire[7:0]count;
 gesture_key #(.DEBOUNCE(3),.LONG_CYCLES(20)) k(clk,rst,key,sp,lp);
 gesture_wizard #(.COUNTDOWN_FRAMES(3),.SETTLE_FRAMES(2),.TIMEOUT_FRAMES(8)) w(clk,rst,on,frame,sp,lp,sd,so,cd,co,2'd2,busy,clear,ss,learn,step,state,err,count);
 integer shorts=0,longs=0;
 always @(posedge clk)begin if(sp)shorts=shorts+1;if(lp)longs=longs+1;end
 task tick(input integer n);repeat(n)@(negedge clk);endtask
 task press;begin key=0;tick(10);key=1;tick(10);end endtask
 task hold;begin key=0;tick(40);key=1;tick(10);end endtask
 task ft;begin frame=1;tick(1);frame=0;tick(2);end endtask
 initial begin
  tick(3);rst=1;tick(50);if(shorts||longs)$fatal(1,"Boot held key fired");key=1;tick(10);
  key=0;tick(1);key=1;tick(5);if(shorts||longs)$fatal(1,"Bounce fired");
  hold();if(shorts||longs!=1||!busy||step!=1||state!=1)$fatal(1,"Long action");
  press();if(shorts!=1||state!=2)$fatal(1,"Short confirm");ft();ft();ft();
  if(state!=3)$fatal(1,"Colour wait");sd=1;so=0;tick(1);sd=0;tick(2);if(state!=6||err!=1)$fatal(1,"Invalid colour not rejected");
  press();ft();ft();ft();sd=1;so=1;tick(1);sd=0;tick(2);ft();ft();if(state!=5)$fatal(1,"Capture state");
  cd=1;co=1;tick(1);cd=0;tick(2);if(step!=2||state!=1)$fatal(1,"Next step");
  press();ft();ft();ft();ft();ft();cd=1;co=0;tick(1);cd=0;tick(2);if(state!=6||err!=2)$fatal(1,"Similar model error");
  press();ft();ft();ft();ft();ft();cd=1;co=1;tick(1);cd=0;tick(2);if(step!=3)$fatal(1,"Heart step");
  press();ft();ft();ft();ft();ft();cd=1;co=1;tick(1);cd=0;tick(2);if(busy||state)$fatal(1,"Wizard finish");
  hold();on=0;tick(2);if(busy)$fatal(1,"Mode exit did not cancel");
  on=1;hold();press();ft();ft();ft();repeat(8)ft();if(state!=6)$fatal(1,"Missing camera timeout");
  $display("PASS: K2 debounce, boot-held suppression, short/long exclusivity, three steps, colour failure, ambiguity, timeout and cancellation");$finish;
 end
endmodule
