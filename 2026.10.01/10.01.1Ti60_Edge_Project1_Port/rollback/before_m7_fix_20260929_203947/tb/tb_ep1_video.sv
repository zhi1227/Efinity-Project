`timescale 1ns/1ps
module tb_ep1_video #(parameter FULL=0);
 localparam W=FULL?1280:32,H=FULL?720:24,HT=FULL?1650:56,VT=FULL?750:40;
 localparam X0=FULL?260:8,Y0=FULL?25:8,N=FULL?2:64;
 localparam LAT=4*(HT+1)+21;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[23:0]rgb=0,expected_rgb=0;reg de=0,vs=0,hs=0;
 wire[23:0]out_rgb;wire od,ov,oh;wire[2:0]mode;wire[7:0]threshold;
 ep1_video #(.WIDTH(W),.HEIGHT(H),.H_TOTAL(HT),.DEBOUNCE(2),.LONG_PRESS(8),.HUD_ENABLE(0))
 dut(clk,rst,rgb,de,vs,hs,1'b1,1'b1,out_rgb,od,ov,oh,mode,threshold,,,);
 reg[23:0]pixels[0:49151],expected[0:49151];reg[10:0]modes[0:63];
 reg[26:0]queue[0:LAT-1];integer ptr=0,cycles=0,errors=0,checked=0;
 reg[26:0]want;integer next_ptr;
 always @(posedge clk)begin
  if(!rst)begin ptr=0;cycles=0;end
  else begin
   queue[ptr]={expected_rgb,de,vs,hs};
   next_ptr=ptr==LAT-1?0:ptr+1;
   want=queue[next_ptr];ptr=next_ptr;
   #1;
   if(cycles>=LAT-1)begin
    if({out_rgb,od,ov,oh}!==want)begin
     if(errors<12)$display("Mismatch FULL=%0d cycle=%0d mode=%0d actual=%h expected=%h ax=%0d ay=%0d",FULL,cycles,mode,{out_rgb,od,ov,oh},want,dut.ax,dut.ay);
     errors=errors+1;
    end
    if(want[2])checked=checked+1;
   end
   cycles=cycles+1;
  end
 end
 integer f,yy,xx,px,py,index;reg[2:0]setting;reg[7:0]t;
 initial begin
  $readmemh("tb/pixels.hex",pixels);$readmemh("tb/expected.hex",expected);$readmemh("tb/modes.hex",modes);
  repeat(8)@(negedge clk);rst=1;
  for(f=0;f<N;f=f+1)begin
   setting=FULL?(f==0?3:0):modes[f][10:8];t=FULL?100:modes[f][7:0];
   // Exercise frame-boundary commit separately from the physical button bench.
   // Full-size frame zero must reach Sobel without any button or test override.
   if(!FULL||f!=0)begin dut.controls.requested_mode=setting;dut.controls.requested_threshold=t;end
   for(yy=0;yy<VT;yy=yy+1)for(xx=0;xx<HT;xx=xx+1)begin
    @(negedge clk);vs=yy>=(FULL?5:2);hs=xx>=(FULL?40:2);
    de=xx>=X0&&xx<X0+W&&yy>=Y0&&yy<Y0+H;rgb=0;expected_rgb=0;
    if(de)begin
     px=xx-X0;py=yy-Y0;
     if(FULL)begin
      rgb=px<W/2?24'h000000:24'hffffff;
      expected_rgb=f==1?rgb:((px==W/2-1||px==W/2)&&py>=2&&py<H-2?24'hffffff:24'h000000);
     end else begin index=f*W*H+py*W+px;rgb=pixels[index];expected_rgb=expected[index];end
    end
   end
  end
  @(negedge clk);de=0;vs=0;hs=0;rgb=0;expected_rgb=0;
  repeat(LAT+20)@(negedge clk);
  if(errors||checked!=N*W*H)$fatal(1,"FAIL video errors=%0d checked=%0d expected_pixels=%0d",errors,checked,N*W*H);
  $display("PASS video FULL=%0d frames=%0d pixels=%0d RGB/DE/HS/VS exact",FULL,N,checked);$finish;
 end
endmodule
module tb_ep1_720p;tb_ep1_video #(.FULL(1)) full_test();endmodule
