`timescale 1ns/1ps
module tb_h5_raster;
 reg clk=0,rst=0,en=1,mode_on=1,de=0,vs=0,hs=0,vsq=1,ks=0,kl=0;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov,busy,pv;wire[41:0]box;wire[2:0]g,dc,step,state,trained;
 wire[3:0]fault;wire[1:0]err;wire[255:0]preview;
 raster_xy #(.WIDTH(320)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(320),.HEIGHT(240),.H_TOTAL(400),.WIZ_COUNTDOWN(2),.WIZ_SETTLE(4),.WIZ_TIMEOUT(32)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.mode_on(mode_on),.rgb(rgb),.de(de),.vs(vs),.hs(hs),.fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),
 .box_valid(bv),.box(box),.gesture(g),.overflow(ov),.debug_fault(fault),.debug_class(dc),
 .key_short(ks),.key_long(kl),.learn_busy(busy),.learn_step(step),.learn_state(state),.learn_error(err),.trained(trained),.preview(preview),.preview_valid(pv));
 integer n,v,h,xx,yy,kind=0,offset=0,limit,tilt=0,fallbacks=0;reg hand,wave_seen=0;
 task pulse(input bit long_key);begin @(negedge clk);ks=!long_key;kl=long_key;@(negedge clk);ks=0;kl=0;end endtask
 task frame;begin
  for(v=0;v<270;v=v+1)for(h=0;h<400;h=h+1)begin
   @(negedge clk);vs=v>=3;hs=h>=4;de=v>=15&&v<255&&h>=40&&h<360;xx=h-40-offset;yy=v-15;hand=0;if(kind==8&&yy<110)xx=xx-tilt*(110-yy)/60;
   case(kind)
    1:hand=(xx>=110&&xx<210&&yy>=104&&yy<170)||
      (yy>=50&&yy<112&&((xx>=113&&xx<127)||(xx>=139&&xx<153)||(xx>=165&&xx<179)||(xx>=191&&xx<205)));
    2:hand=(xx>=120&&xx<144&&yy>=48&&yy<108)||(xx>=116&&xx<204&&yy>=104&&yy<174);
    3:hand=(yy>=48&&yy<86&&((xx>=132&&xx<149)||(xx>=165&&xx<182)))||
      (xx>=132&&xx<182&&yy>=82&&yy<98)||(xx>=116&&xx<204&&yy>=92&&yy<174);
    8:hand=(yy>=110&&yy<170&&xx>=95&&xx<225)||
      (yy>=50&&yy<115&&((xx>=110&&xx<128)||(xx>=150&&xx<168)||(xx>=190&&xx<208)));
    4:hand=xx>=110&&xx<210&&yy>=90&&yy<170;
   endcase
   // Bright pale fingers + darker palm: H3 discarded the pale colour.
   rgb=de&&hand?(yy<104?24'hE6D6C9:24'hC88C6E):24'h204080;
  end
  if(ov||fault||g>3)$fatal(1,"Pipeline fault %h / result %0d",fault,g);
 end endtask
 task enrol(input integer id);begin
  kind=id;offset=0;repeat(3)frame();pulse(0);limit=0;
  while(busy&&step==id&&limit<28)begin
   frame();limit=limit+1;
   if(state==6)$fatal(1,"Enrol %0d error %0d, mask%h count%0d distances%0d/%0d/%0d",id,err,preview,dut.templates.ones,dut.templates.d1,dut.templates.d2,dut.templates.d3);
  end
  if(limit>=28)$fatal(1,"Enrol %0d timeout state%0d valid%b/%b",id,state,bv,pv);
  $display("Enrolled %0d in %0d frames",id,limit);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;kind=2;repeat(6)frame();if(g||dc)$fatal(1,"Untrained result");
  pulse(1);enrol(1);enrol(2);enrol(3);if(trained!=7||busy)$fatal(1,"Three samples missing");
  kind=2;repeat(11)frame();if(g!=2||dc!=2)$fatal(1,"RGB thumb match %0d/%0d",g,dc);
  kind=3;repeat(11)frame();if(g!=3||dc!=3)$fatal(1,"RGB heart match %0d/%0d",g,dc);
  kind=4;repeat(11)frame();if(g)$fatal(1,"Untrained fist triggered");
  kind=1;repeat(11)frame();if(g||dc!=1)$fatal(1,"Static palm behavior %0d/%0d",g,dc);
  for(n=0;n<10;n=n+1)begin offset=n%2;frame();if(g)$fatal(1,"Jitter wave");end
  for(n=0;n<=8;n=n+1)begin offset=n*2;frame();if(g==1)wave_seen=1;end
  for(n=0;n<=16;n=n+1)begin offset=16-n*2;frame();if(g==1)wave_seen=1;end
  for(n=0;n<=16;n=n+1)begin offset=-16+n*2;frame();if(g==1)wave_seen=1;end
  if(!wave_seen)$fatal(1,"Learned palm motion failed WAVE");
  // Palm changes its spread/outline relative to recorded template. Broad base
  // fixes the bbox while three separated upper fingers lean left and right.
  kind=0;offset=0;repeat(6)frame();kind=8;tilt=0;repeat(8)frame();
  if(dc!=1)$fatal(1,"Different open palm not admitted by independent evidence");
  wave_seen=0;
  for(n=0;n<=6;n=n+1)begin
   tilt=n*2;frame();if(dc==1&&dut.template_class!=1)fallbacks=fallbacks+1;
   $display("WRIST tilt=%0d cls=%0d lean=%0d phase=%0d dir=%0d extreme=%0d credit=%0d cx=%0d",tilt,dc,dut.palm_lean,dut.wave.phase,dut.wave.dir_l,dut.wave.extreme_l,dut.wave.credit,dut.wave.cx);
   if(g==1)wave_seen=1;
  end
  for(n=0;n<=12;n=n+1)begin
   tilt=12-n*2;frame();if(dc==1&&dut.template_class!=1)fallbacks=fallbacks+1;
   $display("WRIST tilt=%0d cls=%0d lean=%0d phase=%0d dir=%0d extreme=%0d credit=%0d cx=%0d",tilt,dc,dut.palm_lean,dut.wave.phase,dut.wave.dir_l,dut.wave.extreme_l,dut.wave.credit,dut.wave.cx);
   if(g==1)wave_seen=1;
  end
  for(n=0;n<=12;n=n+1)begin
   tilt=-12+n*2;frame();if(dc==1&&dut.template_class!=1)fallbacks=fallbacks+1;
   $display("WRIST return=%0d cls=%0d lean=%0d phase=%0d dir=%0d cx=%0d",tilt,dc,dut.palm_lean,dut.wave.phase,dut.wave.dir_l,dut.wave.cx);
   if(dut.wave.cx!=159||dut.wave.dir_x!=0)$fatal(1,"Wrist test unexpectedly translated bbox");
   if(g==1)wave_seen=1;
  end
  repeat(3)begin frame();if(g==1)wave_seen=1;end
  if(!wave_seen||fallbacks==0)$fatal(1,"Wrist/fallback missed wave%0d evidence_frames%0d",wave_seen,fallbacks);
  $display("Independent evidence used on %0d tilted-palm frames",fallbacks);
  kind=0;repeat(6)frame();if(g||bv)$fatal(1,"Stale removal");
  en=0;repeat(3)@(negedge clk);if(g||bv||trained!=7)$fatal(1,"Freeze retention");
  en=1;kind=2;offset=0;repeat(11)frame();if(g!=2)$fatal(1,"Recognition after resume");
  mode_on=0;en=0;repeat(3)@(negedge clk);if(trained!=7)$fatal(1,"Mode exit erased models");
  $display("PASS: H5 RGB-to-template button enrollment and changed-shape wrist-wave; multi-tone fingers; learned thumb/heart/dynamic wave; static/jitter/fist/blank rejection; freeze and mode persistence");$finish;
 end
endmodule
