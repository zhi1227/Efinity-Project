`timescale 1ns/1ps
module tb_gesture_integration;
 reg clk=0,rst=0,de=0,vs=0,hs=0,freeze=0,pure_en=0;always #5 clk=~clk;
 reg[23:0]rgb=0;reg[7:0]health=8'hFF,lo=10;
 parallel_video #(.WIDTH(128),.HEIGHT(96),.H_TOTAL(160),.CANNY_GAUSSIAN(1),.HUD_ENABLE(1))dut(
 .clk(clk),.rst_n(rst),.rgb_i(rgb),.de_i(de),.vs_i(vs),.hs_i(hs),.mode_i(4'd15),.low_i(12'd40),.high_i(12'd80),
 .freeze_i(freeze),.pure_i(pure_en),.detect_i(1'b1),.skin_lower_i(lo),.health_i(health));
 integer n,h,v,xx,yy;
 task frame;begin
  for(v=0;v<120;v=v+1)for(h=0;h<160;h=h+1)begin
   @(posedge clk);#1;vs=v>=3;hs=h>=4;de=v>=15&&v<111&&h>=12&&h<140;xx=h-12;yy=v-15;
   rgb=de&&((xx>=42&&xx<54&&yy>=20&&yy<48)||(xx>=38&&xx<86&&yy>=46&&yy<74))?24'hC88C6E:24'h204080;
  end
 end endtask
 task idle_check;if(dut.hand_valid||dut.gesture!=0)$fatal(1,"Stale gesture on disabled/unhealthy pipeline");endtask
 initial begin
  repeat(5)@(posedge clk);#1;rst=1;
  for(n=0;n<10;n=n+1)frame();
  if(!dut.hand_valid||dut.gesture!=2||dut.detect_active)$fatal(1,"Integrated hand/face gating failed");
  health[6]=0;repeat(4)@(posedge clk);#1;idle_check();
  health=8'hFF;for(n=0;n<10;n=n+1)frame();
  if(dut.gesture!=2)$fatal(1,"Reacquisition failed");
  freeze=1;frame();idle_check();freeze=0;
  for(n=0;n<10;n=n+1)frame();
  if(dut.gesture!=2)$fatal(1,"Thaw reacquisition failed");
  lo=85;frame();idle_check();
  lo=10;for(n=0;n<10;n=n+1)frame();
  if(dut.gesture!=2)$fatal(1,"Threshold reacquisition failed");
  pure_en=1;frame();idle_check();
  $display("PASS: integrated gesture gating on lost frame, freeze, parameter change, pure capture; face count disabled");$finish;
 end
endmodule
