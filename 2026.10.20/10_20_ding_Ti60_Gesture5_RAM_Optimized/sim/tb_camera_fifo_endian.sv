`timescale 1ns/1ps
// The generated .sv FIFOs are compiled directly, without behavioural substitutes.
module tb_camera_fifo_endian;
 localparam WORDS=64, PIXELS=WORDS*8;
 reg camera_clk=0,axi_clk=0,pixel_clk=0;
 always #7 camera_clk=~camera_clk;
 always #5 axi_clk=~axi_clk;
 always #6 pixel_clk=~pixel_clk;
 reg reset=1,camera_we=0,camera_re=0,pixel_we=0,pixel_re=0;
 reg[7:0]camera_byte=0;
 reg[127:0]memory_word=0;
 wire[127:0]packed_word;
 wire[15:0]pixel;
 wire camera_empty,camera_valid,camera_busy,camera_underflow,camera_overflow;
 wire pixel_empty,pixel_valid,pixel_busy,pixel_underflow,pixel_overflow;
 W0_FIFO_8 camera_fifo(.wr_clk_i(camera_clk),.rd_clk_i(axi_clk),
  .wr_en_i(camera_we),.rd_en_i(camera_re),.wdata(camera_byte),.a_rst_i(reset),
  .rdata(packed_word),.empty_o(camera_empty),.rd_valid_o(camera_valid),
  .rst_busy(camera_busy),.underflow_o(camera_underflow),.overflow_o(camera_overflow));
 R0_FIFO_16 pixel_fifo(.wr_clk_i(axi_clk),.rd_clk_i(pixel_clk),
  .wr_en_i(pixel_we),.rd_en_i(pixel_re),.wdata(memory_word),.a_rst_i(reset),
  .rdata(pixel),.empty_o(pixel_empty),.rd_valid_o(pixel_valid),
  .rst_busy(pixel_busy),.underflow_o(pixel_underflow),.overflow_o(pixel_overflow));
 reg[127:0]memory[0:WORDS-1];
 integer i,j,waits;
 reg[127:0]expected_word;
 function[15:0]colour(input integer n);
  begin case(n%8)
   0:colour=16'hf800;1:colour=16'h07e0;2:colour=16'h001f;
   3:colour=16'hffff;4:colour=16'h0000;5:colour=16'ha55a;
   6:colour=16'h1234;default:colour=16'hcdef;
  endcase end
 endfunction
 task send_pixel(input integer index);
  reg[15:0]value;
  begin
   value=colour(index);
   @(negedge camera_clk);camera_we=1;camera_byte=value[15:8];
   @(negedge camera_clk);camera_byte=value[7:0];
   @(negedge camera_clk);camera_we=0;
  end
 endtask
 initial begin
  repeat(20)@(negedge camera_clk);reset=0;
  repeat(60)@(negedge camera_clk);
  if(camera_busy||pixel_busy)$fatal(1,"FIFO reset synchronization did not settle");
  for(i=0;i<8;i=i+1)send_pixel(i);
  waits=0;
  while(camera_empty)begin @(negedge axi_clk);waits=waits+1;if(waits>100)$fatal(1,"Camera FWFT timeout");end
  #1;
  if(!camera_valid||packed_word!==128'hf80007e0001fffff0000a55a1234cdef)
   $fatal(1,"W0_FIFO_8 big-endian/FWFT mismatch: %h valid=%b",packed_word,camera_valid);
  $display("INFO: real W0_FIFO_8 MODE=FWFT PIPELINE_REG=1 OUTPUT_REG=0 first word visible before rd_en; additional AXI-clock waits=%0d, word=%h",waits,packed_word);
  for(i=8;i<PIXELS;i=i+1)send_pixel(i);
  // Stalled writes to a 128-bit memory, preserving each AXI beat exactly.
  for(i=0;i<WORDS;i=i+1)begin
   @(negedge axi_clk);camera_re=0;
   while(camera_empty)@(negedge axi_clk);
   expected_word=0;
   for(j=0;j<8;j=j+1)expected_word[127-j*16-:16]=colour(i*8+j);
   if(packed_word!==expected_word)$fatal(1,"Packed word %0d got=%h expected=%h",i,packed_word,expected_word);
   memory[i]=packed_word;camera_re=1;
   @(negedge axi_clk);camera_re=0;
   repeat(i%4)@(negedge axi_clk);
  end
  repeat(10)@(negedge axi_clk);
  if(!camera_empty)$fatal(1,"Camera FIFO retained data after all 64 words");
  // Feed the first beat, prove first-word fall-through without requesting a read.
  @(negedge axi_clk);pixel_we=1;memory_word=memory[0];
  @(negedge axi_clk);pixel_we=0;
  waits=0;
  while(pixel_empty)begin @(negedge pixel_clk);waits=waits+1;if(waits>100)$fatal(1,"Pixel FWFT timeout");end
  #1;
  if(!pixel_valid||pixel!==16'hf800)$fatal(1,"R0_FIFO_16 first word mismatch %h valid=%b",pixel,pixel_valid);
  $display("INFO: real R0_FIFO_16 MODE=FWFT PIPELINE_REG=1 OUTPUT_REG=0 first pixel visible before rd_en; additional pixel-clock waits=%0d, pixel=%h",waits,pixel);
  for(i=1;i<WORDS;i=i+1)begin
   repeat(i%3)@(negedge axi_clk);
   @(negedge axi_clk);pixel_we=1;memory_word=memory[i];
   @(negedge axi_clk);pixel_we=0;
  end
  repeat(20)@(negedge pixel_clk);
  for(i=0;i<PIXELS;i=i+1)begin
   @(negedge pixel_clk);pixel_re=0;
   if(pixel_empty||!pixel_valid||pixel!==colour(i))
    $fatal(1,"RGB565 pixel %0d got=%h expected=%h empty=%b valid=%b",i,pixel,colour(i),pixel_empty,pixel_valid);
   // FWFT holds the next pixel during downstream stalls.
   repeat(i%4)begin @(negedge pixel_clk);if(pixel!==colour(i))$fatal(1,"FWFT changed without read at pixel %0d",i);end
   pixel_re=1;
   @(negedge pixel_clk);pixel_re=0;
  end
  repeat(10)@(negedge pixel_clk);
  if(!pixel_empty)$fatal(1,"Pixel FIFO retained data after all 512 pixels");
  if(camera_underflow||camera_overflow||pixel_underflow||pixel_overflow)$fatal(1,"Unexpected FIFO overflow/underflow");
  $display("PASS: real generated W0_FIFO_8/R0_FIFO_16 big-endian camera high-byte first -> 64 memory words -> 512 RGB565 pixels F800/07E0/001F/FFFF/0000/A55A/1234/CDEF, FWFT before read and stalls");
  $finish;
 end
 initial begin #2000000;$fatal(1,"Vendor camera FIFO endian timeout");end
endmodule
