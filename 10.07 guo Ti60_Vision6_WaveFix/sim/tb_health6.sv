`timescale 1ns/1ps
module tb_health6;
 reg sc=0,cc=0,pc=0,rst=0;always #5 sc=~sc;always #7 cc=~cc;always #6 pc=~pc;
 reg vs=0,de=0,pde=0;reg[23:0]rgb=0;reg cfg=0,ack=0,cd=0,cp=0,bufready=0;wire retry;wire[7:0]health;
 camera_health #(.SYS_HZ(10000),.FRAME_BYTES(64),.RGB_TIMEOUT(37),.RGB_MAX(50))dut(
 .sys_clk(sc),.sys_rst_n(rst),.cam_clk(cc),.cam_vs(vs),.cam_de(de),.cam_data(8'h50),
 .cfg_done(cfg),.cfg_ack(ack),.cal_done(cd),.cal_pass(cp),.buffer_ready(bufready),
 .pixel_clk(pc),.pixel_rst_n(rst),.pixel_de(pde),.pixel_rgb(rgb),.retry_config(retry),.health(health));
 integer retries=0,j;always @(posedge sc)if(retry)retries=retries+1;
 task camframe;begin
  @(negedge cc);vs=1;repeat(3)@(negedge cc);de=1;repeat(64)@(negedge cc);de=0;
  repeat(3)@(negedge cc);vs=0;repeat(20)@(negedge cc);
 end endtask
 initial begin
  repeat(5)@(negedge sc);rst=1;cfg=1;ack=1;cd=1;cp=1;bufready=1;pde=1;rgb=24'hF80000;
  for(j=0;j<20;j=j+1)camframe();repeat(20)@(negedge pc);
  if(health!==8'hFF)$fatal(1,"Healthy path not all green: %h",health);
  pde=0;rgb=0;repeat(80)@(negedge pc);
  if(health[7])$fatal(1,"RGB watchdog stale");
  repeat(32000)@(negedge sc);
  if(health[3]||health[6]||!health[2])$fatal(1,"VS/BUF stale or clock detection wrong: %h",health);
  if(retries<1)$fatal(1,"No automatic camera reconfiguration after missing frames");
  $display("PASS: diagnostic activity, complete frame, RGB expiration and automatic missing-camera retry");$finish;
 end
endmodule
