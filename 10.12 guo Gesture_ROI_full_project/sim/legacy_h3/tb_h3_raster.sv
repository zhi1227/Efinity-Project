`timescale 1ns/1ps
module tb_h3_raster;
 reg clk=0,rst=0,en=1,de=0,vs=0,hs=0,vsq=1;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov;wire[41:0]box;wire[2:0]g,dc;
 wire[3:0]fault;wire[19:0]raw,clean;
 raster_xy #(.WIDTH(320)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(320),.HEIGHT(240),.H_TOTAL(400)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.rgb(rgb),.de(de),.vs(vs),.hs(hs),.fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),
 .box_valid(bv),.box(box),.gesture(g),.overflow(ov),.debug_fault(fault),.debug_class(dc),.debug_raw(raw),.debug_clean(clean));
 integer n,v,h,xx,yy,kind=0,offset=0;reg hand,wave_seen=0;
 task frame;begin
  for(v=0;v<270;v=v+1)for(h=0;h<400;h=h+1)begin
   @(negedge clk);vs=v>=3;hs=h>=4;de=v>=15&&v<255&&h>=40&&h<360;xx=h-40-offset;yy=v-15;hand=0;
   case(kind)
    1:hand=(xx>=110&&xx<210&&yy>=110&&yy<170)||
      (yy>=50&&yy<115&&((xx>=113&&xx<127)||(xx>=139&&xx<153)||(xx>=165&&xx<179)||(xx>=191&&xx<205)));
    2:hand=(xx>=120&&xx<144&&yy>=48&&yy<108)||(xx>=116&&xx<204&&yy>=104&&yy<174);
    3:hand=(yy>=48&&yy<86&&((xx>=132&&xx<149)||(xx>=165&&xx<182)))||
      (xx>=132&&xx<182&&yy>=82&&yy<98)||(xx>=116&&xx<204&&yy>=92&&yy<174);
    4:hand=xx>=110&&xx<210&&yy>=90&&yy<170; // plain fist: no output
    5:hand=(xx>=152&&xx<168&&yy>=30&&yy<108)||(xx>=116&&xx<204&&yy>=104&&yy<174); // centred index
    6:hand=(yy>=30&&yy<108&&((xx>=120&&xx<139)||(xx>=180&&xx<199)))||
      (xx>=116&&xx<204&&yy>=104&&yy<174); // V: no output
    7:hand=xx>=80&&xx<220&&yy>=0&&yy<240; // clipped at guide: no output
   endcase
   rgb=de&&(hand||(h-40<55&&h>=40))?24'hC88C6E:24'h204080;
  end
  if(ov||fault||g>3)$fatal(1,"Pipeline fault or removed output %h %0d",fault,g);
 end endtask
 task check(input integer what,input[2:0]expected,raw_expected);begin
  kind=what;offset=0;
  for(n=0;n<11;n=n+1)frame();
  if(g!=expected||dc!=raw_expected)$fatal(1,"H3 kind=%0d result=%0d/raw=%0d expected=%0d/%0d F=%0d R=%0d one/two/many=%0d/%0d/%0d thumb/solid/cross/join=%0d/%0d/%0d/%0d",what,g,dc,expected,raw_expected,dut.fill,dut.ratio,dut.one_votes,dut.two_votes,dut.many_votes,dut.thumb_votes,dut.solid_votes,dut.cross_votes,dut.join_votes);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  check(2,2,2);check(3,3,3);check(4,0,0);check(5,0,0);check(6,0,0);check(7,0,0);check(0,0,0);
  check(1,0,1); // stationary open palm is evidence, not WAVE
  for(n=0;n<20;n=n+1)begin offset=n%3;frame();if(g)$fatal(1,"Small palm jitter triggered WAVE");end
  for(n=0;n<=10;n=n+1)begin offset=n*2;frame();if(g==1)wave_seen=1;end
  for(n=0;n<=20;n=n+1)begin offset=20-n*2;frame();if(g==1)wave_seen=1;end
  for(n=0;n<=20;n=n+1)begin offset=-20+n*2;frame();if(g==1)wave_seen=1;end
  if(!wave_seen)$fatal(1,"RGB palm motion failed to produce WAVE");
  kind=0;offset=0;for(n=0;n<5;n=n+1)frame();if(g||bv)$fatal(1,"Removal stale result");
  en=0;repeat(3)@(negedge clk);if(g||bv)$fatal(1,"Disable stale");
  $display("PASS: end-to-end RGB H3 thumb-up, short crossed-finger silhouette, dynamic wave; static palm/jitter/fist/index/V/clipping/background rejected; bounded removal");$finish;
 end
endmodule
