from pathlib import Path
import zipfile
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
archive=P/'reports/before_stability.zip'
assert not archive.exists(), 'Stability update already applied; do not rerun'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for d in ['src/haar','tools','tb','sim','reports','model']:
  for f in (P/d).glob('*'):
   if f.is_file() and f!=archive and f.suffix not in ['.exe','.zip']:z.write(f,f.relative_to(P))
 for name in ['Ti60_Demo.xml','README.md','outflow/Ti60_Demo.bit','outflow/Ti60_Demo.timing.rpt','outflow/Ti60_Demo.place.rpt']:
  z.write(P/name,name)

def change(name,old,new):
 f=P/name;s=f.read_text(encoding='utf-8-sig');assert old in s,(name,old[:60]);f.write_text(s.replace(old,new),encoding='utf-8')

(P/'src/haar/haar_box_tracker.v').write_text('''`timescale 1ns/1ps
// Display-only association and dropout buffering. Input boxes must already pass Haar.
// Ages use display frames, so timeout remains bounded even if the detector stops.
module haar_box_tracker #(parameter MAX_FACES=8,HOLD_FRAMES=36)(
 input clk,rst_n,frame_start,result_valid,
 input [3:0] result_count,input [MAX_FACES*42-1:0] result_boxes,
 output reg [3:0] display_count,output reg [MAX_FACES*42-1:0] display_boxes,
 output reg [MAX_FACES-1:0] display_mask,output busy,output reg overrun
);
 localparam AGE_BITS=$clog2(HOLD_FRAMES+1),INDEX_BITS=(MAX_FACES>1)?$clog2(MAX_FACES):1;
 localparam IDLE=0,SEARCH=1,APPLY=2,COMMIT=3,PREPARE=4;
 reg [2:0] state;
 assign busy=state!=IDLE;
 reg [AGE_BITS-1:0] ttl[0:MAX_FACES-1];
 reg [MAX_FACES*42-1:0] candidates,updates;
 reg [MAX_FACES-1:0] claimed,update_mask;
 reg [3:0] count,candidate_index;
 reg [INDEX_BITS-1:0] scan_index,best_index,free_index;
 reg best_found,free_found;reg [12:0] best_score;
 wire [41:0] candidate=candidates[candidate_index*42+:42];
 wire [41:0] current=display_boxes[scan_index*42+:42];
 wire [11:0] ccx={1'b0,candidate[10:0]}+{1'b0,candidate[21:11]};
 wire [11:0] ocx={1'b0,current[10:0]}+{1'b0,current[21:11]};
 wire [10:0] ccy={1'b0,candidate[31:22]}+{1'b0,candidate[41:32]};
 wire [10:0] ocy={1'b0,current[31:22]}+{1'b0,current[41:32]};
 wire [11:0] delta_x=(ccx>ocx)?ccx-ocx:ocx-ccx;
 wire [10:0] delta_y=(ccy>ocy)?ccy-ocy:ocy-ccy;
 wire [11:0] cw={1'b0,candidate[21:11]}-{1'b0,candidate[10:0]}+1'b1;
 wire [11:0] ow={1'b0,current[21:11]}-{1'b0,current[10:0]}+1'b1;
 wire [10:0] ch={1'b0,candidate[41:32]}-{1'b0,candidate[31:22]}+1'b1;
 wire [10:0] oh={1'b0,current[41:32]}-{1'b0,current[31:22]}+1'b1;
 wire [12:0] distance={1'b0,delta_x}+{2'b0,delta_y};
 wire near=(delta_x<=((cw<ow)?cw:ow))&&(delta_y<=((ch<oh)?ch:oh));
 function [41:0] smooth;input [41:0] a,b;
 reg [11:0] x0,x1;reg [10:0] y0,y1;
 begin
  x0={1'b0,a[10:0]}+{1'b0,b[10:0]}+1'b1;
  x1={1'b0,a[21:11]}+{1'b0,b[21:11]}+1'b1;
  y0={1'b0,a[31:22]}+{1'b0,b[31:22]}+1'b1;
  y1={1'b0,a[41:32]}+{1'b0,b[41:32]}+1'b1;
  smooth={y1[10:1],y0[10:1],x1[11:1],x0[11:1]};
 end endfunction
 integer n;reg [3:0] next_count;
 always @*begin
  next_count=0;
  for(n=0;n<MAX_FACES;n=n+1)
   if(ttl[n]>1||(state==COMMIT&&update_mask[n]))next_count=next_count+1'b1;
 end
 integer k;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=IDLE;display_count<=0;display_boxes<=0;display_mask<=0;overrun<=0;
  candidates<=0;updates<=0;claimed<=0;update_mask<=0;count<=0;candidate_index<=0;
  scan_index<=0;best_index<=0;free_index<=0;best_found<=0;free_found<=0;best_score<=0;
  for(k=0;k<MAX_FACES;k=k+1)ttl[k]<=0;
 end else begin
  if(result_valid&&busy)overrun<=1;
  // Only this block changes displayed coordinates and validity, at frame boundaries.
  if(frame_start)begin
   display_count<=next_count;
   for(k=0;k<MAX_FACES;k=k+1)begin
    if(state==COMMIT&&update_mask[k])begin
     display_boxes[k*42+:42]<=updates[k*42+:42];display_mask[k]<=1;ttl[k]<=HOLD_FRAMES;
    end else if(ttl[k]>1)ttl[k]<=ttl[k]-1'b1;
    else begin ttl[k]<=0;display_mask[k]<=0;display_boxes[k*42+:42]<=0;end
   end
  end
  case(state)
   IDLE:if(result_valid&&result_count!=0)begin
    candidates<=result_boxes;count<=(result_count>MAX_FACES)?MAX_FACES:result_count;
    if(result_count>MAX_FACES)overrun<=1;
    claimed<=0;update_mask<=0;candidate_index<=0;state<=PREPARE;
   end
   PREPARE:begin scan_index<=0;best_found<=0;free_found<=0;best_score<=13'h1fff;state<=SEARCH;end
   SEARCH:begin
    if(!claimed[scan_index])begin
     if(ttl[scan_index]!=0&&near&&(!best_found||distance<best_score))begin
      best_found<=1;best_index<=scan_index;best_score<=distance;
     end
     if(ttl[scan_index]==0&&!free_found)begin free_found<=1;free_index<=scan_index;end
    end
    if(scan_index==MAX_FACES-1)state<=APPLY;else scan_index<=scan_index+1'b1;
   end
   APPLY:begin
    if(best_found)begin
     updates[best_index*42+:42]<=smooth(display_boxes[best_index*42+:42],candidate);
     claimed[best_index]<=1;update_mask[best_index]<=1;
    end else if(free_found)begin
     updates[free_index*42+:42]<=candidate;claimed[free_index]<=1;update_mask[free_index]<=1;
    end else overrun<=1;
    if(candidate_index+1>=count)state<=COMMIT;
    else begin candidate_index<=candidate_index+1'b1;state<=PREPARE;end
   end
   COMMIT:if(frame_start)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
''',encoding='utf-8')

change('src/haar/haar_engine.v','parameter SCALE_COUNT=4','parameter SCALE_COUNT=7')
change('src/haar/haar_engine.v','reg [1:0] scale_id;','reg [2:0] scale_id;')
change('src/haar/haar_engine.v','0:begin stride<=10;sw<=128;sh<=72;end\n        1:begin stride<=12;sw<=106;sh<=60;end','0:begin stride<=9;sw<=142;sh<=80;end\n        1:begin stride<=10;sw<=128;sh<=72;end\n        2:begin stride<=11;sw<=116;sh<=65;end\n        3:begin stride<=12;sw<=106;sh<=60;end\n        4:begin stride<=14;sw<=91;sh<=51;end')
change('src/haar/haar_face_video.v','DIAGNOSTICS=1,SELF_TEST=1','DIAGNOSTICS=1,SELF_TEST=1,HOLD_FRAMES=36,SELF_EXPECTED=15')
change('src/haar/haar_face_video.v','self_ok<=raw_count==16\'d7;','self_ok<=raw_count==SELF_EXPECTED;')
change('src/haar/haar_face_video.v','reg [31:0] frame_id,captured_id,result_id,published_id;','reg [31:0] frame_id,captured_id;')
start=' reg [3:0] work_count,pending_count,display_count;'
end=' reg inside_face,border;'
f=P/'src/haar/haar_face_video.v';s=f.read_text();a=s.index(start);b=s.index(end)
s=s[:a]+''' reg [3:0] work_count;wire [3:0] display_count;
 reg [10:0] bx0[0:MAX_FACES-1],bx1[0:MAX_FACES-1];reg [9:0] by0[0:MAX_FACES-1],by1[0:MAX_FACES-1];
 wire [MAX_FACES*42-1:0] work_boxes,display_boxes;wire [MAX_FACES-1:0] display_mask;
 wire tracker_busy,tracker_overrun;
 genvar bi;generate for(bi=0;bi<MAX_FACES;bi=bi+1)begin:pack_boxes
  assign work_boxes[bi*42+:42]={by1[bi],by0[bi],bx1[bi],bx0[bi]};
 end endgenerate
 haar_box_tracker #(.MAX_FACES(MAX_FACES),.HOLD_FRAMES(HOLD_FRAMES)) tracker(
  .clk(clk),.rst_n(rst_n),.frame_start(display_fs),.result_valid(hd&&!test_capture),
  .result_count(work_count),.result_boxes(work_boxes),.display_count(display_count),
  .display_boxes(display_boxes),.display_mask(display_mask),.busy(tracker_busy),.overrun(tracker_overrun));
 reg [31:0] last_cycles;reg [15:0] last_raw;reg [31:0] completed;
 integer i,match_index;reg matched;
 wire [11:0] ncx={1'b0,dx}+(ds>>1);wire [10:0] ncy={1'b0,dy}+(ds>>1);
 always @*begin
  matched=0;match_index=0;
  for(i=0;i<MAX_FACES;i=i+1)if(i<work_count&&!matched&&ncx>=bx0[i]&&ncx<=bx1[i]&&ncy>=by0[i]&&ncy<=by1[i])begin matched=1;match_index=i;end
 end
 integer j;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   work_count<=0;overrun<=0;last_cycles<=0;last_raw<=0;completed<=0;
   for(j=0;j<MAX_FACES;j=j+1)begin bx0[j]<=0;bx1[j]<=0;by0[j]<=0;by1[j]<=0;end
 end else begin
   if(start)work_count<=0;
   if(tracker_overrun)overrun<=1;
   if(dv&&!matched&&!test_capture)begin
     if(work_count<MAX_FACES)begin
       bx0[work_count]<=dx;bx1[work_count]<=(dx+ds>WIDTH)?WIDTH-1:dx+ds-1;
       by0[work_count]<=dy;by1[work_count]<=(dy+ds>HEIGHT)?HEIGHT-1:dy+ds-1;work_count<=work_count+1'b1;
     end else overrun<=1;
   end
   if(hd&&!test_capture)begin
     last_cycles<=elapsed;last_raw<=raw_count;completed<=completed+1'b1;
   end
 end
''' +s[b:]
s=s.replace('if(k<display_count)begin','if(display_mask[k])begin')
f.write_text(s,encoding='utf-8')
change('Ti60_Demo.xml','        <efx:design_file name="src/haar/haar_face_video.v"','        <efx:design_file name="src/haar/haar_box_tracker.v" version="default" library="default" />\n        <efx:design_file name="src/haar/haar_face_video.v"')
change('tools/run_tests.ps1',"'src/haar/haar_engine.v',","'src/haar/haar_engine.v','src/haar/haar_box_tracker.v',")
change('tools/run_tests.ps1',"'tb/tb_haar_selftest.v'","'tb/tb_haar_selftest.v','tb/tb_haar_tracker.v'")
for name in ['tools/run_tests.ps1','tools/program_jtag.ps1','tools/record_verified_build.py']:
 change(name,"'tb_haar_selftest'","'tb_haar_selftest','tb_haar_tracker'")
change('tools/generate_test.py','[(8,160,90),(10,128,72),(12,106,60),(16,80,45)]','[(s,1280//s,720//s) for s in (8,9,10,11,12,14,16)]')
change('tb/tb_haar_integration.v','.SELF_TEST(0)', '.SELF_TEST(0),.HOLD_FRAMES(4)')
change('tb/tb_haar_integration.v','f<10','f<18')
change('tb/tb_haar_selftest.v','f<9','f<15')
change('tb/tb_haar_selftest.v','dut.self_raw!=7','dut.self_raw!=dut.SELF_EXPECTED')
change('tb/tb_haar_selftest.v','self-test 7 raw boxes','self-test expected raw boxes')
print('Applied stabilization sources; determine exact self-test count next.')
