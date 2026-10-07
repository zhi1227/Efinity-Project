`timescale 1ns/1ps
module tb_menu_cdc;
 reg sc=0,dc=0,rst=1;reg [4:0] status=3;wire [4:0] observed;
 always #6.72043 sc=~sc;
 always #10.416667 dc=~dc;
 menu_status_cdc dut(sc,rst,status,dc,rst,observed);
 integer ids[0:5];integer i;
 reg [4:0] accepted=3;
 reg old_ack=0;
 always @(negedge dc) if(!rst) begin
   if(dut.acknowledge!=old_ack) begin
     if(observed!==dut.payload) $fatal(1,"CDC payload mismatch");
     case(observed[3:0]) 0,1,3,5,10,12: ;default:$fatal(1,"Torn mode word");endcase
   end
   old_ack=dut.acknowledge;
 end else old_ack=0;
 initial begin
   ids[0]=0;ids[1]=1;ids[2]=3;ids[3]=5;ids[4]=10;ids[5]=12;
   #200;rst=0;
   for(i=0;i<1000;i=i+1) begin
     @(negedge sc);status={i[0],ids[i%6][3:0]};
     repeat(i%7) @(negedge sc);
   end
   @(negedge sc);status=5'h1c;
   repeat(100) @(negedge dc);
   if(observed!==5'h1c) $fatal(1,"CDC did not converge to latest state");
   rst=1;#200;rst=0;status=3;repeat(100) @(negedge dc);
   if(observed!==5'd3) $fatal(1,"CDC reset/recovery failed");
   $display("PASS: CDC 1000 rapid changes, coherent payload, eventual state, reset recovery");$finish;
 end
endmodule
