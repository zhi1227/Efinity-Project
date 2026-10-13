`timescale 1ns/1ps
module tb_vision8_frames;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg[2:0]mode=4;reg[1:0]alg=0;reg cap=0,clr=0,pip=0,de=0,vs=0;reg[10:0]x=0;reg[9:0]y=0;
 reg[15:0]pixel=0;reg[31:0]id=1;reg[11:0]low=40,high=80;reg[15:0]ver=3;
 wire busy,lock,main_en,sb,se,bad,sreset,sw,req,ar;wire[2:0]ss;wire[31:0]sd;
 wire[1:0]kind;wire[15:0]dir;wire[3:0]valid;wire[511:0]meta;wire[31:0]uf,ce;
 wire[23:0]out;wire od,ov,oh;
 reg ack=0,done=0,ok=1,empty=0;reg[31:0]adata=32'h07e0f800;
 vision8_frames #(.WIDTH(64),.HEIGHT(48))dut(
 .clk(clk),.rst_n(rst),.mode_i(mode),.algorithm_i(alg),.pip_i(pip),.capture_i(cap),.clear_i(clr),.freeze_active(1'b1),.source_id(id),
 .low_i(low),.high_i(high),.version_i(ver),.source_ok(1'b1),.processing_ok(1'b1),.face_count(4'd0),.face_valid(1'b0),.face_saturated(1'b0),
 .rgb_i(24'h112233),.de_i(de),.vs_i(vs),.hs_i(1'b1),.result_i(pixel),.result_de(de),.result_vs(vs),.result_x(x),.result_y(y),
 .rgb_o(out),.de_o(od),.vs_o(ov),.hs_o(oh),.busy(busy),.lock_source(lock),.main_enable(main_en),.capture_low(),.capture_high(),.capture_backend(),
 .snap_begin(sb),.snap_end(se),.snap_slot(ss),.snap_bad(bad),.snap_reset(sreset),.snap_wr(sw),.snap_data(sd),.snap_full(1'b0),.snap_done(done),.snap_ok(ok),
 .aux_request(req),.aux_kind(kind),.aux_directory(dir),.aux_ack(ack),.aux_data(adata),.aux_empty(empty),.aux_frame_ready(1'b1),.aux_rd(ar),.valid_tiles(valid),.metadata(meta),.underflows(uf),.capture_errors(ce));
 integer words=0,end_delay=0,generation=0;reg end_seen=0;reg[15:0]first,second;
 function[15:0]sample(input integer n);integer xx,yy;begin xx=(n%32)*2;yy=(n/32)*2;sample=generation*4096+yy*64+xx;end endfunction
 always @(negedge clk)begin
  ack=req;
  if(sw)begin first=sample(words*2);second=sample(words*2+1);if(sd!=={second,first})$fatal(1,"downsample pair=%d got %h expected %h",words,sd,{second,first});words=words+1;end
  if(se!=end_seen)begin end_seen=se;end_delay=120;end
  if(end_delay!=0)begin end_delay=end_delay-1;if(end_delay==1)done=~done;end
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task frame;
  integer xx,yy;begin
   vs=0;de=0;cycles(40);vs=1;cycles(20);
   for(yy=0;yy<48;yy=yy+1)begin
    for(xx=0;xx<64;xx=xx+1)begin @(negedge clk);de=1;x=xx;y=yy;pixel=generation*4096+yy*64+xx;end
    @(negedge clk);de=0;cycles(16);
   end
   vs=0;de=0;cycles(160);
  end
 endtask
 task take;
  begin words=0;cap=1;cycles(1);cap=0;repeat(5)frame();if(busy||words!=384)$fatal(1,"capture did not finish busy=%b words=%d",busy,words);end
 endtask
 integer i;reg[11:0]old_directory;
 initial begin
  cycles(6);rst=1;cycles(15);frame();
  for(i=0;i<4;i=i+1)begin alg=i;generation=i;id=i+10;low=40+i;high=80+i;ver=i+3;take();
   if(valid!==((1<<(i+1))-1))$fatal(1,"tile publication order");
   if(meta[i*128+24+:32]!==id||meta[i*128+72+:12]!==low||meta[i*128+96+:2]!==alg)$fatal(1,"bound metadata");
  end
  old_directory=dut.directory;generation=4;id=20;alg=0;take();
  if(dut.directory[11:3]!==old_directory[11:3]||dut.directory[2:0]!==3)$fatal(1,"fifth capture replacement");
  if(meta[55:24]!=20)$fatal(1,"replacement source tag");
  // Clear during capture cancels its publication but still drains the last frame.
  words=0;cap=1;cycles(1);cap=0;frame();frame();frame();clr=1;cycles(1);clr=0;frame();frame();
  if(valid!=0||meta!=0||ce!=1||busy)$fatal(1,"clear/cancel left stale tiles");
  // Once an AUX underflow occurs, the remaining frame cannot consume stale data.
  mode=1;pip=1;empty=1;frame();if(uf!=1)$fatal(1,"PiP underrun counter");empty=0;
  if(ar)$fatal(1,"invalid frame consumed tail");frame();if(uf!=1)$fatal(1,"underflow did not recover next frame");
  $display("PASS: frame-bound PiP/compare compositor, processed 2x2 sampling, four captures/fifth replacement, bound source/config metadata, safe clear cancellation and underflow recovery");$finish;
 end
 initial begin #5000000;$fatal(1,"frames timeout");end
endmodule
