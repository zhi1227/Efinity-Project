`timescale 1ns/1ps
// Stable snapshot -> asynchronous-to-raster Haar work -> atomic frame-boundary boxes.
module haar_face_video #(parameter WIDTH=1280,HEIGHT=720,H_TOTAL=1650,MAX_FACES=8,DIAGNOSTICS=1,SELF_TEST=1,HOLD_FRAMES=36,SELF_EXPECTED=11)(
 input clk,rst_n,input [23:0] rgb_i,input de_i,vs_i,hs_i,
 input [2:0] mode_i,input [11:0] low_i,high_i,
 output reg [23:0] rgb_o,output reg de_o,vs_o,hs_o,output reg overrun
);
 reg [10:0] x;reg [9:0] y;reg vs_q;
 wire fs=vs_i&&!vs_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin x<=0;y<=0;vs_q<=1;end
 else begin vs_q<=vs_i;if(!vs_i)begin x<=0;y<=0;end
 else if(de_i)begin if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end end
 wire [15:0] rgb565={rgb_i[23:19],rgb_i[15:10],rgb_i[7:3]};
 wire [7:0] gray;wire gv;wire [10:0] gx;wire [9:0] gy;
 rgb565_to_gray gray_inst(clk,rst_n,de_i,x,y,rgb565,gray,gv,gx,gy);
 wire [71:0] sw;wire wv,ev;wire [10:0] wx,ex;wire [9:0] wy,ey;wire [11:0] mag;wire [1:0] dir;
 line_buffer_3x3 #(.WIDTH(WIDTH),.DWIDTH(8)) win(clk,rst_n,fs,gv,gx,gy,gray,sw,wv,wx,wy);
 sobel3x3 sobel(clk,rst_n,wv,wx,wy,sw,mag,dir,ev,ex,ey);
 localparam DELAY=H_TOTAL+1+4;
 wire [39:0] aligned;
 video_delay #(.BITS(40),.LATENCY(DELAY)) delay_video(clk,rst_n,{vs_i,hs_i,de_i,y,x,rgb565},aligned);
 wire avs=aligned[39],ahs=aligned[38],ade=aligned[37];wire [9:0] ay=aligned[36:27];wire [10:0] ax=aligned[26:16];
 wire [23:0] argb;rgb565_to_rgb888 expand(aligned[15:0],argb);
 reg avs_q;wire display_fs=avs&&!avs_q;reg [2:0] active_mode;reg [11:0] active_threshold;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin avs_q<=1;active_mode<=1;active_threshold<=80;end
 else begin avs_q<=avs;if(display_fs)begin active_mode<=mode_i;active_threshold<=high_i;end end
 wire edge_on=ev&&ade&&ex==ax&&ey==ay&&mag>=active_threshold;
 // Each sample averages its complete 8x8 tile. Snapshot remains immutable while busy.
 reg capturing,start;reg [13:0] capture_addr;reg [31:0] frame_id,captured_id;
 reg [1:0] next_phase,capture_phase;
 reg test_done,test_capture,self_ok;reg [15:0] self_raw;
 (* ram_style="block" *) reg [3:0] test_rom[0:14399];reg [3:0] test_q;
 initial $readmemh("model/selftest.mem",test_rom);
 always @(posedge clk)test_q<=test_rom[capture_addr];
 wire [4:0] max_stage;wire [5:0] debug_state;wire [7:0] preview_pixel;
 wire [13:0] preview_addr=(ay<94&&ay>=4&&ax>=1116&&ax<1276)?(ay-4)*160+ax-1116:0;
 wire hb,hd,dv;wire [10:0] dx;wire [9:0] dy,ds;wire [31:0] elapsed;wire [15:0] raw_count;
 wire sample;wire [7:0] thumbnail_pixel;
 gray_thumbnail #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) thumbnail(clk,rst_n,gv,gx,gy,gray,sample,thumbnail_pixel);
 wire load_we=capturing&&sample&&!hb;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin next_phase<=0;capture_phase<=0;capturing<=0;start<=0;capture_addr<=0;frame_id<=0;captured_id<=0;test_done<=!SELF_TEST;test_capture<=0;self_ok<=0;self_raw<=0;end
 else begin
   start<=0;
   if(hd&&!test_capture)next_phase<=next_phase+1'b1;
   if(hd&&test_capture)begin test_done<=1;self_raw<=raw_count;self_ok<=raw_count==SELF_EXPECTED;end
   if(fs)begin frame_id<=frame_id+1'b1;
     if(!hb&&!capturing&&!start)begin capturing<=1;capture_addr<=0;captured_id<=frame_id+1'b1;test_capture<=!test_done;capture_phase<=test_done?((hd&&!test_capture)?next_phase+2'd1:next_phase):2'b00;end
     else if(capturing)begin capture_addr<=0;captured_id<=frame_id+1'b1;end
   end
   if(load_we)begin
     if(capture_addr==14399)begin capturing<=0;start<=1;end
     else capture_addr<=capture_addr+1'b1;
   end
 end
 haar_engine core(.scan_phase(capture_phase),.clk(clk),.rst_n(rst_n),.load_we(load_we),.load_addr(capture_addr),.load_pixel(test_capture?{test_q,test_q}:thumbnail_pixel),.start(start),
 .busy(hb),.done(hd),.det_valid(dv),.det_x(dx),.det_y(dy),.det_size(ds),.cycles(elapsed),.raw_count(raw_count),.debug_addr(preview_addr),.debug_pixel(preview_pixel),.max_stage(max_stage),.debug_state(debug_state));
 // Greedy overlap clustering; every accepted candidate has passed all 25 stages.
 // Retain up to 8 clusters. Count overflow explicitly; never write past capacity.
 reg [3:0] work_count;wire [3:0] display_count;
 reg [10:0] bx0[0:MAX_FACES-1],bx1[0:MAX_FACES-1];reg [9:0] by0[0:MAX_FACES-1],by1[0:MAX_FACES-1];
 wire [MAX_FACES*42-1:0] work_boxes,display_boxes;wire [MAX_FACES-1:0] display_mask;
 wire tracker_busy,tracker_overrun;reg publish_pending;
 wire tracker_send=publish_pending&&!tracker_busy;
 genvar bi;generate for(bi=0;bi<MAX_FACES;bi=bi+1)begin:pack_boxes
  assign work_boxes[bi*42+:42]={by1[bi],by0[bi],bx1[bi],bx0[bi]};
 end endgenerate
 haar_box_tracker #(.MAX_FACES(MAX_FACES),.HOLD_FRAMES(HOLD_FRAMES)) tracker(
  .clk(clk),.rst_n(rst_n),.frame_start(display_fs),.result_valid(tracker_send),
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
   publish_pending<=0;work_count<=0;overrun<=0;last_cycles<=0;last_raw<=0;completed<=0;
   for(j=0;j<MAX_FACES;j=j+1)begin bx0[j]<=0;bx1[j]<=0;by0[j]<=0;by1[j]<=0;end
 end else begin
   if(tracker_send)publish_pending<=0;
   if(start)begin work_count<=0;publish_pending<=0;end
   if(tracker_overrun)overrun<=1;
   if(dv&&!matched&&!test_capture)begin
     if(work_count<MAX_FACES)begin
       publish_pending<=1;
       bx0[work_count]<=dx;bx1[work_count]<=(dx+ds>WIDTH)?WIDTH-1:dx+ds-1;
       by0[work_count]<=dy;by1[work_count]<=(dy+ds>HEIGHT)?HEIGHT-1:dy+ds-1;work_count<=work_count+1'b1;
     end else overrun<=1;
   end
   if(hd&&!test_capture)begin
     last_cycles<=elapsed;last_raw<=raw_count;completed<=completed+1'b1;
   end
 end
 reg inside_face,border;reg [10:0] x0,x1;reg [9:0] y0,y1;integer k;
 always @*begin
  inside_face=0;border=0;x0=0;x1=0;y0=0;y1=0;
  for(k=0;k<MAX_FACES;k=k+1)if(display_mask[k])begin
   x0=display_boxes[k*42+:11];x1=display_boxes[k*42+11+:11];y0=display_boxes[k*42+22+:10];y1=display_boxes[k*42+32+:10];
   if(ax>=x0&&ax<=x1&&ay>=y0&&ay<=y1)begin
    inside_face=1;if(ax-x0<2||x1-ax<2||ay-y0<2||y1-ay<2)border=1;
   end
  end
 end
 wire [7:0] luminance=(argb[23:16]>>2)+(argb[15:8]>>1)+(argb[7:0]>>2);

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

 reg [23:0] color;
 always @*begin
   case(active_mode)
    0:color=argb;
    1:color=border?24'h00ff00:((inside_face&&edge_on)?24'hffffff:argb);
    2:color=border?24'h00ff00:((inside_face&&edge_on)?24'hffffff:{luminance,luminance,luminance});
    3:color=border?24'hff0000:((inside_face&&edge_on)?24'hffffff:24'h000000);
    default:color=edge_on?24'hffffff:24'h000000;
   endcase
   if(DIAGNOSTICS)begin
    if(ax>=4&&ax<272&&ay>=4&&ay<24)color=osd_on?24'hffffff:(self_ok?24'h003000:24'h500000);
    if(ax>=1115&&ax<=1276&&ay>=3&&ay<=94)color=(ax==1115||ax==1276||ay==3||ay==94)?24'h00ffff:{preview_pixel,preview_pixel,preview_pixel};
   end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=ade?color:24'd0;de_o<=ade;vs_o<=avs;hs_o<=ahs;end
endmodule
