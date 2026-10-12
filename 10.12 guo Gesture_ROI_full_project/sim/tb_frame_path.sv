`timescale 1ns/1ps
// Behavioural asynchronous FIFO models below implement the vendor interface.
// This validates AXI sequencing and frame ownership, not the physical DDR PHY.
module W0_FIFO_8(input wr_clk_i,rd_clk_i,wr_en_i,rd_en_i,a_rst_i,input[7:0]wdata,
 output[127:0]rdata,output prog_empty_o,empty_o);
 reg[7:0]mem[0:16383];integer wp=0,rp=0,i;
 always @(posedge wr_clk_i or posedge a_rst_i)if(a_rst_i)wp<=0;else if(wr_en_i)begin mem[wp%16384]<=wdata;wp<=wp+1;end
 always @(posedge rd_clk_i or posedge a_rst_i)if(a_rst_i)rp<=0;else if(rd_en_i)rp<=rp+16;
 genvar g;generate for(g=0;g<16;g=g+1)begin assign rdata[g*8+:8]=(rp+g<wp)?mem[(rp+g)%16384]:8'd0;end endgenerate
 assign empty_o=wp<=rp,prog_empty_o=(wp-rp)<=2032;
endmodule
module R0_FIFO_16(input wr_clk_i,rd_clk_i,wr_en_i,rd_en_i,a_rst_i,input[127:0]wdata,
 output[15:0]rdata,output empty_o,almost_empty_o,prog_full_o);
 reg[15:0]mem[0:8191];integer wp=0,rp=0,j;
 always @(posedge wr_clk_i or posedge a_rst_i)if(a_rst_i)wp<=0;else if(wr_en_i)begin
 for(j=0;j<8;j=j+1)mem[(wp+j)%8192]<=wdata[j*16+:16];wp<=wp+8;end
 always @(posedge rd_clk_i or posedge a_rst_i)if(a_rst_i)rp<=0;else if(rd_en_i&&!empty_o)rp<=rp+1;
 assign rdata=empty_o?16'd0:mem[rp%8192],empty_o=wp<=rp,almost_empty_o=wp-rp<2,prog_full_o=wp-rp>=2048;
endmodule
module tb_frame_path;
 reg ac=0,wc=0,pc=0;always #5 ac=~ac;always #7 wc=~wc;always #6 pc=~pc;
 reg reset=1,wvs=0,wde=0,rvs=0,rde=0,freeze=0;reg[7:0]wd=0;
 wire[31:0]awaddr,araddr;wire[127:0]wdata;wire av,wv,wl,arv,ready,frozen;wire[15:0]pixel;
 reg awready=0,wready=0,arready=0,rv=0,rl=0;reg[127:0]rd=0;
 axi4_ctrl #(.C_RD_END_ADDR(4096),.C_W_WIDTH(8),.C_R_WIDTH(16),.C_ID_LEN(4))dut(
 .axi_clk(ac),.axi_reset(reset),.axi_awaddr(awaddr),.axi_awvalid(av),.axi_awready(awready),
 .axi_wdata(wdata),.axi_wvalid(wv),.axi_wready(wready),.axi_wlast(wl),
 .axi_bid(4'd0),.axi_bresp(2'd0),.axi_bvalid(1'b1),.axi_araddr(araddr),.axi_arvalid(arv),.axi_arready(arready),
 .axi_rid(4'd0),.axi_rdata(rd),.axi_rresp(2'd0),.axi_rlast(rl),.axi_rvalid(rv),
 .wframe_pclk(wc),.wframe_vsync(wvs),.wframe_data_en(wde),.wframe_data(wd),
 .rframe_pclk(pc),.rframe_vsync(rvs),.rframe_data_en(rde),.rframe_data(pixel),
 .freeze_request(freeze),.freeze_active(frozen),.frame_ready(ready));
 reg[127:0]memory[0:1023];integer wi=0,ri=0,wb=0,rb=0,cycle=0;reg wa=0,ra=0;
 always @(negedge ac)begin
  cycle=cycle+1;
  awready=!wa&&(cycle%5!=0);wready=wa&&(cycle%3!=0);arready=!ra&&(cycle%7!=0);
  rv=ra&&(cycle%4!=0);rd=memory[ri];rl=(rb==127);
 end
 always @(posedge ac)if(!reset)begin
  if(av&&awready)begin wi=(awaddr[23:22]*256)+(awaddr[21:0]/16);wb=0;wa=1;end
  if(wv&&wready)begin memory[wi]=wdata;wi=wi+1;wb=wb+1;if(wl)begin if(wb!=128)$fatal(1,"Bad burst");wa=0;end end
  if(arv&&arready)begin ri=araddr[23:22]*256+araddr[21:0]/16;rb=0;ra=1;end
  if(rv)begin ri=ri+1;if(rb==127)ra=0;else rb=rb+1;end
 end
 task camera_frame(input integer bytes,input[7:0]seed);integer k;begin
  @(negedge wc);wvs=1;repeat(20)@(negedge wc);
  for(k=0;k<bytes;k=k+1)begin wde=1;wd=seed+k;@(negedge wc);end
  wde=0;repeat(10)@(negedge wc);wvs=0;repeat(800)@(negedge wc);
 end endtask
 task display_frame(input[7:0]seed);integer k;reg[15:0]expected;begin
  @(negedge pc);rvs=1;repeat(8)@(negedge pc);rvs=0;repeat(1500)@(negedge pc);
  for(k=0;k<2048;k=k+1)begin
    expected={8'(seed+2*k+1),8'(seed+2*k)};
    if(pixel!==expected)$fatal(1,"DDR replay mismatch pixel %0d got %h expected %h",k,pixel,expected);
    rde=1;@(negedge pc);
  end
  rde=0;repeat(100)@(negedge pc);
 end endtask
 initial begin
  repeat(6)@(negedge ac);reset=0;
  camera_frame(0,0);if(ready)$fatal(1,"Empty frame published");
  camera_frame(4000,8'h30);if(ready)$fatal(1,"Padded short frame published");
  camera_frame(4096,8'h42);if(!ready)$fatal(1,"Complete frame not published");display_frame(8'h42);
  freeze=1;display_frame(8'h42);if(!frozen)$fatal(1,"Freeze did not latch");
  camera_frame(4096,8'h80);display_frame(8'h42);
  freeze=0;display_frame(8'h80);
  $display("PASS: camera bytes -> AXI memory -> RGB565 FIFO, stalled bursts, empty/short rejection, freeze/live ownership");$finish;
 end
 initial begin #5000000;$fatal(1,"Frame path timeout");end
endmodule
