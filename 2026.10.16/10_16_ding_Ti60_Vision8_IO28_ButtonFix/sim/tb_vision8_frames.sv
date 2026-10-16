`timescale 1ns/1ps
module tb_vision8_frames;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg[2:0]mode=7;reg[1:0]alg=0;reg cap=0,clr=0,pip=0,de=0,vs=0;reg[10:0]x=0;reg[9:0]y=0;
 reg[15:0]pixel=0;reg[31:0]id=1;reg[11:0]low=40,high=80;reg[15:0]ver=3;
 wire busy,lock,main_en,sb,se,bad,sreset,sw,req,ar;wire[2:0]ss;wire[31:0]sd;
 wire[1:0]kind;wire[15:0]dir;wire[3:0]valid;wire[511:0]meta;wire[31:0]uf,ce;
 wire[23:0]out;wire od,ov,oh;
 reg ack=0,done=0,ok=1,empty=0,pixel_validation=0;
 integer aux_word=0;
 // The external AUX producer changes its word only after the DUT's read strobe.
 // Eight distinct RGB565 values expose byte/halfword swaps and skipped pixels.
 function[15:0]aux_sample(input integer n);
  begin case(n%8)
   0:aux_sample=16'hf800;1:aux_sample=16'h07e0;
   2:aux_sample=16'h001f;3:aux_sample=16'hffff;
   4:aux_sample=16'hffe0;5:aux_sample=16'hf81f;
   6:aux_sample=16'h07ff;default:aux_sample=16'h0000;
  endcase end endfunction
 function[23:0]expected_aux(input integer n);
  begin case(n%8)
   0:expected_aux=24'hff0000;1:expected_aux=24'h00ff00;
   2:expected_aux=24'h0000ff;3:expected_aux=24'hffffff;
   4:expected_aux=24'hffff00;5:expected_aux=24'hff00ff;
   6:expected_aux=24'h00ffff;default:expected_aux=24'h000000;
  endcase end endfunction
 wire[31:0]adata=pixel_validation?{aux_sample(aux_word*2+1),aux_sample(aux_word*2)}:32'h07e0f800;
 always @(posedge clk)begin
  if(!rst||!vs)aux_word<=0;
  else if(pixel_validation&&ar)aux_word<=aux_word+1;
 end
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
 // Observe only compositor inputs/outputs, never internal position/state signals.
 // For this 64x48 raster the specified quarter-size PiP occupies x=32..47,
 // y=16..27, with a two-pixel border at x=30..49 and y=14..29.
 task check_pip_raster(input integer test_id,input integer enabled,input integer mid_change);
  integer xx,yy,n,reads;reg[23:0]expected;reg inset,border,expected_rd;
  begin
   vs=0;de=0;cycles(40);vs=1;cycles(20);reads=0;
   if(kind!==(enabled?2'd1:2'd0))$fatal(1,"PiP case %0d wrong AUX kind %0d",test_id,kind);
   for(yy=0;yy<48;yy=yy+1)begin
    for(xx=0;xx<64;xx=xx+1)begin
     @(negedge clk);de=1;x=xx;y=yy;pixel=yy*64+xx;
     if(yy==0&&xx==1)begin
      if(mid_change==1)pip=0;
      if(mid_change==2)pip=1;
     end
     inset=xx>=32&&xx<48&&yy>=16&&yy<28;
     border=xx>=30&&xx<50&&yy>=14&&yy<30&&!inset;
     n=(yy-16)*16+xx-32;
     expected=enabled&&border?24'h35d499:enabled&&inset?expected_aux(n):24'h112233;
     expected_rd=enabled&&inset&&(n%2==1);
     @(posedge clk);
     if(ar!==expected_rd)$fatal(1,"PiP case %0d read position x=%0d y=%0d got=%b expected=%b",test_id,xx,yy,ar,expected_rd);
     if(ar)reads=reads+1;
     #1;
     if(out!==expected||od!==1'b1||ov!==1'b1||oh!==1'b1)
      $fatal(1,"PiP case %0d raster x=%0d y=%0d got=%h expected=%h de/vs/hs=%b%b%b",test_id,xx,yy,out,expected,od,ov,oh);
    end
    @(negedge clk);de=0;cycles(16);
   end
   vs=0;de=0;cycles(160);
   if(reads!=(enabled?96:0))$fatal(1,"PiP case %0d AUX word count=%0d",test_id,reads);
   if(uf!=0)$fatal(1,"PiP case %0d unexpected underflow",test_id);
   $display("CHECK: PiP case=%0d mode=%0d enabled=%0d full raster pixels=3072 AUX words=%0d",test_id,mode,enabled,reads);
  end
 endtask
 integer i;reg[11:0]old_directory;
 initial begin
  cycles(6);rst=1;cycles(15);
  mode=4;frame();if(!main_en||kind!=0)$fatal(1,"mode 5 split must retain main source, not four-frame AUX");
  cap=1;cycles(1);cap=0;cycles(5);if(busy)$fatal(1,"mode 5 incorrectly accepted capture");
  mode=7;frame();if(main_en||kind!=2)$fatal(1,"mode 8 must select saved four-frame AUX");
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
  // All supported processing modes must show correctly located normal AUX pixels
  // and restore the main raster exactly when PiP is disabled.
  pixel_validation=1;
  for(i=1;i<=3;i=i+1)begin
   mode=i;pip=1;check_pip_raster(i*10,1,0);
   pip=0;check_pip_raster(i*10+1,0,0);
  end
  // A control transition in the first active line cannot tear the current frame.
  mode=1;pip=1;check_pip_raster(40,1,1);
  check_pip_raster(41,0,2);check_pip_raster(42,1,0);
  // Original and split modes reject PiP even if the request remains asserted.
  mode=0;pip=1;check_pip_raster(50,0,0);
  mode=4;check_pip_raster(51,0,0);
  pixel_validation=0;
  // Once an AUX underflow occurs, the remaining frame cannot consume stale data.
  mode=1;pip=1;empty=1;frame();if(uf!=1)$fatal(1,"PiP underrun counter");empty=0;
  if(ar)$fatal(1,"invalid frame consumed tail");frame();if(uf!=1)$fatal(1,"underflow did not recover next frame");
  $display("PASS: frame-bound PiP/compare compositor, supported modes 1/2/3 normal AUX RGB565 pixels and border position, PiP-off main restoration, frame-bound enable/disable, processed 2x2 sampling, four captures/fifth replacement, bound source/config metadata, safe clear cancellation and underflow recovery");$finish;
 end
 initial begin #5000000;$fatal(1,"frames timeout");end
endmodule
