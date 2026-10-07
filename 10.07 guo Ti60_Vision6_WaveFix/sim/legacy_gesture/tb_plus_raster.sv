`timescale 1ns/1ps
module tb_plus_raster;
 reg clk=0,rst=0,en=1,de=0,vs=0,hs=0,vsq=1;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov;wire[41:0]box;wire[2:0]g,dc;
 wire[3:0]fault;wire[19:0]raw,clean;
 raster_xy #(.WIDTH(320)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(320),.HEIGHT(240),.H_TOTAL(400)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.rgb(rgb),.de(de),.vs(vs),.hs(hs),.fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),
 .box_valid(bv),.box(box),.gesture(g),.overflow(ov),.debug_fault(fault),.debug_class(dc),.debug_raw(raw),.debug_clean(clean));
 integer n,v,h,xx,yy,kind=0,offset=0;reg hand;
 task frame;begin
  for(v=0;v<270;v=v+1)for(h=0;h<400;h=h+1)begin
   @(negedge clk);vs=v>=3;hs=h>=4;de=v>=15&&v<255&&h>=40&&h<360;xx=h-40-offset;yy=v-15;hand=0;
   case(kind)
    1:hand=(xx>=110&&xx<210&&yy>=110&&yy<170)||
      (yy>=50&&yy<115&&((xx>=113&&xx<127)||(xx>=139&&xx<153)||(xx>=165&&xx<179)||(xx>=191&&xx<205)));
    2:hand=xx>=110&&xx<210&&yy>=90&&yy<170;
    3:hand=(xx>=150&&xx<170&&yy>=50&&yy<125)||(xx>=135&&xx<185&&yy>=120&&yy<170);
    4:hand=(yy>=50&&yy<125&&((xx>=115&&xx<129)||(xx>=191&&xx<205)))||
      (xx>=112&&xx<208&&yy>=120&&yy<180);
    5:hand=xx>=80&&xx<220&&yy>=0&&yy<240; // crop touching ROI must never classify
    6:hand=(xx>=110&&xx<170&&yy>=80&&yy<180)||
      (xx>=165&&xx<230&&((yy>=83&&yy<97)||(yy>=109&&yy<123)||(yy>=135&&yy<149)||(yy>=161&&yy<175)));
   endcase
   // Distracting skin-coloured clothing left of the guide is larger than the hand.
   rgb=de&&(hand||(h-40<55&&h>=40))?24'hC88C6E:24'h204080;
  end
 end endtask
 task check(input integer what);begin
  kind=what;
  for(n=0;n<11;n=n+1)begin offset=(what==1)?n%3:0;frame();if(ov||fault)$fatal(1,"Pipeline overflow %h",fault);end
  if(g!=(what==6?1:what)||!bv)$fatal(1,"Raster class %0d expected %0d raw=%0d votes=%0d/%0d/%0d fill=%0d ratio=%0d box=%h",g,what,dc,dut.one_votes,dut.two_votes,dut.many_votes,dut.fill,dut.ratio,box);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  check(1);check(4);check(3);check(2);check(6);
  kind=5;for(n=0;n<5;n=n+1)frame();if(g||bv)$fatal(1,"ROI cut-off hand classified");
  kind=0;for(n=0;n<5;n=n+1)frame();if(g||bv)$fatal(1,"Clothing outside ROI classified");
  en=0;repeat(3)@(negedge clk);if(g||bv)$fatal(1,"Disable stale");
  $display("PASS: RGB -> chroma -> disk/closing -> aligned ROI CCL -> finger probes -> stable four static gestures; moving palm, clothing rejection, clipped hand rejection, removal");$finish;
 end
endmodule
