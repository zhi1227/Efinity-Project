`timescale 1ns/1ps
module tb_threshold_controls;
 reg clk=0,rst=0,rx=1,k1=0,k2=0;always #5 clk=~clk;
 wire[3:0]mode;wire[11:0]low,high;wire pure_en,detect,editing,sel,sp,lp;wire[7:0]skin;
 uart_params #(.CLKS_PER_BIT(16),.KEY_DEBOUNCE_CYCLES(3),.KEY_LONG_CYCLES(24)) dut(
  clk,rst,rx,mode,low,high,k1,pure_en,detect,skin,k2,editing,sel,sp,lp);
 integer shorts=0,longs=0,i,saved;integer ids[0:8];reg[7:0]commands[0:8];
 always @(posedge clk)if(rst)begin
  if(sp)shorts=shorts+1;if(lp)longs=longs+1;
  if(low<1||low>=high||high>4095)$fatal(1,"Invalid threshold range: %0d %0d",low,high);
  if(editing&&(sp||lp))$fatal(1,"Editor leaked freeze/gesture key");
 end
 task tick(input integer n);repeat(n)@(negedge clk);endtask
 task press(input integer key,input integer duration);
  begin if(key==1)k1=0;else k2=0;tick(duration);if(key==1)k1=1;else k2=1;tick(12);end
 endtask
 task send(input[7:0]b);integer n;begin
  rx=0;tick(16);for(n=0;n<8;n=n+1)begin rx=b[n];tick(16);end rx=1;tick(32);
 end endtask
 initial begin
  tick(4);rst=1;tick(70);if(editing||mode||shorts||longs)$fatal(1,"Boot held key action");
  k1=1;k2=1;tick(12);
  k1=0;tick(1);k1=1;tick(12);if(mode||editing)$fatal(1,"Bounce action");
  ids[0]=0;ids[1]=1;ids[2]=10;ids[3]=9;ids[4]=14;ids[5]=15;ids[6]=5;ids[7]=12;ids[8]=8;
  commands[0]="0";commands[1]="1";commands[2]="2";commands[3]="3";commands[4]="4";commands[5]="5";
  commands[6]="g";commands[7]="c";commands[8]="t";
  for(i=0;i<9;i=i+1)begin
   send("r");send(commands[i]);press(1,70);
   if(!editing||mode!=ids[i]||sel)$fatal(1,"Cannot enter from mode %0d",ids[i]);
   press(1,10);if(low!=32||high!=80||mode!=ids[i])$fatal(1,"Low decrement");
   press(2,10);if(low!=40||high!=80)$fatal(1,"Low increment");
   press(2,70);if(!sel||high!=80||low!=40)$fatal(1,"Select produced short action");
   press(2,10);if(high!=88||low!=40)$fatal(1,"High increment");
   press(1,10);if(high!=80||low!=40)$fatal(1,"High decrement");
   press(1,70);if(editing||mode!=ids[i]||low!=40||high!=80)$fatal(1,"Exit/release changed mode or values");
  end
  send("p");press(1,40);if(!pure_en||!editing)$fatal(1,"Pure capture editor entry");press(1,40);
  press(2,10);press(2,40);if(shorts!=1||longs!=1)$fatal(1,"Normal K2 routing");
  // Entry and exit while K2 is held must not replay its release in a different context.
  press(1,40);k1=0;tick(20);k2=0;tick(12);k1=1;tick(8);k2=1;tick(12);
  if(editing||shorts!=1||longs!=1)$fatal(1,"Cross-context K2 release leaked");
  send("r");press(1,40);
  repeat(10)press(1,10);if(low!=1)$fatal(1,"Low underflow");
  repeat(20)press(2,10);if(low!=79||high!=80)$fatal(1,"Low crossed high");
  press(2,40);repeat(20)press(1,10);if(high!=80)$fatal(1,"High crossed low");
  repeat(520)press(2,10);if(high!=4095)$fatal(1,"High overflow");
  press(2,40);repeat(520)press(2,10);if(low!=4094)$fatal(1,"Low overflow");
  send("+");if(low!=4094||high!=4095)$fatal(1,"UART + overflow");
  repeat(520)send("-");if(low!=1||high!=2)$fatal(1,"UART - underflow/order");
  send("r");if(editing||low!=40||high!=80||mode)$fatal(1,"Reset defaults");
  press(1,10);if(mode!=1)$fatal(1,"Normal K1 cycle");
  $display("PASS: editor in all nine modes and pure capture; independent values; debounce; long/short exclusivity; K2 routing; context ownership; saturation and UART bounds");$finish;
 end
 initial begin #10000000;$fatal(1,"Timeout");end
endmodule
