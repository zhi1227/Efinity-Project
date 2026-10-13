`timescale 1ns/1ps
module tb_menu_cdc6;
 reg sc=0,dc=0,rst=1;reg [12:0] status=0;wire [12:0] observed;
 always #6.72043 sc=~sc;
 always #10.416667 dc=~dc;
 menu_status_cdc dut(sc,rst,status,dc,rst,observed);
 integer ids[0:5];integer i;
 reg [12:0] accepted=0;
 reg old_ack=0;
 always @(negedge dc) if(!rst) begin
   if(dut.acknowledge!=old_ack) begin
     if(observed!==dut.payload) $fatal(1,"CDC payload mismatch");
     case(observed[3:0]) 0,1,10,9,14,15: ;default:$fatal(1,"Torn mode word");endcase
   end
   old_ack=dut.acknowledge;
 end else old_ack=0;
 initial begin
   ids[0]=0;ids[1]=1;ids[2]=10;ids[3]=9;ids[4]=14;ids[5]=15;
   #200;rst=0;
   for(i=0;i<1000;i=i+1) begin
     @(negedge sc);status={i[7:0],i[0],ids[i%6][3:0]};
     repeat(i%7) @(negedge sc);
   end
   @(negedge sc);status=13'h1fdf;
   repeat(100) @(negedge dc);
   if(observed!==13'h1fdf) $fatal(1,"CDC did not converge to latest state");
   rst=1;#200;rst=0;status=0;repeat(100) @(negedge dc);
   if(observed!==13'd0) $fatal(1,"CDC reset/recovery failed");
   $display("PASS: CDC 1000 rapid changes, coherent payload, eventual state, reset recovery");$finish;
 end
endmodule
