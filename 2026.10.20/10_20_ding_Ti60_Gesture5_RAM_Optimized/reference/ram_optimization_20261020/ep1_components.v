// Initial calibration intervals; F is fill per mille, R is height/width per mille.
module ep1_classify(input valid,input[9:0]fill,input[19:0]ratio,output[1:0]gesture);
 assign gesture=!valid?0:(fill>=250&&fill<=600&&ratio>=650&&ratio<=1500)?1:
  (fill>=700&&ratio>=650&&ratio<=1500)?2:(fill>=250&&fill<=750&&ratio>=1600&&ratio<=3500)?3:0;
endmodule

// 8-connected run-length CCL. BRAM FIFO absorbs bursts; roots are resolved before
// union. Each run is counted once. Overflow/deadline failure invalidates the frame.
// Results commit only at frame_start; tables are initialized on allocation.
module ep1_gesture #(parameter WIDTH=1280,HEIGHT=720,BORDER=5,MIN_W=40,MIN_H=40,
 MIN_AREA=2500,MAX_AREA=460800,MIN_FILL=150,LABEL_CAP=1024,CANDIDATE_CAP=64,
 ALLOW_BOTTOM=0,TRACK=0,ROI_X0=0,ROI_X1=WIDTH-1,ROI_Y0=0,ROI_Y1=HEIGHT-1)(
 input clk,rst_n,frame_start,frame_end,enable,de,bit_i,input[10:0]x,input[9:0]y,
 output reg box_valid,output reg[10:0]xmin,xmax,output reg[9:0]ymin,ymax,
 output reg[19:0]area,output reg[9:0]fill,output reg[19:0]ratio,
 output reg[1:0]gesture,output reg overflow,result_done,
 output reg[3:0]reject_flags,fault_flags);
 reg[3:0]reject_seen;
 reg label_fault,candidate_fault;
 localparam ROW_CAP=(WIDTH+1)/2;
 (* ram_style="block" *) reg[31:0]fifo[0:1023];
 reg[10:0]wp,rp;reg in_run;reg[10:0]run_start;reg input_overflow;
 wire fifo_full=(wp-rp)==11'd1024;
 wire emit_run=de&&((bit_i&&x==WIDTH-1)||(!bit_i&&in_run));
 wire[10:0]emit_start=in_run?run_start:x,emit_end=bit_i?x:x-11'd1;
 always @(posedge clk)begin
  if(!rst_n||!enable||frame_start)begin wp<=0;in_run<=0;run_start<=0;input_overflow<=0;end
  else if(de)begin
   if(bit_i&&!in_run)run_start<=x;in_run<=bit_i&&x!=WIDTH-1;
   if(emit_run)begin if(fifo_full)input_overflow<=1;else begin fifo[wp[9:0]]<={y,emit_start,emit_end};wp<=wp+1'b1;end end
  end
 end
 reg[31:0]fq;always @(posedge clk)fq<=fifo[rp[9:0]];
 // Entry layout: parent[71:62], area[61:42], x0[41:31], x1[30:20], y0[19:10], y1[9:0].
 (* ram_style="block" *) reg[71:0]table_mem[0:1023];
 reg[9:0]ta,twaddr;reg[71:0]tq,twdata;reg twe;
 always @(posedge clk)begin tq<=table_mem[ta];if(twe)table_mem[twaddr]<=twdata;end
 (* ram_style="block" *) reg[31:0]row0[0:ROW_CAP-1],row1[0:ROW_CAP-1];
 reg bank;reg[9:0]pi,cur_count,prev_count;reg[31:0]q0,q1;
 reg row_we,row_wbank;reg[9:0]row_waddr;reg[31:0]row_wdata;
 always @(posedge clk)begin
  q0<=row0[pi];q1<=row1[pi];
  if(row_we)begin if(row_wbank)row1[row_waddr]<=row_wdata;else row0[row_waddr]<=row_wdata;end
 end
 wire[31:0]pq=bank?q0:q1;
 reg[10:0]sx,ex;reg[9:0]sy,row_y;reg row_seen,have_frame,ended,engine_overflow;
 reg[10:0]allocated,scan;reg[6:0]candidates;
 reg main_valid;reg[9:0]main_id,find_id;reg[71:0]main_data;reg advance_prev;reg[10:0]hops;
 reg best_near;reg[19:0]best_area;reg[10:0]best_x0,best_x1;reg[9:0]best_y0,best_y1;
 reg[10:0]cw;reg[9:0]ch;reg[20:0]bbox_area;reg[71:0]scan_data;
 reg pending_valid;reg[9:0]pending_fill;reg[19:0]pending_ratio;
 reg[31:0]quotient,denominator;reg[32:0]remainder;reg[5:0]div_step;reg div_ratio;
 wire[32:0]trial={remainder[31:0],quotient[31]};wire take=trial>={1'b0,denominator};
 wire[31:0]next_quotient={quotient[30:0],take};reg[1:0]last_class,streak;wire[1:0]new_class;
 ep1_classify classify(pending_valid,pending_fill,pending_ratio,new_class);
 localparam IDLE=0,FWAIT=1,FLOAD=2,ROW=3,PREV=4,PWAIT=5,PCHECK=6,FIND=7,TWAIT=8,TCHECK=9,
 AFTER=10,FINISH=11,WRITE_RUN=12,SCAN=13,SWAIT=14,SCHECK=15,EVAL=16,SELECT=17,DIVIDE=18,DONE=19,RSET=20;
 reg[4:0]state;
 wire[19:0]run_area={9'd0,ex}-{9'd0,sx}+20'd1,merged_area=main_data[61:42]+tq[61:42],final_area=main_data[61:42]+run_area;
 wire[10:0]merged_x0=main_data[41:31]<tq[41:31]?main_data[41:31]:tq[41:31];
 wire[10:0]merged_x1=main_data[30:20]>tq[30:20]?main_data[30:20]:tq[30:20];
 wire[9:0]merged_y0=main_data[19:10]<tq[19:10]?main_data[19:10]:tq[19:10];
 wire[9:0]merged_y1=main_data[9:0]>tq[9:0]?main_data[9:0]:tq[9:0];
 wire[10:0]final_x0=main_data[41:31]<sx?main_data[41:31]:sx,final_x1=main_data[30:20]>ex?main_data[30:20]:ex;
 wire[9:0]final_y0=main_data[19:10]<sy?main_data[19:10]:sy,final_y1=main_data[9:0]>sy?main_data[9:0]:sy;
 wire near_previous=box_valid&&scan_data[41:31]<=xmax&&scan_data[30:20]>=xmin&&
  scan_data[19:10]<=ymax&&scan_data[9:0]>=ymin&&
  cw*2>=xmax-xmin+1&&ch*2>=ymax-ymin+1;
 wire candidate_ok=cw>=MIN_W&&ch>=MIN_H&&scan_data[61:42]>=MIN_AREA&&scan_data[61:42]<=MAX_AREA&&
  scan_data[41:31]>BORDER&&scan_data[30:20]<WIDTH-1-BORDER&&scan_data[19:10]>BORDER&&scan_data[9:0]<HEIGHT-1-BORDER&&
  scan_data[61:42]*30'd1000>=bbox_area*MIN_FILL&&
  scan_data[41:31]>ROI_X0+BORDER&&scan_data[30:20]<ROI_X1-BORDER&&
  scan_data[19:10]>ROI_Y0+BORDER&&(ALLOW_BOTTOM||scan_data[9:0]<ROI_Y1-BORDER);
 wire area_better=scan_data[61:42]>best_area||(scan_data[61:42]==best_area&&
  (scan_data[19:10]<best_y0||(scan_data[19:10]==best_y0&&scan_data[41:31]<best_x0)));
 wire candidate_better=TRACK?((near_previous&&!best_near)||(near_previous==best_near&&area_better)):area_better;
 always @(posedge clk)begin
  twe<=0;row_we<=0;result_done<=0;
  if(!rst_n||!enable)begin
   state<=IDLE;rp<=0;bank<=0;pi<=0;cur_count<=0;prev_count<=0;sx<=0;ex<=0;sy<=0;row_y<=0;row_seen<=0;
   have_frame<=0;ended<=0;engine_overflow<=0;allocated<=0;scan<=0;candidates<=0;main_valid<=0;main_id<=0;find_id<=0;main_data<=0;advance_prev<=0;hops<=0;
   ta<=0;twaddr<=0;twdata<=0;row_waddr<=0;row_wbank<=0;row_wdata<=0;best_area<=0;best_near<=0;best_x0<=0;best_x1<=0;best_y0<=0;best_y1<=0;cw<=0;ch<=0;bbox_area<=0;scan_data<=0;
   pending_valid<=0;pending_fill<=0;pending_ratio<=0;quotient<=0;denominator<=0;remainder<=0;div_step<=0;div_ratio<=0;
   box_valid<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;area<=0;fill<=0;ratio<=0;gesture<=0;overflow<=0;last_class<=0;streak<=0;reject_flags<=0;fault_flags<=0;reject_seen<=0;label_fault<=0;candidate_fault<=0;
  end else if(frame_start)begin
   result_done<=1;overflow<=have_frame&&(input_overflow||engine_overflow||state!=DONE);
   reject_flags<=have_frame?reject_seen:4'd0;
   fault_flags<=have_frame?{state!=DONE,candidate_fault,label_fault,input_overflow}:4'd0;
   reject_seen<=0;label_fault<=0;candidate_fault<=0;
   if(have_frame&&state==DONE&&!input_overflow&&!engine_overflow&&pending_valid)begin
    box_valid<=1;xmin<=best_x0;xmax<=best_x1;ymin<=best_y0;ymax<=best_y1;area<=best_area;fill<=pending_fill;ratio<=pending_ratio;
    if(new_class==0)begin gesture<=0;last_class<=0;streak<=0;end
    else if(new_class!=last_class)begin last_class<=new_class;streak<=1;gesture<=0;end
    else begin if(streak<3)streak<=streak+1'b1;gesture<=streak>=2?new_class:2'd0;end
   end else begin box_valid<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;area<=0;fill<=0;ratio<=0;gesture<=0;last_class<=0;streak<=0;end
   state<=IDLE;rp<=0;bank<=0;pi<=0;cur_count<=0;prev_count<=0;row_seen<=0;allocated<=0;candidates<=0;best_area<=0;best_near<=0;ended<=0;engine_overflow<=0;have_frame<=1;pending_valid<=0;
  end else begin
   if(frame_end&&have_frame)ended<=1;
   case(state)
    IDLE:if(have_frame)begin if(rp!=wp)state<=FWAIT;else if(ended)begin scan<=0;state<=SCAN;end end
    FWAIT:state<=FLOAD;
    FLOAD:begin {sy,sx,ex}<=fq;rp<=rp+1'b1;main_valid<=0;state<=ROW;end
    ROW:begin
     if(!row_seen||sy!=row_y)begin prev_count<=row_seen&&sy==(row_y+1'b1) ? cur_count:10'd0;bank<=~bank;cur_count<=0;pi<=0;row_y<=sy;row_seen<=1;end
     state<=PREV;
    end
    PREV:if(pi>=prev_count)state<=FINISH;else state<=PWAIT;
    PWAIT:state<=PCHECK;
    PCHECK:begin
     if({1'b0,pq[20:10]}+12'd1<{1'b0,sx})begin pi<=pi+1'b1;state<=PREV;end
     else if({1'b0,pq[31:21]}>{1'b0,ex}+12'd1)state<=FINISH;
     else begin find_id<=pq[9:0];hops<=0;advance_prev<=pq[20:10]<=ex;state<=FIND;end
    end
    FIND:begin ta<=find_id;state<=TWAIT;end
    TWAIT:state<=TCHECK;
    TCHECK:begin
     if(tq[71:62]!=find_id)begin find_id<=tq[71:62];hops<=hops+1'b1;state<=FIND;if(hops>=1023)begin engine_overflow<=1;label_fault<=1;state<=DONE;end end
     else begin
      if(!main_valid)begin main_valid<=1;main_id<=find_id;main_data<=tq;end
      else if(find_id!=main_id)begin twe<=1;twaddr<=find_id;twdata<={main_id,tq[61:0]};main_data<={main_id,merged_area,merged_x0,merged_x1,merged_y0,merged_y1};end
      state<=AFTER;
     end
    end
    AFTER:if(advance_prev)begin pi<=pi+1'b1;state<=PREV;end else state<=FINISH;
    FINISH:begin
     if(cur_count>=ROW_CAP||(!main_valid&&allocated>=LABEL_CAP))begin engine_overflow<=1;label_fault<=1;state<=DONE;end
     else begin
      twe<=1;
      if(main_valid)begin twaddr<=main_id;twdata<={main_id,final_area,final_x0,final_x1,final_y0,final_y1};end
      else begin main_id<=allocated[9:0];twaddr<=allocated[9:0];twdata<={allocated[9:0],run_area,sx,ex,sy,sy};allocated<=allocated+1'b1;end
      state<=WRITE_RUN;
     end
    end
    WRITE_RUN:begin row_we<=1;row_wbank<=bank;row_waddr<=cur_count;row_wdata<={sx,ex,main_id};cur_count<=cur_count+1'b1;state<=IDLE;end
    SCAN:if(scan>=allocated)state<=SELECT;else begin ta<=scan[9:0];state<=SWAIT;end
    SWAIT:state<=SCHECK;
    SCHECK:begin
     scan<=scan+1'b1;
     if(tq[71:62]==scan[9:0])begin
      scan_data<=tq;cw<=tq[30:20]-tq[41:31]+11'd1;ch<=tq[9:0]-tq[19:10]+10'd1;state<=EVAL;
     end else state<=SCAN;
    end
    EVAL:begin bbox_area<=cw*ch;state<=RSET;end
    RSET:begin
     if(scan_data[41:31]<=ROI_X0+BORDER||scan_data[30:20]>=ROI_X1-BORDER||scan_data[19:10]<=ROI_Y0+BORDER||(!ALLOW_BOTTOM&&scan_data[9:0]>=ROI_Y1-BORDER))reject_seen[0]<=1;
     if(cw<MIN_W||ch<MIN_H||scan_data[61:42]<MIN_AREA)reject_seen[1]<=1;
     if(scan_data[61:42]>MAX_AREA)reject_seen[2]<=1;
     if(scan_data[61:42]*30'd1000<bbox_area*MIN_FILL)reject_seen[3]<=1;
     // Small/border/low-fill roots are not candidates. Counting them before
     // this filter falsely invalidated otherwise usable frames with ERR:4.
     if(candidate_ok)begin
      if(candidates>=CANDIDATE_CAP)begin engine_overflow<=1;candidate_fault<=1;end
      else candidates<=candidates+1'b1;
      if(candidate_better)begin best_near<=near_previous;best_area<=scan_data[61:42];best_x0<=scan_data[41:31];best_x1<=scan_data[30:20];best_y0<=scan_data[19:10];best_y1<=scan_data[9:0];end
     end
     state<=SCAN;
    end
    SELECT:begin
     if(best_area==0||input_overflow||engine_overflow)begin pending_valid<=0;state<=DONE;end
     else begin quotient<=best_area*32'd1000;denominator<=({21'd0,best_x1}-{21'd0,best_x0}+32'd1)*({22'd0,best_y1}-{22'd0,best_y0}+32'd1);remainder<=0;div_step<=0;div_ratio<=0;state<=DIVIDE;end
    end
    DIVIDE:begin
     quotient<=next_quotient;remainder<=take?trial-{1'b0,denominator}:trial;
     if(denominator==0)begin pending_valid<=0;state<=DONE;end
     else if(div_step==31)begin
      if(!div_ratio)begin pending_fill<=next_quotient[9:0];quotient<=({22'd0,best_y1}-{22'd0,best_y0}+32'd1)*32'd1000;denominator<={21'd0,best_x1}-{21'd0,best_x0}+32'd1;remainder<=0;div_step<=0;div_ratio<=1;end
      else begin pending_ratio<=next_quotient[19:0];pending_valid<=1;state<=DONE;end
     end else div_step<=div_step+1'b1;
    end
    DONE:state<=DONE;
    default:begin engine_overflow<=1;label_fault<=1;state<=DONE;end
   endcase
  end
 end
endmodule

