`timescale 1ns/1ps
module tb_menu8_pixels;
 reg clk=0,reset=1,visible=0,tick=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[639:0]state=0;
 wire[23:0]rgb,local_rgb,health_rgb;wire de,local_de,health_de;
 wire[12:0]addr;wire[15:0]bits;
 shared_glyph_rom rom(clk,13'd0,,clk,addr,bits);
 menu8_renderer #(.SHARED_FONT(1)) dut(clk,reset,x,y,visible,state,rgb,de,addr,bits,tick);
 menu8_renderer local_dut(clk,reset,x,y,visible,state,local_rgb,local_de,,16'd0,tick);
 wire[639:0]flipped_health=state^640'hff0;
 menu8_renderer health_dut(clk,reset,x,y,visible,flipped_health,health_rgb,health_de,,16'd0,tick);
 always @(negedge clk)if(!reset)begin
  if(de!==local_de||de!==health_de||rgb!==local_rgb||rgb!==health_rgb)$fatal(1,"font parity / health dependency %d,%d",x,y);
  if(de&&(^rgb===1'bx))$fatal(1,"Unknown UI pixel");
 end
 integer f,scenario,mode,px,py,n,numbers,face_digits,card_labels;
 reg[9:0]last_flow;
 task frame_tick;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
 task save_pixel;begin
  if(de)begin
   $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
   if(n%1024>=144&&n%1024<400&&n/1024>=228&&n/1024<356&&rgb==24'hecf4ff)numbers=numbers+1;
   if(n%1024>=432&&n%1024<560&&n/1024>=390&&n/1024<454&&rgb==24'h65dbab)face_digits=face_digits+1;
   if(n/1024>=280&&n/1024<296&&n%1024>=48&&n%1024<976&&(rgb==24'ha3b5cd||rgb==24'hffffff))card_labels=card_labels+1;
   n=n+1;
  end
 end endtask
 initial begin
  repeat(4)@(negedge clk);reset=0;
  // Real frame pulses only: no active-raster movement, bounded wrap, retargeting.
  state[2:0]=1;repeat(3)frame_tick();if(dut.flow_pos!=36)$fatal(1,"waterfall did not advance twelve pixels per frame");
  last_flow=dut.flow_pos;repeat(100)@(negedge clk);if(dut.flow_pos!=last_flow)$fatal(1,"animation moved without frame pulse");
  state[2:0]=2;repeat(40)frame_tick();if(dut.flow_pos!=232)$fatal(1,"rapid retarget failed");
  state[2:0]=7;repeat(40)frame_tick();if(dut.flow_pos!=812)$fatal(1,"last mode rail position");
  state[2:0]=0;repeat(9)frame_tick();if(dut.flow_pos!=920)$fatal(1,"wrap should travel forward, not jump backward");
  frame_tick();if(dut.flow_pos!=0)$fatal(1,"wrap landing");
  for(scenario=0;scenario<17;scenario=scenario+1)begin
   mode=scenario<8?scenario:6;
   if(scenario==15)mode=1;if(scenario==16)mode=0;
   state=0;state[2:0]=mode;state[11:4]=255;state[48:37]=40+mode;state[60:49]=80+mode;
   state[62:61]=mode%3;state[64:63]=mode%3;state[14]=1;state[19:16]=mode==6?8:0;state[15]=mode==6;
   if(scenario>=8&&scenario<12)begin state[15]=0;state[19:16]=scenario==8?0:3;state[3]=scenario==10;state[14]=scenario!=11;end
   if(scenario>=12&&scenario<=14)begin
    state[123]=1;state[48:37]=scenario==13?2000:scenario==14?41:40;
    state[60:49]=scenario==13?2040:scenario==14?81:80;
    state[62:61]=scenario==12?0:scenario==13?2:1;state[64:63]=scenario==13?2:0;
   end
   if(mode==7)begin
    state[116:113]=15;
    for(integer k=0;k<4;k=k+1)begin
     state[128+k*128+96+:2]=k;state[128+k*128+72+:12]=40+k*10;
     state[128+k*128+84+:12]=80+k*10;state[128+k*128+24+:32]=32'h12345670+k;
    end
   end
   if(scenario==15)begin state[2:0]=0;repeat(40)frame_tick();state[2:0]=1;repeat(3)frame_tick();end
   else if(scenario==16)begin state[2:0]=7;repeat(40)frame_tick();state[2:0]=0;repeat(3)frame_tick();end
   else repeat(40)frame_tick();
   last_flow=dut.flow_pos;
   f=$fopen($sformatf("reports/menu_%0d.ppm",scenario),"wb");if(!f)$fatal(1,"PPM open");
   $fwrite(f,"P6\n1024 600\n255\n");n=0;numbers=0;face_digits=0;card_labels=0;
   for(py=0;py<600;py=py+1)for(px=0;px<1024;px=px+1)begin
    @(negedge clk);save_pixel();x=px;y=py;visible=1;
    if(dut.flow_pos!=last_flow)$fatal(1,"flow tearing inside raster");
   end
   @(negedge clk);save_pixel();visible=0;
   repeat(4)begin @(negedge clk);save_pixel();end
   $fclose(f);
   if(n!=614400)$fatal(1,"pixel count");
   if(state[123]&&(numbers<500||card_labels!=0))$fatal(1,"full settings page missing large digits or leaking cards");
   if(!state[123]&&(card_labels<150||(mode==6&&face_digits<40)||(mode!=6&&face_digits!=0)))$fatal(1,"mode labels / gated count scenario %0d face %0d",scenario,face_digits);
   $display("PASS: UI scenario %0d mode %0d settings %0d digits %0d face %0d cards %0d",scenario,mode,state[123],numbers,face_digits,card_labels);
  end
  $display("PASS: all eight UI modes, independent full-screen thresholds, live values, face 8+/0/3/frozen/invalid, frame-based flow/wrap/retargeting, shared/local parity, health-independent output");$finish;
 end
endmodule
