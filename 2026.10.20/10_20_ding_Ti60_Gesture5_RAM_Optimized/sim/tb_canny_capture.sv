`timescale 1ns/1ps
// Real capture FSM plus real threshold controller. The image sampler stays the
// existing vision8_frames path; this bench tests source/config binding and the
// capture-pulse OR lock handshake on the SAME threshold frame boundary.
module tb_canny_capture;
 localparam W=192,H=24,WORDS=W*H/8;
 reg clk=0,rst_n=0,fs=0,de=0,vs=0,nv=0,gv=0;
 always #5 clk=~clk;
 reg[10:0]x=0,nx=0;reg[9:0]y=0,ny=0;
 reg[31:0]sid=1;reg request=1,cap=0;
 reg[2:0]user_mode=1;reg[11:0]manual_low=40,manual_high=80;
 wire actual_mode,pending;wire[11:0]actual_low,actual_high,candidate;
 wire[15:0]actual_version;wire[7:0]status;wire[19:0]samples,valids;
 wire busy,lock_source,main_enable,sb,se,bad,sreset,sw,aux_request,aux_rd;
 wire[2:0]slot;wire[31:0]snap_data;wire[1:0]aux_kind;wire[15:0]aux_directory;
 wire[3:0]valid_tiles;wire[511:0]metadata;wire[31:0]underflows,capture_errors;
 reg aux_ack=0,snap_done=0,override_live=0;
 reg[11:0]changed_low=333,changed_high=666;reg[15:0]changed_version=16'hffff;
 wire live_mode=override_live?~actual_mode:actual_mode;
 wire[11:0]live_low=override_live?changed_low:actual_low;
 wire[11:0]live_high=override_live?changed_high:actual_high;
 wire[15:0]live_version=override_live?changed_version:actual_version;
 wire threshold_lock=lock_source||cap;
 always @(posedge clk)gv<=rst_n&&de;
 canny_adaptive_thresholds #(.WIDTH(W),.HEIGHT(H)) thresholds(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.input_de(de),.input_x(x),.input_y(y),
  .gray_valid(gv),.gray(8'd100),.nms_valid(nv),.nms_x(nx),.nms_y(ny),.nms_mag(12'd100),
  .source_id(sid),.source_ok_i(1'b1),.freeze_i(1'b0),.capture_lock_i(threshold_lock),
  .manual_low(manual_low),.manual_high(manual_high),.mode_request(request),
  .actual_mode(actual_mode),.low_o(actual_low),.high_o(actual_high),.version_o(actual_version),
  .status_o(status),.candidate_high_o(candidate),.sample_count_o(samples),.valid_count_o(valids),.pending_valid_o(pending));
 vision8_frames #(.WIDTH(W),.HEIGHT(H),.CANNY_DYNAMIC_ENABLE(1)) dut(
  .clk(clk),.rst_n(rst_n),.mode_i(user_mode),.algorithm_i(2'd1),.pip_i(1'b0),
  .capture_i(cap),.clear_i(1'b0),.freeze_active(lock_source),.source_id(sid),
  .low_i(live_low),.high_i(live_high),.version_i(live_version),.canny_mode_i(live_mode),
  .source_ok(1'b1),.processing_ok(1'b1),.face_count(4'd0),.face_valid(1'b0),.face_saturated(1'b0),
  .rgb_i(24'd0),.de_i(de),.vs_i(vs),.hs_i(1'b1),
  .result_i({actual_high[7:0],actual_low[7:0]}),.result_de(de),.result_vs(vs),.result_x(x),.result_y(y),
  .rgb_o(),.de_o(),.vs_o(),.hs_o(),.busy(busy),.lock_source(lock_source),.main_enable(main_enable),
  .mode_committed(),.capture_low(),.capture_high(),.capture_backend(),
  .snap_begin(sb),.snap_end(se),.snap_slot(slot),.snap_bad(bad),.snap_reset(sreset),
  .snap_wr(sw),.snap_data(snap_data),.snap_full(1'b0),.snap_done(snap_done),.snap_ok(1'b1),
  .aux_request(aux_request),.aux_kind(aux_kind),.aux_directory(aux_directory),.aux_ack(aux_ack),
  .aux_data(32'd0),.aux_empty(1'b0),.aux_frame_ready(1'b1),.aux_rd(aux_rd),
  .valid_tiles(valid_tiles),.metadata(metadata),.underflows(underflows),.capture_errors(capture_errors));
 integer words=0,done_delay=0,checks=0;reg end_seen=0,hold_valid=0;
 reg letter_a_seen=0,letter_b_seen=0;
 reg saved_mode;reg[11:0]saved_low,saved_high;reg[15:0]saved_version;
 reg[31:0]saved_id;reg[15:0]expected_pixel;
 always @(negedge clk)begin
  aux_ack=aux_request;
  if(sw)begin
   expected_pixel={saved_high[7:0],saved_low[7:0]};
   if(snap_data!=={expected_pixel,expected_pixel})$fatal(1,"Snapshot pixels used changed live thresholds");
   words=words+1;
  end
  if(se!=end_seen)begin end_seen=se;done_delay=100;end
  if(done_delay!=0)begin done_delay=done_delay-1;if(done_delay==1)snap_done=~snap_done;end
 end
 always @(posedge clk)begin
  // Real raster positions select c==5 in the saved-tile label. No force or
  // alternate label implementation is used; both stored mode bits are shown.
  if(rst_n&&de&&dut.mode_active==7&&dut.y==8)begin
   if(dut.x==68&&valid_tiles[0])begin
    if(dut.label_char!==8'h41)$fatal(1,"Enhanced tile label did not show A");
    letter_a_seen=1;
   end
   if(dut.x==W/2+68&&valid_tiles[1])begin
    if(dut.label_char!==8'h42)$fatal(1,"Baseline tile label did not show B");
    letter_b_seen=1;
   end
  end
  #1;
  if(rst_n&&hold_valid&&lock_source)
   if(actual_mode!=saved_mode||actual_low!=saved_low||actual_high!=saved_high||actual_version!=saved_version)
    $fatal(1,"Capture lock changed actual algorithm parameters");
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task source_frame(input integer id,input integer start_capture);
  integer a,b;
  begin
   fs=0;vs=0;de=0;nv=0;cycles(50);
   if(start_capture)begin
    saved_mode=actual_mode;saved_low=actual_low;saved_high=actual_high;saved_version=actual_version;
    saved_id=id;words=0;cap=1;hold_valid=1;user_mode=7;
   end
   fs=1;vs=1;
   @(posedge clk);#1;
   if(start_capture)begin
    if(!lock_source||actual_mode!=saved_mode||actual_low!=saved_low||actual_high!=saved_high||actual_version!=saved_version)
     $fatal(1,"Capture-start same-fs lock lost snapshot");
    if(dut.bound_low!=saved_low||dut.bound_high!=saved_high||dut.bound_version!=saved_version||dut.bound_canny_mode!=saved_mode)
     $fatal(1,"Capture-start bound config not the actual pre-fs snapshot");
    checks=checks+1;
   end
   @(negedge clk);fs=0;cap=0;
   // Source ID arrives after fs, as it does through the real AXI->pixel CDC.
   cycles(4);sid=id;cycles(90);
   if(start_capture)begin
    override_live=1;manual_low=13;manual_high=77;request=~saved_mode;
   end
   for(b=0;b<H;b=b+1)begin
    for(a=0;a<W;a=a+1)begin
     @(negedge clk);de=1;x=a;y=b;nv=a>=6&&b>=6;nx=a-3;ny=b-3;
    end
    @(negedge clk);de=0;nv=0;cycles(12);
   end
   vs=0;de=0;nv=0;cycles(200);
  end
 endtask
 task capture(input integer id,input integer tile);
  integer n;reg[127:0]m;
  begin
   source_frame(id,1);
   for(n=0;n<5;n=n+1)source_frame(id,0);
   if(busy||words!=WORDS||bad||capture_errors!=0||!valid_tiles[tile])
    $fatal(1,"Capture publication failed busy=%0b words=%0d expected=%0d bad=%0b errors=%0d valid=%h",busy,words,WORDS,bad,capture_errors,valid_tiles);
   m=metadata[tile*128+:128];
   if(m[55:24]!=saved_id||m[71:56]!=saved_version||m[83:72]!=saved_low||m[95:84]!=saved_high||m[97:96]!=1||m[98]!=saved_mode||m[127:99]!=0)
    $fatal(1,"Snapshot metadata not bound id=%0d L/H=%0d/%0d V=%0d A=%0d mode=%0d",m[55:24],m[83:72],m[95:84],m[71:56],m[97:96],m[98]);
   checks=checks+1;hold_valid=0;override_live=0;
  end
 endtask
 initial begin
  cycles(6);rst_n=1;cycles(80);
  source_frame(1,0);source_frame(2,0);source_frame(3,0);
  if(!actual_mode||!pending||actual_high!=84)$fatal(1,"Adaptive pending preparation failed H=%0d pending=%b",actual_high,pending);
  capture(77,0);
  if(saved_mode!=1)$fatal(1,"Enhanced snapshot mode was not exercised");checks=checks+1;
  request=0;manual_low=31;manual_high=99;source_frame(78,0);
  if(actual_mode||actual_low!=31||actual_high!=99)$fatal(1,"Baseline manual setup failed");
  capture(88,1);
  if(saved_mode!=0)$fatal(1,"Baseline snapshot mode was not exercised");checks=checks+1;
  if(!letter_a_seen||!letter_b_seen)$fatal(1,"A/B saved-tile letters were not both exercised");checks=checks+2;
  $display("PASS: Canny capture %0d checks; capture pulse OR lock on same fs, actual mode/threshold/version frozen, late source ID binding, real processed snapshot sampler, metadata bit98 enhanced/baseline and post-bind live configuration changes",checks);
  $finish;
 end
 initial begin #1000000;$fatal(1,"Capture test timeout");end
endmodule
