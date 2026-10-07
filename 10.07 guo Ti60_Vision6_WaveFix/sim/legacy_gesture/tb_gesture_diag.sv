`timescale 1ns/1ps
module tb_gesture_diag;
 reg clk=0,rst=0,en=1,de=0,vs=0,hs=0,vsq=0;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov,sk,sv;wire[41:0]box;wire[1:0]g,dc;
 wire[19:0]raw,clean,ratio;wire[9:0]fill;wire[3:0]rejects,fault;
 reg[7:0]lower=10;integer scene=0,n,v,h,xx,yy;
 raster_xy #(.WIDTH(128)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(128),.HEIGHT(96),.H_TOTAL(160)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.rgb(rgb),.de(de),.vs(vs),.hs(hs),.fs(vs&&!vsq),.x(x),.y(y),.skin_lower(lower),
 .box_valid(bv),.box(box),.gesture(g),.overflow(ov),.skin_raw(sk),.skin_valid(sv),
 .debug_raw(raw),.debug_clean(clean),.debug_fill(fill),.debug_ratio(ratio),.debug_reject(rejects),.debug_fault(fault),.debug_class(dc));
 task frame;reg shape;begin
  for(v=0;v<120;v=v+1)for(h=0;h<160;h=h+1)begin
   @(posedge clk);#1;vs=v>=3;hs=h>=4;de=v>=15&&v<111&&h>=12&&h<140;
   xx=h-12;yy=v-15;
   case(scene)
    0:shape=xx>=34&&xx<94&&yy>=18&&yy<78;
    1:shape=0;
    2:shape=xx>=50&&xx<70&&yy>=35&&yy<55;
    3:shape=xx>=0&&xx<90&&yy>=18&&yy<78;
    4:shape=xx>=40&&xx<88&&yy>=8&&yy<86;
    default:shape=0;
   endcase
   rgb=de&&shape?24'hC88C6E:24'h204080;
  end
 end endtask
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(n=0;n<5;n=n+1)frame();
  if(!bv||ov||g!=2||dc!=2||raw!=3600||clean<3500||clean>3600||fill<970||ratio!=1000||rejects||fault)
   $fatal(1,"fist stats bv=%d g=%d dc=%d raw=%d clean=%d F=%d R=%d reject=%h fault=%h",bv,g,dc,raw,clean,fill,ratio,rejects,fault);
  scene=1;frame();frame();
  if(raw||clean||bv||g||fault||rejects)$fatal(1,"empty mask stats stale");
  scene=2;frame();frame();
  if(raw!=400||clean==0||bv||g||!(rejects&2)||ov||fault)$fatal(1,"small candidate diagnostics raw=%d clean=%d rejects=%h",raw,clean,rejects);
  scene=3;frame();frame();
  if(raw!=5400||clean==0||bv||g||!(rejects&1)||ov||fault)$fatal(1,"border rejection diagnostics box=%h rejects=%h",box,rejects);
  scene=4;frame();frame();
  if(!bv||ov||g||dc||ratio!=1625||fill<970||fault)$fatal(1,"unknown geometry diagnostics F=%d R=%d",fill,ratio);
  en=0;repeat(4)@(posedge clk);#1;
  if(raw||clean||bv||g||rejects||fault)$fatal(1,"disabled stale diagnostics");
  en=1;scene=0;lower=85;frame();frame();
  if(raw||clean||bv||g)$fatal(1,"skin threshold diagnostics");
  $display("PASS: diagnostic counters, filtered mask, valid fist, empty/small/border/unknown, disabled and skin threshold cases");$finish;
 end
endmodule
