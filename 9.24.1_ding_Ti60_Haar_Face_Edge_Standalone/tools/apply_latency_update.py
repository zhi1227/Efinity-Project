from pathlib import Path
import zipfile
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
archive=P/'reports/before_latency.zip'
assert not archive.exists(), 'One-time patch already applied'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for d in ['src/haar','tools','tb','sim','reports','model']:
  for f in (P/d).glob('*'):
   if f.is_file() and f!=archive and f.suffix not in ['.exe','.zip']:z.write(f,f.relative_to(P))
 for name in ['Ti60_Demo.xml','README.md','outflow/Ti60_Demo.bit','outflow/Ti60_Demo.timing.rpt','outflow/Ti60_Demo.place.rpt']:z.write(P/name,name)
def change(name,a,b):
 f=P/name;s=f.read_text(encoding='utf-8-sig');assert a in s,(name,a[:80]);f.write_text(s.replace(a,b),encoding='utf-8')
change('src/haar/haar_engine.v','input clk,rst_n,input load_we','input [1:0] scan_phase,\n input clk,rst_n,input load_we')
change('src/haar/haar_engine.v','reg [4:0] stride;','reg [1:0] active_phase;reg [2:0] read_cycle;\n reg [4:0] stride;')
change('src/haar/haar_engine.v','(corner[0]?rw:0)','(read_cycle[0]?rw:0)')
change('src/haar/haar_engine.v','(corner[1]?rh:0)','(read_cycle[1]?rh:0)')
change('src/haar/haar_engine.v','state<=IDLE;max_stage<=0;','state<=IDLE;active_phase<=0;read_cycle<=0;max_stage<=0;')
change('src/haar/haar_engine.v','IDLE:if(start)begin max_stage<=0;','IDLE:if(start)begin active_phase<=scan_phase;max_stage<=0;')
change('src/haar/haar_engine.v','if(by==sh-1)begin wx<=0;wy<=0;state<=WINDOW;end','if(by==sh-1)begin wx<=active_phase[0];wy<=active_phase[1];state<=WINDOW;end')
change('src/haar/haar_engine.v','WINDOW:begin rx<=0;','WINDOW:begin read_cycle<=0;rx<=0;')
f=P/'src/haar/haar_engine.v';s=f.read_text();a=s.index('   COR0:begin');b=s.index('   VAR0:',a)
s=s[:a]+'''   // One address each clock; ii_ra + synchronous RAM impose two clocks of latency.
   // Four corners are issued at clocks 0..3 and accumulated at clocks 2..5.
   COR0:begin
     if(read_cycle<4)ii_ra<=cy*160+cx;
     case(read_cycle)
       2:begin rect_sum<=ii_q[17:0];rect_sq<=ii_q[43:18];end
       3,4:begin rect_sum<=rect_sum-ii_q[17:0];rect_sq<=rect_sq-ii_q[43:18];end
       5:begin rect_sum<=rect_sum+ii_q[17:0];rect_sq<=rect_sq+ii_q[43:18];end
     endcase
     if(read_cycle==5)state<=norm_read?VAR0:ACC;
     else read_cycle<=read_cycle+1'b1;
   end
''' +s[b:];s=s.replace('FEAT2:begin\n','FEAT2:begin\n     read_cycle<=0;\n');s=s.replace('begin wx<=0;wy<=wy+SCAN_STEP;','begin wx<=active_phase[0];wy<=wy+SCAN_STEP;');f.write_text(s)

(P/'src/haar/gray_thumbnail.v').write_text('''`timescale 1ns/1ps
// Anti-aliased 8x8 average. Stores only one partial-sum row, not another frame.
module gray_thumbnail #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,input valid_i,input [10:0] x_i,input [9:0] y_i,input [7:0] gray_i,
 output reg valid_o,output reg [7:0] gray_o
);
 (* ram_style="block" *) reg [13:0] column_sum[0:WIDTH/8-1];
 reg [13:0] column_q;reg [10:0] row_sum;
 wire [13:0] full_sum=((y_i[2:0]==0)?14'd0:column_q)+{3'b0,row_sum}+{6'b0,gray_i};
 wire [13:0] rounded=full_sum+14'd32;
 always @(posedge clk)begin
  if(x_i<WIDTH)column_q<=column_sum[x_i[10:3]];
  if(valid_i&&x_i<WIDTH&&y_i<HEIGHT&&x_i[2:0]==7)column_sum[x_i[10:3]]<=full_sum;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin row_sum<=0;valid_o<=0;gray_o<=0;end
 else begin
  valid_o<=0;
  if(valid_i&&x_i<WIDTH&&y_i<HEIGHT)begin
   if(x_i[2:0]==0)row_sum<=gray_i;else row_sum<=row_sum+gray_i;
   if(x_i[2:0]==7&&y_i[2:0]==7)begin valid_o<=1;gray_o<=rounded[13:6];end
  end
 end
endmodule
''',encoding='utf-8')
change('src/haar/haar_face_video.v','// Centre sampling on an 8-pixel lattice. The complete snapshot is immutable while busy.','// Each sample averages its complete 8x8 tile. Snapshot remains immutable while busy.')
change('src/haar/haar_face_video.v','reg test_done,test_capture,self_ok;','reg [1:0] next_phase,capture_phase;\n reg test_done,test_capture,self_ok;')
change('src/haar/haar_face_video.v','wire sample=gv&&gx[2:0]==4&&gy[2:0]==4&&gx<1280&&gy<720;','wire sample;wire [7:0] thumbnail_pixel;\n gray_thumbnail #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) thumbnail(clk,rst_n,gv,gx,gy,gray,sample,thumbnail_pixel);')
change('src/haar/haar_face_video.v','if(!rst_n)begin capturing<=0;','if(!rst_n)begin next_phase<=0;capture_phase<=0;capturing<=0;')
change('src/haar/haar_face_video.v','   start<=0;\n','   start<=0;\n   if(hd&&!test_capture)next_phase<=next_phase+1\'b1;\n')
change('src/haar/haar_face_video.v','test_capture<=!test_done;end','test_capture<=!test_done;capture_phase<=test_done?next_phase:2\'b00;end')
change('src/haar/haar_face_video.v','haar_engine core(.clk(clk)','haar_engine core(.scan_phase(capture_phase),.clk(clk)')
change('src/haar/haar_face_video.v','test_capture?{test_q,test_q}:gray','test_capture?{test_q,test_q}:thumbnail_pixel')
change('src/haar/haar_face_video.v','wire tracker_busy,tracker_overrun;','wire tracker_busy,tracker_overrun;reg publish_pending;\n wire tracker_send=publish_pending&&!tracker_busy;')
change('src/haar/haar_face_video.v','.result_valid(hd&&!test_capture)','.result_valid(tracker_send)')
change('src/haar/haar_face_video.v','   work_count<=0;overrun<=0;','   publish_pending<=0;work_count<=0;overrun<=0;')
change('src/haar/haar_face_video.v','   if(start)work_count<=0;','   if(tracker_send)publish_pending<=0;\n   if(start)begin work_count<=0;publish_pending<=0;end')
change('src/haar/haar_face_video.v','     if(work_count<MAX_FACES)begin','     if(work_count<MAX_FACES)begin\n       publish_pending<=1;')
change('Ti60_Demo.xml','        <efx:design_file name="src/haar/haar_box_tracker.v"','        <efx:design_file name="src/haar/gray_thumbnail.v" version="default" library="default" />\n        <efx:design_file name="src/haar/haar_box_tracker.v"')
change('tools/run_tests.ps1',"'src/haar/haar_engine.v',","'src/haar/haar_engine.v','src/haar/gray_thumbnail.v',")
change('tools/run_tests.ps1',"'tb/tb_haar_tracker.v'","'tb/tb_haar_tracker.v','tb/tb_gray_thumbnail.v'")
for name in ['tools/run_tests.ps1','tools/program_jtag.ps1','tools/record_verified_build.py']:
 change(name,"'tb_haar_tracker'","'tb_haar_tracker','tb_gray_thumbnail'")
change('tools/haar_reference.cpp','for(int y=0;y+24<H;y+=step)for(int x=0;x+24<W;x+=step)','for(int y=(argc>6?stoi(argv[6]):0);y+24<H;y+=step)for(int x=(argc>5?stoi(argv[5]):0);x+24<W;x+=step)')
print('Saved stable image and applied averaging, phase coverage, pipelined reads, early publication.')
