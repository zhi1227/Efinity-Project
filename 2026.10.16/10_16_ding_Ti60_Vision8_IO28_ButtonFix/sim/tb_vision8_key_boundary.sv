`timescale 1ns/1ps
module tb_vision8_key_boundary;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,key_n=1;reg[3:0]context_i=0;
 // Four test clocks per millisecond preserve the 20ms/2000ms ratio.
 localparam MC=4,DB=20*MC,LC=2000*MC;
 wire short_o,long_o;integer shorts=0,longs=0,collisions=0;
 vision8_key #(.DEBOUNCE(DB),.LONG_CYCLES(LC)) dut(
  .clk(clk),.rst_n(rst_n),.key_n(key_n),.context_i(context_i),.short_o(short_o),.long_o(long_o));
 vision8_key defaults(.clk(clk),.rst_n(1'b0),.key_n(1'b1),.context_i(4'd0),.short_o(),.long_o());

 always @(posedge clk)begin
  // Observe the exact debounced release/long-threshold collision before NBA.
  if(rst_n&&dut.held&&dut.sync&&!dut.stable&&dut.deb==DB-1&&dut.duration==LC-1)
   collisions=collisions+1;
  #1;
  if(!rst_n)begin shorts=0;longs=0;collisions=0;end
  else begin
   if(short_o&&long_o)$fatal(1,"short and long overlap");
   if(short_o)shorts=shorts+1;
   if(long_o)longs=longs+1;
  end
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task expect_events(input integer s,input integer l);
  if(shorts!=s||longs!=l)$fatal(1,"events expected short=%0d long=%0d; got short=%0d long=%0d",s,l,shorts,longs);
 endtask
 task reset_with_level(input reg level);
  begin rst_n=0;key_n=level;context_i=0;cycles(5);rst_n=1;cycles(DB+15);end
 endtask
 task physical_press(input integer milliseconds);
  begin key_n=0;cycles(milliseconds*MC);key_n=1;cycles(DB+15);end
 endtask
 initial begin
  if(defaults.DEBOUNCE!=1488000||defaults.LONG_CYCLES!=148800000||$bits(defaults.duration)<28)
   $fatal(1,"74.4MHz production defaults or long counter width changed");

  // Released at startup: arm only after stable release, with no phantom event.
  reset_with_level(1);expect_events(0,0);
  if(!dut.armed||dut.held||dut.stable!==1)$fatal(1,"released startup did not arm safely");
  cycles(LC+DB);expect_events(0,0);
  repeat(10)begin key_n=0;cycles(2);key_n=1;cycles(2);end
  cycles(DB+15);expect_events(0,0);
  physical_press(500);expect_events(1,0);
  physical_press(1999);expect_events(2,0);
  physical_press(2000);expect_events(2,1);
  if(collisions!=1)$fatal(1,"exact release/long boundary not exercised: %0d",collisions);
  physical_press(5000);expect_events(2,2);
  cycles(LC);expect_events(2,2);

  // A short release bounce cannot terminate a hold or re-trigger its long event.
  key_n=0;cycles(2500*MC);expect_events(2,3);
  key_n=1;cycles(DB/2);key_n=0;cycles(DB+15);
  if(!dut.held)$fatal(1,"release bounce ended a valid hold");
  expect_events(2,3);
  key_n=1;cycles(DB+15);expect_events(2,3);

  // A held-at-startup input remains unarmed even past the long threshold.
  reset_with_level(0);cycles(LC+DB+20);expect_events(0,0);
  if(dut.armed||dut.held||dut.stable!==0)$fatal(1,"boot-held was armed");
  key_n=1;cycles(DB+15);expect_events(0,0);
  if(!dut.armed)$fatal(1,"first boot-held release did not arm");
  physical_press(500);expect_events(1,0);

  // Reset during a valid hold must cancel it and require release before rearming.
  key_n=0;cycles(DB+100);rst_n=0;cycles(5);rst_n=1;
  cycles(LC+DB+20);expect_events(0,0);
  if(dut.armed||dut.held)$fatal(1,"reset-held input escaped startup protection");
  key_n=1;cycles(DB+15);expect_events(0,0);
  physical_press(500);expect_events(1,0);

  // Changing away and back during a hold cancels both short and long actions.
  reset_with_level(1);
  key_n=0;cycles(DB+100);context_i=4'h1;cycles(10);context_i=4'h0;
  cycles(LC+20);expect_events(0,0);key_n=1;cycles(DB+15);expect_events(0,0);
  if(!dut.armed)$fatal(1,"cancelled long did not rearm on release");
  key_n=0;cycles(DB+100);context_i=4'h8;cycles(10);context_i=4'h0;
  key_n=1;cycles(DB+15);expect_events(0,0);
  physical_press(500);expect_events(1,0);
  physical_press(2000);expect_events(1,1);

  // Match a controller changing its context by NBA on the event-generation edge.
  // No force/release is used: the physical pin and real timer produce the event.
  reset_with_level(1);key_n=0;
  while(!(dut.held&&dut.duration==LC-1&&!dut.fired))cycles(1);
  @(posedge clk);context_i<=4'h1;
  #2;if(short_o||long_o)$fatal(1,"same-edge context change leaked pending long");
  @(negedge clk);cycles(10);expect_events(0,0);
  context_i=0;cycles(10);expect_events(0,0);
  key_n=1;cycles(DB+15);expect_events(0,0);

  // The same protection is required for a short registered on stable release.
  reset_with_level(1);key_n=0;cycles(500*MC);key_n=1;
  while(!(dut.held&&dut.sync&&!dut.stable&&dut.deb==DB-1))cycles(1);
  @(posedge clk);context_i<=4'h8;
  #2;if(short_o||long_o)$fatal(1,"same-edge context change leaked pending short");
  @(negedge clk);cycles(10);expect_events(0,0);
  context_i=0;cycles(DB+15);expect_events(0,0);
  physical_press(500);expect_events(1,0);

  $display("PASS: vision8_key 74.4MHz defaults, 20ms/2s scaled timing, 500/1999/2000/5000ms, exact release-long collision with long priority and mutual exclusion");
  $display("PASS: vision8_key released/held startup, reset while held, press/release bounce, one long per hold, no short after long, context away-and-back cancellation and rearm");
  $display("PASS: vision8_key same-edge NBA context changes mask pending short/long before a new context can consume them");
  $finish;
 end
 initial begin #5000000;$fatal(1,"key boundary timeout");end
endmodule
