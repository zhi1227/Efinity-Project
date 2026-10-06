from pathlib import Path
import re,subprocess,json
P=Path(__file__).resolve().parents[1]
im=[int(x,16) for x in (P/'sim/positive.mem').read_text().split()]
(P/'model/selftest.mem').write_text('\n'.join(f'{v>>4:x}' for v in im)+'\n')
a=[(v>>4)*17 for v in im];gold=[]
for s,w,h in [(8,160,90),(10,128,72),(12,106,60),(16,80,45)]:
 f=P/f'sim/selftest{s}.raw';f.write_bytes(bytes(a[y*s//8*160+x*s//8] for y in range(h) for x in range(w)))
 r=subprocess.run([str(P/'tools/haar_reference.exe'),str(f),str(w),str(h),'2'],capture_output=True,text=True,check=True)
 gold.extend(r.stdout.splitlines())
print('SELF TEST EXPECTED RAW',len(gold));assert len(gold)>0
(P/'reports/selftest_expected.json').write_text(json.dumps({'raw_count':len(gold),'boxes_by_scale':gold},indent=2))
f=P/'src/haar/haar_engine.v';t=f.read_text(encoding='utf-8-sig')
t=t.replace('output reg [9:0] det_size,output reg [31:0] cycles,output reg [15:0] raw_count','output reg [9:0] det_size,output reg [31:0] cycles,output reg [15:0] raw_count,\n input [13:0] debug_addr,output reg [7:0] debug_pixel,output reg [4:0] max_stage,output [5:0] debug_state')
t=t.replace('pixel_q<=frame_mem[frame_ra];','pixel_q<=frame_mem[frame_ra];debug_pixel<=frame_mem[debug_addr];')
t=t.replace('reg [5:0] state;','reg [5:0] state;assign debug_state=state;')
t=t.replace('state<=IDLE;busy<=0;done<=0;','state<=IDLE;max_stage<=0;busy<=0;done<=0;')
t=t.replace('IDLE:if(start)begin busy<=1;','IDLE:if(start)begin max_stage<=0;busy<=1;')
t=t.replace('else if(stage==24)state<=DETECT;','else if(stage==24)begin max_stage<=25;state<=DETECT;end')
t=t.replace("else begin stage<=stage+1'b1;stage_sum<=0;", "else begin if(stage+1>max_stage)max_stage<=stage+1'b1;stage<=stage+1'b1;stage_sum<=0;")
f.write_text(t)
# Update algorithm test instance explicitly to account for debug interface.
f=P/'tb/tb_haar.v';t=f.read_text(encoding='utf-8-sig').replace('haar_engine dut(clk,rst_n,load_we,addr,pixel,start,busy,done,dv,x,y,s,cycles,raw);','haar_engine dut(.clk(clk),.rst_n(rst_n),.load_we(load_we),.load_addr(addr),.load_pixel(pixel),.start(start),.busy(busy),.done(done),.det_valid(dv),.det_x(x),.det_y(y),.det_size(s),.cycles(cycles),.raw_count(raw),.debug_addr(14\'d0));');f.write_text(t)
f=P/'src/haar/haar_face_video.v';t=f.read_text(encoding='utf-8-sig')
t=t.replace('MAX_FACES=8)(', 'MAX_FACES=8,DIAGNOSTICS=1,SELF_TEST=1)(')
t=t.replace('wire hb,hd,dv;', '''reg test_done,test_capture,self_ok;reg [15:0] self_raw;
 (* ram_style="block" *) reg [3:0] test_rom[0:14399];reg [3:0] test_q;
 initial $readmemh("model/selftest.mem",test_rom);
 always @(posedge clk)test_q<=test_rom[capture_addr];
 wire [4:0] max_stage;wire [5:0] debug_state;wire [7:0] preview_pixel;
 wire [13:0] preview_addr=(ay<94&&ay>=4&&ax>=1116&&ax<1276)?(ay-4)*160+ax-1116:0;
 wire hb,hd,dv;''')
t=t.replace('capture_addr<=0;frame_id<=0;captured_id<=0;end','capture_addr<=0;frame_id<=0;captured_id<=0;test_done<=!SELF_TEST;test_capture<=0;self_ok<=0;self_raw<=0;end')
t=t.replace("captured_id<=frame_id+1'b1;end", "captured_id<=frame_id+1'b1;test_capture<=!test_done;end",1)
t=t.replace('   start<=0;\n   if(fs)', "   start<=0;\n   if(hd&&test_capture)begin test_done<=1;self_raw<=raw_count;self_ok<=raw_count==16'd"+str(len(gold))+";end\n   if(fs)")
t=t.replace('haar_engine core(clk,rst_n,load_we,capture_addr,gray,start,hb,hd,dv,dx,dy,ds,elapsed,raw_count);', '''haar_engine core(.clk(clk),.rst_n(rst_n),.load_we(load_we),.load_addr(capture_addr),.load_pixel(test_capture?{test_q,test_q}:gray),.start(start),
 .busy(hb),.done(hd),.det_valid(dv),.det_x(dx),.det_y(dy),.det_size(ds),.cycles(elapsed),.raw_count(raw_count),.debug_addr(preview_addr),.debug_pixel(preview_pixel),.max_stage(max_stage),.debug_state(debug_state));''')
t=t.replace('if(dv&&!matched)', 'if(dv&&!matched&&!test_capture)')
t=t.replace('if(hd)begin\n     pending_count', 'if(hd&&!test_capture)begin\n     pending_count')
# Monochrome 4x6 characters expanded 2x. Line: SELF FFFF Sxx Rxx Bx
insert='''
 function [23:0] glyph; input [7:0] c; begin case(c)
 "0":glyph=24'h699996;"1":glyph=24'h262227;"2":glyph=24'h69124f;"3":glyph=24'he1619e;
 "4":glyph=24'h99f111;"5":glyph=24'hf8e19e;"6":glyph=24'h68e996;"7":glyph=24'hf11224;
 "8":glyph=24'h696996;"9":glyph=24'h699716;"A":glyph=24'h699f99;"B":glyph=24'he9e99e;
 "C":glyph=24'h788887;"D":glyph=24'he9999e;"E":glyph=24'hf8e88f;"F":glyph=24'hf8e888;
 "S":glyph=24'h78e11e;"T":glyph=24'hf22222;"R":glyph=24'he99ea9;"L":glyph=24'h88888f;
 "P":glyph=24'he99e88;"U":glyph=24'h999996;"N":glyph=24'h9db999;default:glyph=0;endcase end endfunction
 function [7:0] hexchar;input [3:0] v;begin hexchar=v<10?("0"+v):("A"+v-10);end endfunction
 reg [7:0] ch;reg [23:0] bits;reg osd_on;integer char_index,bit_index;
 always @*begin
  char_index=(ax-8)/10;ch=" ";
  case(char_index)
   0:ch="S";1:ch="E";2:ch="L";3:ch="F";4:ch=self_ok?"P":(test_done?"F":"R");
   6:ch="F";7:ch=hexchar(completed[15:12]);8:ch=hexchar(completed[11:8]);9:ch=hexchar(completed[7:4]);10:ch=hexchar(completed[3:0]);
   12:ch="S";13:ch=hexchar({3'b0,max_stage[4]});14:ch=hexchar(max_stage[3:0]);
   16:ch="R";17:ch=hexchar(last_raw[7:4]);18:ch=hexchar(last_raw[3:0]);
   20:ch="B";21:ch=hexchar(display_count);
   23:ch="T";24:ch=hexchar({2'b0,debug_state[5:4]});25:ch=hexchar(debug_state[3:0]);
  endcase
  bits=glyph(ch);bit_index=23-((ay-8)/2)*4-((ax-8)%10)/2;
  osd_on=ax>=8&&ax<268&&ay>=8&&ay<20&&((ax-8)%10)<8&&bits[bit_index];
 end
'''
t=t.replace(' reg [23:0] color;',insert+'\n reg [23:0] color;')
t=t.replace('   endcase\n end\n always @(posedge clk', '''   endcase
   if(DIAGNOSTICS)begin
    if(ax>=4&&ax<272&&ay>=4&&ay<24)color=osd_on?24'hffffff:(self_ok?24'h003000:24'h500000);
    if(ax>=1115&&ax<=1276&&ay>=3&&ay<=94)color=(ax==1115||ax==1276||ay==3||ay==94)?24'h00ffff:{preview_pixel,preview_pixel,preview_pixel};
   end
 end
 always @(posedge clk''')
f.write_text(t)
for name in ['tb_haar_video.v','tb_haar_integration.v']:
 f=P/'tb'/name;t=f.read_text(encoding='utf-8-sig').replace('haar_face_video dut','haar_face_video #(.DIAGNOSTICS(0),.SELF_TEST(0)) dut');f.write_text(t)
