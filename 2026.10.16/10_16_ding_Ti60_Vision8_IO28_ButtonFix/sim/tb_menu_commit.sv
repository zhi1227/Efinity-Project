`timescale 1ns/1ps
module tb_menu_commit;
 reg clk=0,rst_n=0,vs=0;reg [3:0] mode=3;reg frozen=0;
 always #6.72043 clk=~clk;
 wire [23:0] rgb;wire de,vo,hs,overrun;wire [3:0] committed;wire hold_committed;
 parallel_video #(.WIDTH(64),.HEIGHT(48),.H_TOTAL(80),.HUD_ENABLE(1),.CANNY_GAUSSIAN(1)) dut(
  .clk(clk),.rst_n(rst_n),.rgb_i(24'd0),.de_i(1'b0),.vs_i(vs),.hs_i(1'b1),
  .mode_i(mode),.low_i(12'd40),.high_i(12'd80),.rgb_o(rgb),.de_o(de),.vs_o(vo),.hs_o(hs),
  .overrun(overrun),.freeze_i(frozen),.mode_committed_o(committed),.frozen_committed_o(hold_committed));
 integer ids[0:5];integer i;reg [3:0] old_mode;reg old_hold;
 initial begin
   ids[0]=0;ids[1]=1;ids[2]=3;ids[3]=5;ids[4]=10;ids[5]=12;
   repeat(10) @(negedge clk);rst_n=1;repeat(500) @(negedge clk);
   old_mode=3;old_hold=0;
   for(i=0;i<6;i=i+1) begin
     mode=ids[i];frozen=i[0];repeat(40) @(negedge clk);
     if(committed!=old_mode || hold_committed!=old_hold) $fatal(1,"HDMI status applied before frame boundary");
     vs=1;repeat(500) @(negedge clk);
     if(committed!=mode || hold_committed!=frozen) $fatal(1,"HDMI committed output did not update");
     old_mode=mode;old_hold=frozen;vs=0;repeat(500) @(negedge clk);
   end
   $display("PASS: real HDMI pipeline exports six frame-committed modes and freeze status");$finish;
 end
endmodule
