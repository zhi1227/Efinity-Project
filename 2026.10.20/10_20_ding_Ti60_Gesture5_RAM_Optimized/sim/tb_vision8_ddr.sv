`timescale 1ns/1ps
module tb_vision8_ddr #(parameter WITH_IO29=0);
 reg clk=0,pclk=0,camclk=0,reset=1;always #5 clk=~clk;always #7 pclk=~pclk;always #10 camclk=~camclk;
 wire[31:0]awaddr,araddr;wire[7:0]awlen,arlen;wire awvalid,arvalid,wvalid,wlast,bready,rready;
 wire[127:0]wdata;wire[15:0]wstrb;reg awready=0,arready=0,wready=0,bvalid=0,rvalid=0,rlast=0;
 reg[1:0]bresp=0;reg[127:0]rdata=0;
 reg cvs=0,cde=0,rvs=1,ren=0,freeze=0;reg[7:0]cd=0;wire[15:0]pixel;
 reg io29=1;wire key_freeze;
 generate if(WITH_IO29)begin:button_path
  vision8_controls #(.DEBOUNCE(3),.LONG_CYCLES(24)) controls(
   .clk(pclk),.rst_n(!reset),.frame_start(1'b0),.io35(1'b0),.io28(1'b1),.io29(io29),.k1_n(1'b1),.k2_n(1'b1),
   .capture_busy(1'b0),.learning(1'b0),.rx(1'b1),.freeze_request(key_freeze));
 end else begin assign key_freeze=1'b0;end endgenerate
 task io29_short;begin io29=0;repeat(10)@(negedge pclk);io29=1;repeat(12)@(negedge pclk);end endtask
 reg aux_req=0;reg[1:0]aux_kind=0;reg[15:0]directory=0;wire aux_ack,aux_ready;
 reg sb=0,se=0,sbad=0,sreset=1,sw=0,ard=0;reg[2:0]slot=4;reg[31:0]sd=0;
 wire sfull,sdone,sok,aempty,have,frozen;wire[31:0]aq,id,errors,base_errors;
 vision8_ddr #(.C_ID_LEN(4),.C_W_WIDTH(8),.C_R_WIDTH(16),.C_RD_END_ADDR(6144),.FRAME_W(64),.FRAME_H(48))dut(
 .axi_clk(clk),.axi_reset(reset),.axi_awid(),.axi_awaddr(awaddr),.axi_awlen(awlen),.axi_awsize(),.axi_awburst(),.axi_awlock(),.axi_awcache(),.axi_awprot(),.axi_awqos(),.axi_awvalid(awvalid),.axi_awready(awready),
 .axi_wdata(wdata),.axi_wstrb(wstrb),.axi_wlast(wlast),.axi_wvalid(wvalid),.axi_wready(wready),.axi_bid(4'd0),.axi_bresp(bresp),.axi_bvalid(bvalid),.axi_bready(bready),
 .axi_arid(),.axi_araddr(araddr),.axi_arlen(arlen),.axi_arsize(),.axi_arburst(),.axi_arlock(),.axi_arcache(),.axi_arprot(),.axi_arqos(),.axi_arvalid(arvalid),.axi_arready(arready),
 .axi_rid(4'd0),.axi_rdata(rdata),.axi_rresp(2'd0),.axi_rlast(rlast),.axi_rvalid(rvalid),.axi_rready(rready),
 .wframe_pclk(camclk),.wframe_vsync(cvs),.wframe_data_en(cde),.wframe_data(cd),.rframe_pclk(pclk),.rframe_vsync(rvs),.rframe_data_en(ren),.rframe_data(pixel),.tp_o(),
 .freeze_request(WITH_IO29?key_freeze:freeze),.frame_ready(have),.freeze_active(frozen),.main_enable(1'b1),.aux_request(aux_req),.aux_kind(aux_kind),.aux_directory(directory),.aux_ack(aux_ack),.aux_frame_ready(aux_ready),
 .snap_begin(sb),.snap_end(se),.snap_slot(slot),.snap_bad(sbad),.snap_reset(sreset),.snap_wr(sw),.snap_data(sd),.snap_full(sfull),.aux_rd(ard),.aux_data(aq),.aux_empty(aempty),.snap_done(sdone),.snap_ok(sok),.source_id(id),.base_errors(base_errors),.memory_errors(errors));
 reg[127:0]raw[0:1535];reg[127:0]shots[0:163839];
 reg[31:0]wa,ra,rng=32'h9126acd8;integer wb,rb,wl,rl,delay_b;
 reg writing=0,reading=0;integer accepted_writes=0,accepted_reads=0;
 function integer index_raw(input[31:0]a);index_raw=(a>>22)*384+((a&32'h3fffff)>>4);endfunction
 function[127:0]load(input[31:0]a);begin if(a<32'h1000000)load=raw[index_raw(a)];else load=shots[(a-32'h1000000)>>4];end endfunction
 always @(negedge clk)begin
  if(reset)begin awready=0;arready=0;wready=0;end
  else begin rng=rng*1664525+1013904223;awready=!writing&&!bvalid&&delay_b==0&&rng[0];arready=!reading&&!rvalid&&rng[1];wready=writing&&rng[2];end
 end
 always @(posedge clk)begin
  if(reset)begin writing<=0;reading<=0;bvalid<=0;rvalid<=0;delay_b<=0;accepted_writes<=0;accepted_reads<=0;end
  else begin
   if(awvalid&&awready)begin
    $display("AW %h len=%d",awaddr,awlen);
    if(awaddr[11:0]+(awlen+1)*16>4096)$fatal(1,"AW crossed 4K");
    writing<=1;wa<=awaddr;wb<=0;wl<=awlen;accepted_writes<=accepted_writes+1;
   end
   if(wvalid&&wready)begin
    if(wlast!==(wb==wl)||wstrb!==16'hffff)$fatal(1,"WLAST/WSTRB");
    if(wa<32'h1000000)raw[index_raw(wa)+wb]<=wdata;else shots[((wa-32'h1000000)>>4)+wb]<=wdata;
    wb<=wb+1;if(wlast)begin writing<=0;delay_b<=9;end
   end
   if(delay_b>0)begin delay_b<=delay_b-1;if(delay_b==1)bvalid<=1;end
   if(bvalid&&bready)bvalid<=0;
   if(arvalid&&arready)begin
    if(araddr[11:0]+(arlen+1)*16>4096)$fatal(1,"AR crossed 4K %h %d",araddr,arlen);
    reading<=1;ra<=araddr;rb<=0;rl<=arlen;accepted_reads<=accepted_reads+1;
   end
   if(rvalid&&rready)begin rvalid<=0;rb<=rb+1;if(rlast)reading<=0;end
   else if(reading&&!rvalid&&rng[4])begin rvalid<=1;rdata<=load(ra+rb*16);rlast<=rb==rl;end
  end
 end
 // AXI descriptors and data remain stable throughout every ready stall.
 reg[31:0]last_aw,last_ar;reg[7:0]last_awlen,last_arlen;reg aws=0,ars=0,ws=0;reg[127:0]last_data;reg last_wlast;
 always @(posedge clk)if(!reset)begin
  if(aws&&(awaddr!==last_aw||awlen!==last_awlen||!awvalid))$fatal(1,"AW changed under stall");
  if(ars&&(araddr!==last_ar||arlen!==last_arlen||!arvalid))$fatal(1,"AR changed under stall");
  if(ws&&(wdata!==last_data||wlast!==last_wlast||!wvalid))$fatal(1,"W changed under stall");
  aws=awvalid&&!awready;ars=arvalid&&!arready;ws=wvalid&&!wready;last_aw=awaddr;last_ar=araddr;last_awlen=awlen;last_arlen=arlen;last_data=wdata;last_wlast=wlast;
 end
 task camera_frame(input integer generation,input integer bytes_count);
  integer i,n;reg[15:0]value;
  begin @(negedge camclk);cvs=1;
   for(i=0;i<bytes_count;i=i+1)begin n=i/2;value=((n/64+generation*16)<<8)|(n%64);cd=i%2==0?value[15:8]:value[7:0];cde=1;@(negedge camclk);end
   cde=0;cvs=0;repeat(400)@(negedge camclk);
  end
 endtask
 task reader_start;begin @(negedge pclk);rvs=1;repeat(10)@(negedge pclk);rvs=0;repeat(100)@(negedge pclk);end endtask
 task snapshot(input integer generation,input bit fail_response);
  integer i;reg old;begin
   old=sdone;sreset=1;repeat(12)@(negedge pclk);sreset=0;repeat(12)@(negedge pclk);sb=~sb;
   bresp=fail_response?2'd2:0;
   for(i=0;i<384;i=i+1)begin
    while(sfull)@(negedge pclk);
    sd={16'(generation*4096+i*2+1),16'(generation*4096+i*2)};sw=1;@(negedge pclk);sw=0;repeat(3)@(negedge pclk);
   end
   se=~se;wait(sdone!=old);if(sok===fail_response)$fatal(1,"snapshot B response status");
   repeat(10)@(negedge pclk);bresp=0;
  end endtask
 integer i,j;reg[127:0]expected;reg[31:0]hold_id;
 initial begin
  #200;reset=0;repeat(100)@(negedge camclk);camera_frame(0,6144);wait(have);reader_start();wait(id==1);
  if(WITH_IO29)begin io29_short();if(!key_freeze)$fatal(1,"IO29 button failed to request freeze");end else freeze=1;
  reader_start();wait(frozen);hold_id=id;
  fork camera_frame(1,6144);snapshot(2,0);join
  if(id!=hold_id)$fatal(1,"camera overwrote frozen displayed slot");
  for(i=0;i<96;i=i+1)begin for(j=0;j<8;j=j+1)expected[j*16+:16]=16'h2000+i*8+j;
   if(shots[131072+i]!==expected)$fatal(1,"snapshot ordering beat=%d",i);end
  // Aux compares from DDR with the exact same snapshot word/pixel order.
  aux_kind=2;directory={4'b0001,12'h004};aux_req=~aux_req;wait(aux_ack==aux_req);wait(aux_ready);
  for(i=0;i<384;i=i+1)begin wait(!aempty);@(negedge pclk);
   if(aq!=={16'(16'h2000+i*2+1),16'(16'h2000+i*2)})$fatal(1,"aux compare order %d got %h",i,aq);
   ard=1;@(negedge pclk);ard=0;
  end
  // Abort/restart mid-reader drains old returns before FIFO reset and new data.
  aux_kind=0;aux_req=~aux_req;wait(aux_ack==aux_req);repeat(100)@(negedge clk);
  snapshot(3,1);if(errors==0)$fatal(1,"missing AXI error count");
  aux_kind=1;aux_req=~aux_req;wait(aux_ack==aux_req);wait(aux_ready);wait(!aempty);@(negedge pclk);
  if(aq!==32'h00040000)$fatal(1,"PiP raw endian/sampling got %h",aq);
  if(base_errors!=0)$fatal(1,"unexpected base errors %d",base_errors);
  if(WITH_IO29)begin
   io29_short();if(key_freeze)$fatal(1,"IO29 button failed to request resume");
   reader_start();wait(!frozen);wait(id==2);
   io29_short();reader_start();wait(frozen);if(id!=2)$fatal(1,"IO29 re-freeze lost latest frame");
   $display("PASS: IO29 active-low button -> debounce/release -> freeze request -> DDR slot held while camera writes -> resume latest source -> re-freeze");
  end
  $display("PASS: real vendor camera/main FIFOs, simultaneous DDR clients, stable stalls, B-response commit/error, snapshot packing, compare/PiP readback and restart drain; W=%d R=%d",accepted_writes,accepted_reads);$finish;
 end
 initial begin #10000000;$display("camera state=%d ptr=%d bytes=%d good=%b overflow=%b ready=%b writes=%d wowner=%d wpending=%b",dut.camera.rs_w,dut.camera.rc_w_ptr,dut.camera.camera_bytes,dut.camera.camera_frame_good,dut.camera.camera_overflow,have,accepted_writes,dut.write_owner,dut.camera.r_weof_pending);$display("aw=%h av=%b ready=%b caw=%b cready=%b wd=%b br=%b bv=%b wb=%d burst=%d",awaddr,awvalid,awready,dut.c_awvalid,dut.c_awready,dut.write_data,dut.write_response,bvalid,wb,dut.camera.rc_burst);$fatal(1,"DDR timeout state bytes=%d id=%d owner=%d",dut.snapshot_bytes,id,dut.read_owner);end
endmodule
