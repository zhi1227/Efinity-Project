`timescale 1ns/1ps
`include "rgb_balance_config.vh"
// Independent integer pixel reference, correction RTL and actual generated IP.
module tb_camera_rgb_fifo;
 reg camera_clk=0,axi_clk=0,pixel_clk=0;
 always #7 camera_clk=~camera_clk;
 always #5 axi_clk=~axi_clk;
 always #3 pixel_clk=~pixel_clk;
 reg rst_n=0,vs=0,de=0;
 reg[7:0]data=0;
 wire cvs,cde;wire[7:0]cdata;
 camera_rgb_balance correction(camera_clk,rst_n,vs,de,data,cvs,cde,cdata);
 wire[127:0]packed_word;
 wire camera_empty,camera_underflow,camera_overflow;
 wire pixel_empty,pixel_full,pixel_underflow,pixel_overflow;
 wire[15:0]pixel;
 reg camera_re=0,pixel_we=0,pixel_re=0;
 reg[127:0]memory_word=0;
 W0_FIFO_8 camera_fifo(.wr_clk_i(camera_clk),.rd_clk_i(axi_clk),
  .wr_en_i(cde),.rd_en_i(camera_re),.wdata(cdata),.a_rst_i(!rst_n),
  .rdata(packed_word),.empty_o(camera_empty),.underflow_o(camera_underflow),.overflow_o(camera_overflow));
 R0_FIFO_16 pixel_fifo(.wr_clk_i(axi_clk),.rd_clk_i(pixel_clk),
  .wr_en_i(pixel_we),.rd_en_i(pixel_re),.wdata(memory_word),.a_rst_i(!rst_n),
  .rdata(pixel),.empty_o(pixel_empty),.full_o(pixel_full),
  .underflow_o(pixel_underflow),.overflow_o(pixel_overflow));
 reg[127:0]memory[0:2047];
 reg[15:0]expected[0:16383];
 integer memory_write=0,memory_read=0,cycle_axi=0,cycle_pixel=0;
 integer sent=0,received=0,output_bytes=0,xx,yy,width,waits;
 reg output_vs_q=0,frame_tail_seen=0,error_seen=0;
 function integer gain;
  input integer centre,edge_value,weight;
  integer adjustment;
  begin
   adjustment=(centre-edge_value)*weight;
   if(adjustment>=0)adjustment=(adjustment+128)/256;
   else adjustment=-((-adjustment+128)/256);
   gain=edge_value+adjustment;
  end
 endfunction
 function integer reference_profile;
  input integer c,e,o,m,k,w;
  integer a,b,n,d,v;
  begin
   if(!`RGB_BALANCE_PROFILE_ENABLE || w<=64) reference_profile=gain(c,e,w);
   else begin
    if(w<=128) begin a=gain(c,e,64);b=o;n=w-64;end
    else if(w<=192) begin a=o;b=m;n=w-128;end
    else begin a=m;b=k;n=w-192;end
    d=b-a;v=((d<0?-d:d)*n+32)/64;
    reference_profile=d<0?a-v:a+v;
   end
  end
 endfunction
 function[15:0]reference_pixel;
  input[15:0]value;
  input integer x,y;
  integer dx,dy,wx,wy,weight,r,g,b;
  begin
   dx=x<640?x:1279-x;dy=y<360?y:719-y;
   wx=(dx*205+256)/512;wy=(dy*365+256)/512;
   if(wx>256)wx=256;if(wy>256)wy=256;
   weight=(wx*wy+128)/256;
   r=(value[15:11]*reference_profile(`RGB_BALANCE_CENTER_R,`RGB_BALANCE_EDGE_R,`RGB_BALANCE_OUTER_R,`RGB_BALANCE_MID_R,`RGB_BALANCE_CORE_R,weight)+128)/256;
   g=(value[10:5]*reference_profile(`RGB_BALANCE_CENTER_G,`RGB_BALANCE_EDGE_G,`RGB_BALANCE_OUTER_G,`RGB_BALANCE_MID_G,`RGB_BALANCE_CORE_G,weight)+128)/256;
   b=(value[4:0]*reference_profile(`RGB_BALANCE_CENTER_B,`RGB_BALANCE_EDGE_B,`RGB_BALANCE_OUTER_B,`RGB_BALANCE_MID_B,`RGB_BALANCE_CORE_B,weight)+128)/256;
   if(r>31)r=31;if(g>63)g=63;if(b>31)b=31;
   reference_pixel=`RGB_BALANCE_ENABLE?{5'(r),6'(g),5'(b)}:value;
  end
 endfunction
 function[15:0]pattern;
  input integer x,y;
  begin
   if(x==639||x==640)pattern=16'hffff;
   else case((x+y)%8)
    0:pattern=16'hf800;1:pattern=16'h07e0;2:pattern=16'h001f;
    3:pattern=16'hffff;4:pattern=16'h0000;5:pattern=16'h8410;
    6:pattern=16'h7bef;default:pattern=16'h1234;
   endcase
  end
 endfunction
 task send_pixel;
  input integer x,y;
  reg[15:0]value;
  begin
   value=pattern(x,y);expected[sent]=reference_pixel(value,x,y);sent=sent+1;
   @(negedge camera_clk);de=1;data=value[15:8];
   @(negedge camera_clk);data=value[7:0];
  end
 endtask
 // Different write/read pauses exercise FIFO prefetch and memory beat ordering.
 always @(negedge axi_clk)begin
  camera_re=0;pixel_we=0;
  if(rst_n)begin
   cycle_axi=cycle_axi+1;
   if(!camera_empty&&cycle_axi%3!=0)begin
    memory[memory_write]=packed_word;memory_write=memory_write+1;camera_re=1;
   end
   if(memory_read<memory_write&&!pixel_full&&cycle_axi%4!=0)begin
    memory_word=memory[memory_read];memory_read=memory_read+1;pixel_we=1;
   end
  end
 end
 always @(negedge pixel_clk)begin
  cycle_pixel=cycle_pixel+1;
  pixel_re=rst_n&&!pixel_empty&&(cycle_pixel%4!=0);
 end
 always @(posedge pixel_clk)if(rst_n)begin
  if(pixel_re&&!pixel_empty)begin
   if(received>=sent||pixel!==expected[received])
    $fatal(1,"Corrected FIFO pixel %0d got=%h expected=%h sent=%0d",received,pixel,expected[received],sent);
   received=received+1;
  end
  if(pixel_underflow||pixel_overflow)error_seen=1;
 end
 always @(posedge camera_clk)begin
  #1;
  if(rst_n)begin
   if(cde)begin
    output_bytes=output_bytes+1;
    if(!cvs)$fatal(1,"Corrected final pixel escaped delayed frame VS");
   end
   if(output_vs_q&&!cvs)begin
    frame_tail_seen=1;
    if(output_bytes!=2*sent)$fatal(1,"Frame-tail byte count got=%0d expected=%0d",output_bytes,2*sent);
   end
   output_vs_q=cvs;
  end
 end
 always @(posedge axi_clk)if(rst_n&&(camera_underflow||camera_overflow))error_seen=1;
 initial begin
  repeat(20)@(negedge camera_clk);rst_n=1;
  repeat(80)@(negedge camera_clk);
  @(negedge camera_clk);vs=1;
  for(yy=0;yy<720;yy=yy+1)begin
   width=(yy==0||yy==359||yy==360||yy==719)?1280:8;
   for(xx=0;xx<width;xx=xx+1)send_pixel(xx,yy);
   if(yy!=719)begin
    @(negedge camera_clk);de=0;repeat(3)@(negedge camera_clk);
   end
  end
  // VS falls directly after the final low input byte; the pipeline must drain.
  @(negedge camera_clk);vs=0;de=0;
  waits=0;
  while(received<sent||!frame_tail_seen)begin
   @(negedge camera_clk);waits=waits+1;
   if(waits>2000)$fatal(1,"Corrected FIFO final pixel timeout sent=%0d received=%0d",sent,received);
  end
  repeat(40)@(negedge camera_clk);
  if(sent!=10848||received!=10848||output_bytes!=21696||memory_write!=1356||memory_read!=1356)
   $fatal(1,"Corrected FIFO counts sent=%0d received=%0d bytes=%0d words=%0d/%0d",sent,received,output_bytes,memory_write,memory_read);
  if(!camera_empty||!pixel_empty||error_seen)$fatal(1,"Corrected FIFO residual data/overflow/underflow");
  $display("PASS: default camera_rgb_balance -> real W0_FIFO_8 -> stalled 128-bit memory -> real R0_FIFO_16; 10848 RGB565 pixels/21696 bytes/1356 words independently checked, RGB/white/gray/black, 720 rows with full edge and centre rows, byte order, delayed-VS final pixel and counts");
  $finish;
 end
 initial begin #2000000;$fatal(1,"Corrected camera FIFO integration timeout");end
endmodule
