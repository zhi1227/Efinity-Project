`timescale 1ns/1ps
module tb_freeze;
 reg clk=0;always #5 clk=~clk;
 reg pixel_clk=0;always #7 pixel_clk=~pixel_clk;
 reg reset=1,key_n=0,wr=0,rd=0,request=0;
 wire pulse,frozen,have_frame;wire [1:0] ws,rs;
 button_press #(.CYCLES(4)) key(pixel_clk,!reset,key_n,pulse);
 always @(posedge pixel_clk or posedge reset)
 if(reset)request<=0;else if(pulse)request<=~request;
 frame_buffer_select dut(clk,reset,wr,rd,request,ws,rs,frozen,have_frame);
 integer content[0:3];integer serial=0,completed=-1,hold_value=-1,cycles=0,i;
 reg [1:0] old_rs;reg old_frozen;
 always @(posedge clk) begin
 old_rs=rs;old_frozen=frozen;
 if(!reset && wr)begin serial=serial+1;content[ws]=serial;completed=ws;end
 #1;
 if(!reset)begin
   cycles=cycles+1;
   if(ws===rs)$fatal(1,"writer collided with display slot");
   if(!rd && rs!==old_rs)$fatal(1,"read pointer changed midframe");
   if(frozen && !old_frozen)hold_value=content[rs];
   if(frozen && content[rs]!==hold_value)$fatal(1,"frozen DDR content overwritten");
   if(rd && !frozen && have_frame && rs!==completed[1:0])$fatal(1,"did not select latest completed frame");
 end
 end
 task tick;begin @(negedge clk);end endtask
 task commit;input w,r;begin wr=w;rd=r;tick;wr=0;rd=0;tick;end endtask
 task press;begin
   key_n=1;repeat(14)@(negedge pixel_clk);
   key_n=0;repeat(14)@(negedge pixel_clk);
 end endtask
 initial begin
 for(i=0;i<4;i=i+1)content[i]=-1;
 repeat(5)tick;reset=0;repeat(30)tick;
 if(request)$fatal(1,"boot-held key toggled");
 // Freeze request before first captured image must not pin startup garbage.
 press;repeat(10)tick;commit(0,1);
 if(frozen)$fatal(1,"froze uninitialized frame");
 commit(1,1);commit(0,1);if(!frozen)$fatal(1,"freeze after first complete frame failed");
 for(i=0;i<60;i=i+1)commit(1,(i%3)==0);
 repeat(20)tick;if(!request)$fatal(1,"held key repeated");
 // Release bounce shorter than debounce cannot arm a second press.
 repeat(3)begin key_n=1;@(negedge pixel_clk);key_n=0;@(negedge pixel_clk);end
 repeat(12)@(negedge pixel_clk);if(!request)$fatal(1,"release bounce");
 press;repeat(10)tick;
 if(!frozen)$fatal(1,"unfroze before read boundary");
 commit(1,1);if(frozen)$fatal(1,"resume failed");
 // Simultaneous complete/read then read-only verifies latest register update.
 commit(1,1);commit(0,1);
 for(i=0;i<2000;i=i+1)begin
   wr=($random&3)==0;rd=($random&7)==0;tick;
 end
 wr=0;rd=0;press;repeat(10)tick;commit(0,1);
 for(i=0;i<100;i=i+1)commit(1,1);
 reset=1;repeat(5)tick;if(frozen || request || have_frame)$fatal(1,"reset failed");
 $display("PASS freeze: async K2 debounce/hold/boot, %0d cycles, startup, simultaneous events, latest frame, no slot collision/overwrite, resume/reset",cycles);
 $finish;
 end
 initial begin #200000;$fatal(1,"freeze timeout");end
endmodule
