`timescale 1ns/1ps
module tb_canny_integration;
 localparam W=64,H=48,HT=100;
 reg clk=0,rst_n=0,vs=0,de=0,hs=1,request=0,frozen=0,locked=0,good=1;
 reg[23:0]rgb=0;reg[31:0]id=0;reg[11:0]manual_low=40,manual_high=80;
 always #5 clk=~clk;
 wire am;wire[11:0]lo,hi;wire[15:0]version;wire[7:0]status;
 wire[23:0]out_rgb;wire out_de,out_vs,out_hs;
 parallel_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT),.CANNY_GAUSSIAN(1),.CANNY_DYNAMIC_ENABLE(1),.DEFAULT_MODE(1)) dut(
 .clk(clk),.rst_n(rst_n),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),.mode_i(4'd1),.low_i(manual_low),.high_i(manual_high),
 .rgb_o(out_rgb),.de_o(out_de),.vs_o(out_vs),.hs_o(out_hs),.freeze_i(frozen),.pure_i(1'b0),.detect_i(1'b0),
 .skin_lower_i(8'd10),.health_i(8'hff),.gesture_short_i(1'b0),.gesture_long_i(1'b0),.source_id_i(id),.shared_bits(16'd0),
 .canny_mode_request_i(request),.threshold_lock_i(locked),.processing_ok_i(good),.manual_version_i(16'd0),
 .canny_mode_o(am),.canny_low_o(lo),.canny_high_o(hi),.canny_version_o(version),.canny_status_o(status));
 reg[11:0]last_low=40,last_high=80;reg previous_fs=0;
 integer valid_outputs=0,frames=0;
 always @(posedge clk)begin
  previous_fs=dut.fs;
  #1;
  if(rst_n)begin
   if(dut.gray_valid&&(^dut.g_dynamic_canny.threshold_control.gray===1'bx))$fatal(1,"Gray tap became unknown at the controller input");
   if(previous_fs&&(^dut.g_dynamic_canny.threshold_control.gray_sum===1'bx))$fatal(1,"Completed gray sum is unknown");
   if(!previous_fs&&(lo!==last_low||hi!==last_high))$fatal(1,"integrated thresholds changed outside input frame boundary");
   if(lo>=hi||lo==0||hi>2040)$fatal(1,"integrated threshold range");
   if(out_de)begin valid_outputs=valid_outputs+1;if(^out_rgb===1'bx)begin
    $display("DEBUG unknown frame=%0d mode=%0d xy=%0d,%0d edge=%b ce/cv=%b%b edge_xy=%0d,%0d thresholds=%0d/%0d status=%h",frames,dut.mode_active,dut.ax,dut.ay,dut.aligned_edge,dut.ce,dut.cv,dut.ex,dut.ey,lo,hi,status);
    $display("DEBUG controller Q=%h candidate=%h state=%d samples=%d valids=%d input=%d gray=%d bad=%b blocked=%b target=%d cumulative=%d",dut.g_dynamic_canny.threshold_control.high_q,dut.g_dynamic_canny.threshold_control.candidate_high,dut.g_dynamic_canny.threshold_control.state,dut.g_dynamic_canny.threshold_control.sample_count,dut.g_dynamic_canny.threshold_control.nms_count,dut.g_dynamic_canny.threshold_control.input_count,dut.g_dynamic_canny.threshold_control.gray_count,dut.g_dynamic_canny.threshold_control.frame_bad,dut.g_dynamic_canny.threshold_control.frame_blocked,dut.g_dynamic_canny.threshold_control.target,dut.g_dynamic_canny.threshold_control.cumulative);
    $display("DEBUG gray outer=%h controller_port=%h sum=%h previous=%h prev_valid=%b light=%b fast=%b smooth=%h",dut.gray_tap,dut.g_dynamic_canny.threshold_control.gray,dut.g_dynamic_canny.threshold_control.gray_sum,dut.g_dynamic_canny.threshold_control.previous_gray_sum,dut.g_dynamic_canny.threshold_control.previous_gray_valid,dut.g_dynamic_canny.threshold_control.light_change,dut.g_dynamic_canny.threshold_control.fast_step,dut.g_dynamic_canny.threshold_control.smoothed_q);
    $fatal(1,"unknown video pixel");
   end end
  end
  last_low=lo;last_high=hi;
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task frame(input integer source,input integer level,input integer late_id);
  integer xx,yy;begin
   vs=0;de=0;cycles(HT*6);
   $display("DEBUG pre-fs frame=%0d source=%0d mode=%b H=%0d Q=%h candidate=%0d pending=%b state=%d bad=%b input/gray/nms=%0d/%0d/%0d hist0=%h hist1=%h hist2=%h hist63=%h",frames,id,am,hi,dut.g_dynamic_canny.threshold_control.high_q,dut.g_dynamic_canny.threshold_control.candidate_high,dut.g_dynamic_canny.threshold_control.pending_valid_o,dut.g_dynamic_canny.threshold_control.state,dut.g_dynamic_canny.threshold_control.frame_bad,dut.g_dynamic_canny.threshold_control.input_count,dut.g_dynamic_canny.threshold_control.gray_count,dut.g_dynamic_canny.threshold_control.nms_count,dut.g_dynamic_canny.threshold_control.hist[0],dut.g_dynamic_canny.threshold_control.hist[1],dut.g_dynamic_canny.threshold_control.hist[2],dut.g_dynamic_canny.threshold_control.hist[63]);
   $display("DEBUG finite gray current_sum=%0d previous_sum=%0d prev_valid=%b",dut.g_dynamic_canny.threshold_control.gray_sum,dut.g_dynamic_canny.threshold_control.previous_gray_sum,dut.g_dynamic_canny.threshold_control.previous_gray_valid);
   vs=1;
   // Source ID intentionally arrives after VS edge, before the first DE.
   cycles(late_id);id=source;cycles(20-late_id);
   for(yy=0;yy<H;yy=yy+1)begin
    for(xx=0;xx<W;xx=xx+1)begin
     @(negedge clk);de=1;
     rgb=xx>=12&&xx<52&&yy>=8&&yy<40?{3{level[7:0]}}:24'h202020;
    end
    @(negedge clk);de=0;cycles(HT-W-1);
   end
   vs=0;de=0;cycles(HT*6);frames=frames+1;
  end endtask
 reg[11:0]held_low,held_high;reg[15:0]held_version;
 initial begin
  cycles(5);rst_n=1;cycles(80);
  frame(1,216,5);if(am||lo!=40||hi!=80)$fatal(1,"baseline integration changed defaults");
  request=1;frame(2,216,7);repeat(5)frame(id+1,216,7);
  if(!am||hi<=80)$fatal(1,"integrated NMS statistics never updated thresholds");
  held_low=lo;held_high=hi;held_version=version;frozen=1;
  repeat(3)frame(id,216,5);
  if(lo!=held_low||hi!=held_high||version!=held_version)$fatal(1,"frozen repeated source changed adaptive result");
  frozen=0;locked=1;request=0;manual_low=60;manual_high=120;
  repeat(2)frame(id,216,5);
  if(!am||lo!=held_low||hi!=held_high||version!=held_version)$fatal(1,"capture lock did not retain actual mode/threshold/version");
  locked=0;frame(id+1,216,5);
  if(am||lo!=60||hi!=120)$fatal(1,"deferred baseline/manual request not committed after capture");
  good=0;request=1;frame(id+1,216,5);good=1;frame(id+1,216,5);
  frame(id+1,216,5);
  if(hi<=120||status[3])$fatal(1,"Quality restoration did not recover complete-frame adaptation");
  if(valid_outputs!=frames*W*H)$fatal(1,"integrated valid pixel count got %0d expected %0d",valid_outputs,frames*W*H);
  $display("PASS: integrated parallel_video NMS/gray taps, late source ID, frame-only thresholds, freeze/repeated source, capture lock/manual fallback, quality recovery, %0d video pixels",valid_outputs);
  $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
