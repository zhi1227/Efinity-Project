`timescale 1ns/1ps
module tb_hand_720p;
 reg clk=0,rst=0,en=1,de=0,vs=0,hs=0,vsq=0;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov;wire[41:0]box;wire[2:0]g,dc;
 wire[19:0]raw,clean,ratio;wire[9:0]fill;wire[3:0]rejects,fault;
 raster_xy xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch dut(.clk(clk),.rst_n(rst),.enable(en),.rgb(rgb),.de(de),.vs(vs),.hs(hs),.fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),
 .box_valid(bv),.box(box),.gesture(g),.overflow(ov),.debug_raw(raw),.debug_clean(clean),.debug_fill(fill),.debug_ratio(ratio),
 .debug_reject(rejects),.debug_fault(fault),.debug_class(dc));
 integer n,v,h,xx,yy,aligned=0;
 always @(posedge clk)if(rst&&dut.raster[0]&&dut.aligned_clean)aligned=aligned+1;
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(n=0;n<13;n=n+1)begin
   for(v=0;v<750;v=v+1)for(h=0;h<1650;h=h+1)begin
    @(posedge clk);#1;vs=v>=5;hs=h>=40;de=v>=25&&v<745&&h>=260&&h<1540;xx=h-260;yy=v-25;
    rgb=de&&n<9&&((xx>=460&&xx<520&&yy>=180&&yy<290)||(xx>=400&&xx<620&&yy>=290&&yy<460))?24'hC88C6E:24'h204080;
   end
   if(n>=7&&n<9)begin
    if(!bv||ov||g!=2||dc!=2||raw!=44000||clean<43940||clean>44040||fill<710||fill>720||ratio!=1272||rejects||fault)
      $fatal(1,"720p hand failed n=%0d bv=%d g=%d raw=%d clean=%d fill=%d ratio=%d rejects=%h fault=%h",n,bv,g,raw,clean,fill,ratio,rejects,fault);
    if(box!=={10'd459,10'd180,11'd619,11'd400})$fatal(1,"720p box misalignment %h",box);
   end
   if(n==12&&(bv||g||raw||clean||ov||fault))$fatal(1,"720p removal stale result");
  end
  $display("PASS: thirteen full 1280x720 / 1650x750 rasters, exact raw count and box, filtered mask alignment, stable thumb-up with 5-of-7 vote, bounded removal");$finish;
 end
endmodule
