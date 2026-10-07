`timescale 1ns/1ps
module tb_i2c6;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 wire scl,sdo,oe,done,ack;wire[7:0]idx;wire[15:0]rdata;
 wire[31:0]word=idx==0?32'h78300882:32'h78310303;
 reg sdi=0;
 i2c_timing_ctrl_16bit #(.CLK_FREQ(100000),.I2C_FREQ(1000)) dut(
 .clk(clk),.rst_n(rst_n),.i2c_sclk(scl),.i2c_sdat_IN(sdi),.i2c_sdat_OUT(sdo),.i2c_sdat_OE(oe),
 .i2c_config_size(8'd2),.i2c_config_index(idx),.i2c_config_data(word),.i2c_config_done(done),.i2c_rdata(rdata),.config_ack_ok(ack));
 integer phase=0,n=0,reset_written=-1,second_start=-1,cycles=0;
 always @(posedge clk)cycles=cycles+1;
 always @(negedge clk)begin
   // First transaction NACKs; the retry ACKs all three significant bytes.
   sdi=(phase==0&&dut.retries==0&&idx==0)||(phase==1);
   if(dut.config_stop&&dut.config_step&&idx==0)reset_written=cycles;
   if(idx==1&&dut.current_state==1&&second_start<0)second_start=cycles;
 end
 initial begin
  repeat(5)@(posedge clk);#1;rst_n=1;
  wait(done);#1;
  if(!ack)$fatal(1,"Recovered NACK should complete with ACK status");
  if(second_start-reset_written<1000)$fatal(1,"Missing soft reset wait");
  $display("PASS: SCCB retries and 10 ms software-reset settling");
  rst_n=0;phase=1;repeat(4)@(posedge clk);#1;rst_n=1;
  wait(done);#1;if(ack)$fatal(1,"Missing camera falsely ACKed");
  $display("PASS: absent camera produces failed ACK status without hanging configuration");$finish;
 end
 initial begin #10000000;$fatal(1,"SCCB timeout");end
endmodule
