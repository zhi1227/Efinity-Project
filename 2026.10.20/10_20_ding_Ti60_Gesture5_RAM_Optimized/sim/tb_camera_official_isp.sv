`timescale 1ns/1ps
// Compare every LUT entry to the untouched official ROM, then decode the
// real SCCB controller's serial output for all 252 camera writes.
module isp_serial_check #(parameter LENC=0)(output reg passed=0);
 reg clk=0,rst_n=0; always #5 clk=~clk;
 wire [7:0] index,size,reference_size;
 wire [23:0] data,reference_data;
 wire scl,sda,oe,done,ack;
 wire [15:0] read_data;
 I2C_OV5640_1280720_Config #(.LENC_ENABLE(LENC)) rom(index,data,size);
 official_OV5640_Config reference_rom(index,reference_data,reference_size);
 i2c_timing_ctrl_16bit #(.CLK_FREQ(100000),.I2C_FREQ(1000)) ctrl(
  .clk(clk),.rst_n(rst_n),.i2c_sclk(scl),.i2c_sdat_IN(1'b0),
  .i2c_sdat_OUT(sda),.i2c_sdat_OE(oe),.i2c_config_size(size),
  .i2c_config_index(index),.i2c_config_data({8'h78,data}),
  .i2c_config_done(done),.config_ack_ok(ack),.i2c_rdata(read_data));
 reg [31:0] serial_word=0;
 integer bits_seen=0,writes=0,lenc_writes=0,awb_writes=0;
 wire [23:0] expected=(index==59 && !LENC)?24'h500027:reference_data;
 always @(posedge scl) if(rst_n && (ctrl.current_state==2 ||
   ctrl.current_state==4 || ctrl.current_state==6 || ctrl.current_state==8)) begin
  if(!oe)$fatal(1,"SCCB data phase has no output enable");
  serial_word={serial_word[30:0],sda};bits_seen=bits_seen+1;
 end
 always @(posedge clk) if(rst_n && ctrl.config_stop) begin
  if(bits_seen!=32 || serial_word!=={8'h78,expected})
   $fatal(1,"LENC=%0d index=%0d bits=%0d wire=%h expected=%h",LENC,index,bits_seen,serial_word,{8'h78,expected});
  if(serial_word[23:8]==16'h5000)begin
   lenc_writes=lenc_writes+1;
   if(serial_word[7:0] !== (LENC?8'ha7:8'h27))$fatal(1,"Wrong ISP control byte");
  end
  if(serial_word[23:8]==16'h5001)begin
   awb_writes=awb_writes+1;
   if(serial_word[7:0]!==8'h83)$fatal(1,"AWB configuration changed");
  end
  writes=writes+1;bits_seen=0;serial_word=0;
 end
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  wait(done);#2;
  if(!ack || writes!=252 || lenc_writes!=1 || awb_writes!=1)
   $fatal(1,"Incomplete official ISP sequence LENC=%0d writes=%0d",LENC,writes);
  $display("PASS: LENC=%0d all 252 actual SCCB writes match official table except the selected LENC bit; AWB unchanged",LENC);
  passed=1;
 end
endmodule

module tb_camera_official_isp;
 reg [7:0] index=0;
 wire [23:0] off_data,on_data,default_data,reference_data;
 wire [7:0] off_size,on_size,default_size,reference_size;
 wire off_pass,on_pass;
 I2C_OV5640_1280720_Config #(.LENC_ENABLE(0)) off_rom(index,off_data,off_size);
 I2C_OV5640_1280720_Config #(.LENC_ENABLE(1)) on_rom(index,on_data,on_size);
 I2C_OV5640_1280720_Config default_rom(index,default_data,default_size);
 official_OV5640_Config reference_rom(index,reference_data,reference_size);
 isp_serial_check #(.LENC(0)) off_serial(off_pass);
 isp_serial_check #(.LENC(1)) on_serial(on_pass);
 integer i;
 initial begin
  for(i=0;i<256;i=i+1)begin
   index=i;#2;
   if(off_size!==8'd252 || on_size!==8'd252 || default_size!==8'd252 || reference_size!==8'd252)$fatal(1,"LUT length changed");
   if(on_data!==reference_data)$fatal(1,"Official LENC-on ROM differs index=%0d",i);
   if(off_data !== ((i==59)?24'h500027:reference_data))$fatal(1,"Unexpected LENC-off ROM change index=%0d",i);
   if(default_data!==off_data)$fatal(1,"Default is not LENC-off candidate");
  end
  $display("PASS: both 256-index ROM maps match independent official reference, including default output and size");
  wait(off_pass && on_pass);
  $display("PASS: official ISP camera comparison complete");$finish;
 end
 initial begin #20000000;$fatal(1,"Official ISP simulation timeout");end
endmodule
