`timescale 1ns/1ps
module tb_canny_thresholds;
 localparam W=32,H=24,N=(W-6)*(H-6);
 reg clk=0,rst_n=0,fs=0,de=0,gv=0,nv=0;
 always #5 clk=~clk;
 reg[10:0]x=0,nx=0;reg[9:0]y=0,ny=0;
 reg[7:0]pixel_gray=0,g=0;reg[11:0]mag=0,ml=40,mh=80;
 reg[31:0]sid=0;reg ok=1,frozen=0,locked=0,request=0;
 wire mode,pending;wire[11:0]lo,hi,candidate;wire[15:0]version;wire[7:0]status;wire[19:0]samples,valids;
 canny_adaptive_thresholds #(.WIDTH(W),.HEIGHT(H)) dut(
  .clk(clk),.rst_n(rst_n),.frame_start(fs),.input_de(de),.input_x(x),.input_y(y),
  .gray_valid(gv),.gray(g),.nms_valid(nv),.nms_x(nx),.nms_y(ny),.nms_mag(mag),
  .source_id(sid),.source_ok_i(ok),.freeze_i(frozen),.capture_lock_i(locked),
  .manual_low(ml),.manual_high(mh),.mode_request(request),.actual_mode(mode),
  .low_o(lo),.high_o(hi),.version_o(version),.status_o(status),
  .candidate_high_o(candidate),.sample_count_o(samples),.valid_count_o(valids),.pending_valid_o(pending));
 // Match the real gray tap: one register after RGB input, with the same valid.
 always @(posedge clk)begin gv<=rst_n&&de;g<=pixel_gray;end
 reg[11:0]previous_lo=40,previous_hi=80;reg previous_mode=0;
 integer checks=0;
 always @(posedge clk)begin
  #1;
  if(rst_n)begin
   if(!fs&&(lo!==previous_lo||hi!==previous_hi||mode!==previous_mode))$fatal(1,"Threshold/mode changed inside frame");
   if(mode&&(lo<24||hi<48||hi>512||lo>=hi))$fatal(1,"Illegal enhanced thresholds L=%0d H=%0d",lo,hi);
   previous_lo=lo;previous_hi=hi;previous_mode=mode;
  end else begin previous_lo=40;previous_hi=80;previous_mode=0;end
 end
 task tick;begin @(negedge clk);end endtask
 task boundary;
  begin de=0;nv=0;repeat(3)tick;fs=1;tick;fs=0;repeat(70)tick;end
 endtask
 // Faults: 1=input hole, 2=NMS missing last, 3=NMS coordinate swap,
 // 4=source ID changes mid-frame, 5=source quality interruption.
 // kind: 0=constant mag, 1=63 samples only, 2=mixed bins, 3=exact 75% boundary.
 task frame(input integer id,input integer level,input integer strength,input integer kind,input integer fault);
  integer a,b,n;
  begin
   sid=id;n=0;
   for(b=0;b<H;b=b+1)begin
    for(a=0;a<W;a=a+1)begin
     tick;de=!(fault==1&&a==10&&b==10);x=a;y=b;pixel_gray=level;
     if(fault==4&&a==W/2&&b==H/2)sid=id+10000;
     if(fault==5&&a==10&&b==10)ok=0;else ok=1;
     nv=a>=6&&b>=6;
     if(fault==2&&a==W-1&&b==H-1)nv=0;
     nx=a-3;ny=b-3;
     if(fault==3&&a==10&&b==10)nx=nx+1;
     if(nv)begin
      if(kind==1)mag=n<63?strength:0;
      else if(kind==2)mag=n<300?33:400;
      else if(kind==3)mag=n<351?33:400;
      else mag=strength;
      n=n+1;
     end
    end
    tick;de=0;nv=0;repeat(4)tick;
   end
   tick;de=0;nv=0;ok=1;repeat(80)tick;
  end
 endtask
 task expect_high(input integer expected,input[255:0]label);
  begin if(hi!==expected)$fatal(1,"%0s H got %0d expected %0d",label,hi,expected);checks=checks+1;end
 endtask
 integer k,aa,bb;reg[11:0]held_hi,held_lo;reg[15:0]held_version;
 initial begin
  repeat(5)tick;rst_n=1;repeat(70)tick;
  if(mode||lo!=40||hi!=80)$fatal(1,"Reset baseline defaults");checks=checks+1;
  boundary;frame(1,60,100,0,0);
  if(samples!=N||valids!=N||pending||candidate!=96)$fatal(1,"Baseline statistics/hold samples=%0d valid=%0d cand=%0d",samples,valids,candidate);
  for(k=0;k<64;k=k+1)if(dut.hist[k]!=0)$fatal(1,"Histogram not cleared bin %0d",k);
  checks=checks+2;
  boundary;expect_high(80,"Baseline ignores candidate");
  frozen=1;ml=45;mh=90;boundary;
  if(lo!=45||hi!=90||mode)$fatal(1,"Frozen baseline manual behavior");checks=checks+1;
  frozen=0;ml=40;mh=80;request=1;boundary;
  if(!mode||lo!=40||hi!=80)$fatal(1,"First adaptive frame must use manual defaults");checks=checks+1;
  frame(2,60,100,0,0);
  if(samples!=N||valids!=N||!pending||candidate!=96)$fatal(1,"Repeated-bin histogram/percentile");
  boundary;expect_high(82,"Slow positive step");
  frame(3,60,100,0,0);boundary;expect_high(84,"Fractional rounded step");
  held_version=version;frame(3,60,100,0,0);boundary;
  expect_high(84,"Duplicate source held");if(version!=held_version)$fatal(1,"Duplicate changed version");checks=checks+1;
  frozen=1;frame(4,60,400,0,0);
  if(pending)$fatal(1,"Frozen frame should be ineligible");frozen=0;
  boundary;expect_high(84,"Freeze release discards held-frame candidate");
  frame(5,80,100,0,0);boundary;
  expect_high(90,"Brightness jump fast step");if(!status[2])$fatal(1,"Fast response not armed");checks=checks+1;
  held_hi=hi;held_version=version;
  frame(5,80,100,0,0);boundary;
  if(hi!=held_hi||version!=held_version||dut.fast_left!=3)$fatal(1,"Duplicate consumed fast timer");checks=checks+1;
  for(k=6;k<9;k=k+1)begin frame(k,80,100,0,0);boundary;end
  if(status[2])$fatal(1,"Fast timer did not expire after four unique frames");checks=checks+1;
  held_hi=hi;frame(9,80,100,1,0);
  if(samples!=63||pending)$fatal(1,"Minimum samples fallback");boundary;
  if(hi!=held_hi||!status[1])$fatal(1,"Insufficient frame did not hold");checks=checks+1;
  frame(10,0,0,0,0);boundary;expect_high(held_hi,"Black flat hold");
  frame(11,255,0,0,0);boundary;expect_high(held_hi,"White flat hold");
  frame(12,255,100,2,0);
  if(samples!=N||candidate!=384)$fatal(1,"Mixed-bin three-quarter percentile");checks=checks+1;
  boundary;
  frame(121,255,100,3,0);
  if(samples!=N||candidate!=48||dut.target!=351)$fatal(1,"Exact ceil three-quarter boundary");checks=checks+1;boundary;
  frame(13,255,2040,0,0);if(candidate!=512)$fatal(1,"Upper clamp");checks=checks+1;boundary;
  frame(14,255,17,0,0);if(candidate!=48)$fatal(1,"Lower clamp/noise floor");checks=checks+1;boundary;
  frame(15,255,16,0,0);if(samples||pending)$fatal(1,"Noise floor excludes equal magnitude");checks=checks+1;boundary;
  held_hi=hi;frame(16,255,2048,0,0);
  if(pending||!status[3])$fatal(1,"Out-of-range 2048 magnitude accepted");boundary;expect_high(held_hi,"2048 magnitude rejected");
  frame(17,255,4095,0,0);
  if(pending||!status[3])$fatal(1,"Out-of-range 4095 magnitude accepted");boundary;expect_high(held_hi,"4095 magnitude rejected");
  for(k=1;k<=5;k=k+1)begin
   held_hi=hi;held_lo=lo;held_version=version;
   frame(20+k,255,100,0,k);boundary;
   if(hi!=held_hi||lo!=held_lo||version!=held_version||!status[3])$fatal(1,"Incomplete/bad frame accepted fault=%0d status=%h",k,status);
   checks=checks+1;
  end
  // Signed negative IIR and sub-LSB convergence are checked without a quality reset.
  frame(40,100,2040,0,0);boundary;
  for(k=41;k<47;k=k+1)begin frame(k,100,2040,0,0);boundary;end
  held_hi=hi;
  frame(47,100,100,0,0);boundary;
  if(hi>=held_hi||hi<96)$fatal(1,"Negative signed IIR incorrect");checks=checks+1;
  for(k=48;k<150;k=k+1)begin frame(k,100,100,0,0);boundary;end
  expect_high(96,"Uniform magnitude100 converges96");
  if(dut.high_q!=96*16||hi>100)$fatal(1,"Fractional IIR stalled or uniform edge lost its strong evidence");checks=checks+1;
  // Capture holds mode and both thresholds, including a pending baseline request.
  frame(150,100,400,0,0);held_hi=hi;held_lo=lo;held_version=version;
  locked=1;request=0;ml=51;mh=103;boundary;
  if(!mode||hi!=held_hi||lo!=held_lo||version!=held_version)$fatal(1,"Capture lock not atomic");checks=checks+1;
  locked=0;boundary;if(mode||lo!=51||hi!=103)$fatal(1,"Baseline restore/manual values");checks=checks+1;
  // A candidate must never survive a source-quality loss.
  request=1;ml=40;mh=80;boundary;frame(151,100,400,0,0);
  if(!pending)$fatal(1,"Expected pending candidate");ok=0;repeat(3)tick;
  if(pending)$fatal(1,"Lost video left stale pending");ok=1;held_hi=hi;boundary;
  expect_high(held_hi,"Lost video holds last reliable threshold");
  locked=1;frame(152,100,400,0,0);locked=0;boundary;
  expect_high(held_hi,"Capture release discards held-frame candidate");
  // A legal frame whose scan is not ready at fs must retain the old threshold.
  sid=153;held_hi=hi;
  for(bb=0;bb<H;bb=bb+1)begin
   for(aa=0;aa<W;aa=aa+1)begin
    tick;de=1;x=aa;y=bb;pixel_gray=100;nv=aa>=6&&bb>=6;nx=aa-3;ny=bb-3;mag=400;
   end
   if(bb!=H-1)begin tick;de=0;nv=0;repeat(4)tick;end
  end
  tick;de=0;nv=0;repeat(3)tick;
  if(dut.state!=2'd2)$fatal(1,"Expected real scan in progress");
  fs=1;tick;fs=0;repeat(70)tick;
  expect_high(held_hi,"Pending not ready hold");
  frame(154,100,400,0,0);boundary;
  if(hi<=held_hi||status[3])$fatal(1,"Clearing after missed scan prevented later adaptation");checks=checks+1;
  // Late AXI-to-pixel source tags arrive in blanking before first DE; long
  // blanking must neither bind the old ID nor count phantom gray/NMS samples.
  request=0;ml=40;mh=80;boundary;request=1;boundary;
  repeat(11)tick;sid=155;repeat(2000)tick;
  frame(155,100,100,0,0);repeat(2000)tick;
  if(!pending||dut.frame_id!=155||samples!=N||valids!=N)$fatal(1,"Late-ID/long-blank frame not bound correctly");
  boundary;expect_high(82,"Late-ID and long-blank adaptive recovery");
  if(status[3])$fatal(1,"Late blanking tag falsely invalidated frame");checks=checks+1;
  // B clears the previous enhancement session's source/gray history. A starts
  // from manual values, then a large gradient drop can reacquire in one fs.
  request=0;ml=128;mh=256;boundary;
  if(dut.previous_gray_valid||dut.last_source_valid)$fatal(1,"Baseline did not clear adaptive history");checks=checks+1;
  request=1;boundary;frame(200,100,270,0,0);boundary;expect_high(256,"Strong scene initialized");
  if(status[2]||status[5])$fatal(1,"New session reused stale fast history");checks=checks+1;
  frame(201,100,65,0,0);
  expect_high(256,"Weak frame uses unchanged current spatial threshold");
  if(candidate!=64||dut.gray_sum!=dut.previous_gray_sum)$fatal(1,"Drop case not independent of global mean");
  boundary;expect_high(64,"Large gradient-drop reacquire");
  if(!status[5]||dut.high_q!=64*16||dut.fast_left!=3)$fatal(1,"Gradient-drop reacquire state");checks=checks+1;
  for(k=202;k<205;k=k+1)begin
   frame(k,100,65,0,0);boundary;
   if(hi!=64||status[5])$fatal(1,"Constant weak scene reacquired repeatedly");checks=checks+1;
  end
  // A candidate only 16 units lower keeps the ordinary alpha=1/8 response.
  request=0;ml=40;mh=80;boundary;request=1;boundary;
  frame(205,100,65,0,0);boundary;expect_high(78,"Small gradient drop remains smoothed");
  if(status[5]||dut.high_q!=78*16)$fatal(1,"Small 16-unit fluctuation snapped to candidate");checks=checks+1;
  rst_n=0;repeat(4)tick;rst_n=1;repeat(70)tick;
  if(mode||lo!=40||hi!=80||pending||version!=0)$fatal(1,"Reset failed");checks=checks+1;
  $display("PASS: adaptive threshold controller %0d checks; frame atomicity, histogram, percentile, signed Q4 IIR, fast response, unique source, freeze/capture, incomplete frames and recovery",checks);
  $finish;
 end
 initial begin #10000000;$fatal(1,"Timeout");end
endmodule

module tb_canny_thresholds_full;
 localparam W=1280,H=720,N=909636;
 reg clk=0,rst_n=0,fs=0,de=0,gv=0,nv=0;
 always #5 clk=~clk;
 reg[10:0]x=0,nx=0;reg[9:0]y=0,ny=0;
 wire mode,pending;wire[11:0]lo,hi,candidate;wire[15:0]version;wire[7:0]status;wire[19:0]samples,valids;
 canny_adaptive_thresholds dut(.clk(clk),.rst_n(rst_n),.frame_start(fs),
  .input_de(de),.input_x(x),.input_y(y),.gray_valid(gv),.gray(8'd255),
  .nms_valid(nv),.nms_x(nx),.nms_y(ny),.nms_mag(12'd2040),
  .source_id(32'd1),.source_ok_i(1'b1),.freeze_i(1'b0),.capture_lock_i(1'b0),
  .manual_low(12'd40),.manual_high(12'd80),.mode_request(1'b1),
  .actual_mode(mode),.low_o(lo),.high_o(hi),.version_o(version),.status_o(status),
  .candidate_high_o(candidate),.sample_count_o(samples),.valid_count_o(valids),.pending_valid_o(pending));
 always @(posedge clk)gv<=rst_n&&de;
 integer a,b;
 initial begin
  repeat(5)@(negedge clk);rst_n=1;repeat(70)@(negedge clk);
  fs=1;@(negedge clk);fs=0;repeat(70)@(negedge clk);
  for(b=0;b<H;b=b+1)begin
   for(a=0;a<W;a=a+1)begin
    @(negedge clk);de=1;x=a;y=b;nv=a>=6&&b>=6;nx=a-3;ny=b-3;
   end
   @(negedge clk);de=0;nv=0;repeat(6)@(negedge clk);
  end
  if(dut.hist[63]!=N)$fatal(1,"20-bit same-bin count wrapped: %0d",dut.hist[63]);
  repeat(80)@(negedge clk);
  if(samples!=N||valids!=N||candidate!=512||!pending||dut.gray_count!=921600||dut.gray_sum!=235008000)
   $fatal(1,"720p counts samples=%0d valid=%0d gray=%0d sum=%0d cand=%0d status=%h",samples,valids,dut.gray_count,dut.gray_sum,candidate,status);
  fs=1;@(negedge clk);fs=0;
  if(hi!=134||lo!=67||!mode||status[3])$fatal(1,"720p candidate commit H=%0d L=%0d status=%h",hi,lo,status);
  $display("PASS: full 1280x720 frame, 921600 input/gray pixels, 909636 consecutive same-bin NMS samples, 235008000 gray sum, atomic threshold 67/134");$finish;
 end
 initial begin #30000000;$fatal(1,"Timeout");end
endmodule
