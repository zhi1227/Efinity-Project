`timescale 1ns/1ps

module ramopt_face_case #(parameter W=320,H=180)(input clk,output reg finished=0);
 localparam GW=W/2,GH=H/2,N=GW*GH,AW=$clog2(N),XW=$clog2(GW),YW=$clog2(GH),MF=3;
 reg rst_n=0,fs=0,de=0,skin=0;reg[10:0]x=0;reg[9:0]y=0;reg[31:0]source=0;
 wire[3:0]ca,cb;wire[MF*42-1:0]ba,bb;wire busya,busyb,oa,ob,pa,pb,sa,sb;wire[31:0]ida,idb;
 integer checked=0,publishes=0,nonempty=0,max_tail=0,saturation_seen=0,overrun_seen=0;
 face_grid_regions #(.WIDTH(W),.HEIGHT(H),.CELL_SHIFT(1),.CELL_MIN(1),.MAX_FACES(MF),
 .MIN_W(2),.MIN_H(2),.MAX_W(W),.MAX_H(H),.MIN_AREA(1),.MIN_FILL_PERCENT(1),.MIN_RATIO_X10(0),.MAX_RATIO_X10(1000))
 a(clk,rst_n,fs,de,skin,x,y,ca,ba,busya,oa,source,pa,ida,sa);
 face_grid_regions_baseline #(.WIDTH(W),.HEIGHT(H),.CELL_SHIFT(1),.CELL_MIN(1),.MAX_FACES(MF),
 .MIN_W(2),.MIN_H(2),.MAX_W(W),.MAX_H(H),.MIN_AREA(1),.MIN_FILL_PERCENT(1),.MIN_RATIO_X10(0),.MAX_RATIO_X10(1000))
 b(clk,rst_n,fs,de,skin,x,y,cb,bb,busyb,ob,source,pb,idb,sb);
 always @(negedge clk)begin
  checked=checked+1;
  if(checked>2&&{ca,ba,busya,oa,pa,ida,sa,a.state,a.head,a.tail,a.current_x,a.current_y,
      a.capture_bank,a.process_bank,a.read_addr,a.clear_en,a.mask_q,a.queue_we,a.queue_wa,
      a.scan_x,a.scan_y,a.scan_addr,a.neighbour,a.neighbour_x,a.neighbour_y,a.neighbour_ok,
      a.min_x,a.max_x,a.min_y,a.max_y,a.area,a.work_count,a.work_boxes,a.result_ready,
      a.work_saturated,a.pending_saturated,a.process_id,a.pending_id,a.pending_boxes,a.pending_count}!==
     {cb,bb,busyb,ob,pb,idb,sb,b.state,b.head,b.tail,b.current_x,b.current_y,
      b.capture_bank,b.process_bank,b.read_addr,b.clear_en,b.mask_q,b.queue_we,b.queue_wa,
      b.scan_x,b.scan_y,b.scan_addr,b.neighbour,b.neighbour_x,b.neighbour_y,b.neighbour_ok,
      b.min_x,b.max_x,b.min_y,b.max_y,b.area,b.work_count,b.work_boxes,b.result_ready,
      b.work_saturated,b.pending_saturated,b.process_id,b.pending_id,b.pending_boxes,b.pending_count})
   $fatal(1,"face cycle mismatch W=%0d H=%0d checked=%0d state=%0d",W,H,checked,a.state);
  if(checked>2 && a.queue_we && a.queue_d !== b.queue_d[XW+:YW]*GW+b.queue_d[0+:XW])
   $fatal(1,"face enqueue address packing mismatch W=%0d",W);
  if(checked>2 && ^a.queue_q!==1'bx && ^b.queue_q!==1'bx &&
     a.queue_q !== b.queue_q[XW+:YW]*GW+b.queue_q[0+:XW])
   $fatal(1,"face synchronous queue data mismatch W=%0d head=%0d",W,a.head);
  if(a.tail>max_tail)max_tail=a.tail;
  if(pa)begin publishes=publishes+1;if(ca!=0)nonempty=nonempty+1;end
  if(sa)saturation_seen=1;if(oa)overrun_seen=1;
 end
 function pixel;input integer pat,xx,yy;integer cx,cy;begin
  cx=xx/2;cy=yy/2;
  case(pat)
   0:pixel=1;
   1:pixel=(cx%12<2&&cy%12<2);
   2:pixel=(cx<3&&cy<3)||(cx>=GW-3&&cy<3)||(cx>=GW-3&&cy>=GH-3);
   default:pixel=(cx>=GW/2-4&&cx<=GW/2+4&&cy>=GH/2-4&&cy<=GH/2+4);
  endcase
 end endfunction
 task pulse_commit;begin @(negedge clk);fs=1;de=0;@(negedge clk);fs=0;repeat(3)@(negedge clk);end endtask
 task frame;input integer pat,id;integer xx,yy;begin
  @(negedge clk);fs=1;de=0;source=id;
  @(negedge clk);fs=0;
  for(yy=0;yy<H;yy=yy+1)begin
   for(xx=0;xx<W;xx=xx+1)begin de=1;x=xx;y=yy;skin=pixel(pat,xx,yy);@(negedge clk);end
   de=0;repeat(4)@(negedge clk);
  end
  de=0;skin=0;repeat(3)@(negedge clk);
 end endtask
 task finish_frame;input integer expected_id;integer timeout;begin
  timeout=0;while(busya&&timeout<1600000)begin @(negedge clk);timeout=timeout+1;end
  if(timeout==1600000)$fatal(1,"face processing timeout W=%0d",W);
  pulse_commit;
  if(ida!=expected_id)$fatal(1,"face source ID mismatch W=%0d got=%0d expected=%0d",W,ida,expected_id);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  frame(0,101);frame(1,102);finish_frame(101);
  if(ca!=1||ba[10:0]!=0||ba[21:11]!=W-1||ba[31:22]!=0||ba[41:32]!=H-1)
   $fatal(1,"face full-grid result missing W=%0d count=%0d",W,ca);
  frame(1,103);finish_frame(103);
  if(ca!=MF||!sa)$fatal(1,"face saturation coverage missing W=%0d",W);
  frame(2,104);finish_frame(104);
  // Reset between partial captures, without clearing the RAM arrays.
  @(negedge clk);source=105;fs=1;@(negedge clk);fs=0;de=1;x=0;y=0;skin=1;
  repeat(37)@(negedge clk);de=0;rst_n=0;repeat(4)@(negedge clk);rst_n=1;
  frame(3,106);finish_frame(106);
  if(ca!=1)$fatal(1,"face reset recovery missing W=%0d",W);
  if(max_tail!=N||!overrun_seen||!saturation_seen||nonempty<4)
   $fatal(1,"face coverage missing W=%0d max_tail=%0d N=%0d overrun=%0d sat=%0d nonempty=%0d",W,max_tail,N,overrun_seen,saturation_seen,nonempty);
  $display("PASS: face queue W=%0d H=%0d GW=%0d GH=%0d cycles=%0d full_queue=%0d valid_publishes=%0d",W,H,GW,GH,checked,max_tail,nonempty);
  finished=1;
 end
endmodule

module ramopt_ccl_case #(parameter PX=10,CAP=1024)(input clk,output reg finished=0);
 localparam W=1280,H=32,RMAX=PX==10?1000:1279;
 reg rst_n=0,fs=0,fe=0,en=1,de=0,bit_i=0;reg[10:0]x=0;reg[9:0]y=0;
 wire va,vb;wire[10:0]x0a,x1a,x0b,x1b;wire[9:0]y0a,y1a,y0b,y1b,fa,fb;
 wire[19:0]aa,ab,ra,rb;wire[1:0]ga,gb;wire oa,ob,da,db;wire[3:0]reja,rejb,fta,ftb;
 integer checked=0,valid_results=0,gestures=0,fifo_fault_seen=0,label_fault_seen=0,deadline_seen=0,edge_seen=0,high_x_seen=0;
 ep1_gesture #(.WIDTH(W),.HEIGHT(H),.BORDER(0),.MIN_W(3),.MIN_H(3),.MIN_AREA(20),.MAX_AREA(40000),.MIN_FILL(100),
 .LABEL_CAP(CAP),.ROI_X1(RMAX),.ROI_Y1(H-1),.ALLOW_BOTTOM(1),.TRACK(1),.PACKED_X_BITS(PX))
 a(clk,rst_n,fs,fe,en,de,bit_i,x,y,va,x0a,x1a,y0a,y1a,aa,fa,ra,ga,oa,da,reja,fta);
 ep1_gesture_baseline #(.WIDTH(W),.HEIGHT(H),.BORDER(0),.MIN_W(3),.MIN_H(3),.MIN_AREA(20),.MAX_AREA(40000),.MIN_FILL(100),
 .LABEL_CAP(CAP),.ROI_X1(RMAX),.ROI_Y1(H-1),.ALLOW_BOTTOM(1),.TRACK(1))
 b(clk,rst_n,fs,fe,en,de,bit_i,x,y,vb,x0b,x1b,y0b,y1b,ab,fb,rb,gb,ob,db,rejb,ftb);
 always @(negedge clk)begin
  checked=checked+1;
  if(checked>2&&{va,x0a,x1a,y0a,y1a,aa,fa,ra,ga,oa,da,reja,fta,a.state,a.wp,a.rp,a.allocated}!==
    {vb,x0b,x1b,y0b,y1b,ab,fb,rb,gb,ob,db,rejb,ftb,b.state,b.wp,b.rp,b.allocated})
   $fatal(1,"CCL cycle mismatch PX=%0d CAP=%0d checked=%0d state=%0d",PX,CAP,checked,a.state);
  if(da)begin
   if(va)begin valid_results=valid_results+1;if(x0a>511)high_x_seen=1;end
   if(ga!=0)gestures=gestures+1;
   if(fta[0])fifo_fault_seen=1;if(fta[1])label_fault_seen=1;if(fta[3])deadline_seen=1;
  end
  if(de&&bit_i&&x==RMAX)edge_seen=1;
  if(PX==10&&de&&bit_i&&x>1000)$fatal(1,"invalid narrowed CCL stimulus");
 end
 function pixel;input integer pat,xx,yy;integer base;begin
  base=PX==10?600:1140;
  case(pat)
   0:pixel=xx>=base&&xx<base+25&&yy>=4&&yy<24;
   1:pixel=(yy==3&&((xx>=base-60&&xx<=base-45)||(xx>=base-35&&xx<=base-20)))||
      (yy>=4&&yy<=22&&xx>=base-60&&xx<=base-20);
   2:pixel=(xx>=RMAX-12&&xx<=RMAX&&yy>=3&&yy<=18)||(xx>=base&&xx<base+25&&yy>=4&&yy<24);
   3:pixel=xx>=500&&xx<680&&((xx-500)%20<4)&&yy>=3&&yy<=7;
   4:pixel=xx>=40&&xx<=RMAX&&!xx[0];
   default:pixel=0;
  endcase
 end endfunction
 task frame;input integer pat;integer xx,yy;begin
  @(negedge clk);fs=1;fe=0;de=0;
  @(negedge clk);fs=0;
  for(yy=0;yy<H;yy=yy+1)begin
   for(xx=0;xx<W;xx=xx+1)begin de=1;x=xx;y=yy;bit_i=pixel(pat,xx,yy);@(negedge clk);end
   de=0;bit_i=0;repeat(128)@(negedge clk);
  end
  fe=1;@(negedge clk);fe=0;repeat(12000)@(negedge clk);
 end endtask
 task commit;begin @(negedge clk);fs=1;de=0;fe=0;@(negedge clk);fs=0;repeat(4)@(negedge clk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  frame(0);frame(0);frame(0);frame(0);frame(1);frame(2);frame(3);
  frame(4);frame(0);commit;
  // Force an unfinished run FIFO to reach the next frame deadline.
  @(negedge clk);fs=1;@(negedge clk);fs=0;de=1;y=3;
  for(integer xx=40;xx<140;xx=xx+1)begin x=xx;bit_i=!xx[0];@(negedge clk);end
  de=0;fe=1;@(negedge clk);fe=0;commit;
  // Pointer/state reset must also recover without clearing storage arrays.
  rst_n=0;repeat(5)@(negedge clk);rst_n=1;
  frame(0);commit;
  if(valid_results<5||gestures==0||!high_x_seen||!edge_seen||!fifo_fault_seen||!deadline_seen||(CAP==8&&!label_fault_seen))
   $fatal(1,"CCL coverage missing PX=%0d CAP=%0d valid=%0d gestures=%0d high=%0d edge=%0d fifo=%0d label=%0d deadline=%0d",PX,CAP,valid_results,gestures,high_x_seen,edge_seen,fifo_fault_seen,label_fault_seen,deadline_seen);
  $display("PASS: CCL storage PX=%0d CAP=%0d cycles=%0d valid_results=%0d gesture_results=%0d fifo=%0d label=%0d deadline=%0d",PX,CAP,checked,valid_results,gestures,fifo_fault_seen,label_fault_seen,deadline_seen);
  finished=1;
 end
endmodule

module tb_ramopt_coordinates;
 reg clk=0;always #5 clk=~clk;
 wire f160,fg,c10,c8,c11;
 ramopt_face_case f0(clk,f160);
 ramopt_face_case #(.W(96),.H(64)) f1(clk,fg);
 ramopt_ccl_case c0(clk,c10);
 ramopt_ccl_case #(.CAP(8)) c1(clk,c8);
 ramopt_ccl_case #(.PX(11)) c2(clk,c11);
 initial begin
  wait(f160&&fg&&c10&&c8&&c11);
  $display("PASS: coordinate RAM exact equivalence; face 160x90 and generic 48x32; narrowed 10-bit and default 11-bit CCL; complete queues, valid boxes, merges, source IDs, saturation, overruns, FIFO/label overflow, deadlines and reset recovery");
  $finish;
 end
 initial begin #50000000;$fatal(1,"coordinate RAM equivalence timeout");end
endmodule
