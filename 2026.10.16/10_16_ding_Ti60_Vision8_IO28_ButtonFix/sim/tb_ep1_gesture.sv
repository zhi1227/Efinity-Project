`timescale 1ns/1ps
module tb_ep1_gesture;
 localparam W=128,H=96,N=31;
 reg clk=0;always #5 clk=~clk;reg rst=0,fs=0,fe=0,de=0,bit_i=0;
 reg[10:0]x=0;reg[9:0]y=0;wire bv,ovf,done;wire[10:0]x0,x1;wire[9:0]y0,y1,fill;wire[19:0]area,ratio;wire[1:0]g;
 ep1_gesture #(.WIDTH(W),.HEIGHT(H),.BORDER(1),.MIN_W(4),.MIN_H(4),.MIN_AREA(20),.MAX_AREA(W*H))
 dut(clk,rst,fs,fe,1'b1,de,bit_i,x,y,bv,x0,x1,y0,y1,area,fill,ratio,g,ovf,done,,);
 wire label_ovf;
 ep1_gesture #(.WIDTH(W),.HEIGHT(H),.BORDER(1),.MIN_W(4),.MIN_H(4),.MIN_AREA(20),.MAX_AREA(W*H),.LABEL_CAP(1))
 limited(.clk(clk),.rst_n(rst),.frame_start(fs),.frame_end(fe),.enable(1'b1),.de(de),.bit_i(bit_i),.x(x),.y(y),.overflow(label_ovf));
 reg pixels[0:N*W*H-1];reg[93:0]expected[0:N-1];integer n,xx,yy;
 reg cv=0;reg[9:0]cf=0;reg[19:0]cr=0;wire[1:0]cg;
 ep1_classify classify(cv,cf,cr,cg);
 task rule(input integer f,r,v,want);begin cf=f;cr=r;cv=v;#1;if(cg!==want)$fatal(1,"class boundary f=%0d r=%0d",f,r);end endtask
 task pulse_fs;begin @(negedge clk);fs=1;@(negedge clk);fs=0;end endtask
 initial begin
  $readmemh("tb/ccl_pixels.hex",pixels);$readmemh("tb/ccl_expected.hex",expected);
  rule(250,650,1,1);rule(600,1500,1,1);rule(601,1500,1,0);rule(700,650,1,2);rule(699,650,1,0);
  rule(750,1600,1,3);rule(750,3500,1,3);rule(751,3500,1,0);rule(500,1550,1,0);rule(1000,1000,0,0);
  repeat(4)@(negedge clk);rst=1;pulse_fs;
  for(n=0;n<N;n=n+1)begin
   for(yy=0;yy<H;yy=yy+1)begin
    for(xx=0;xx<W;xx=xx+1)begin @(negedge clk);de=1;x=xx;y=yy;bit_i=pixels[n*W*H+yy*W+xx];end
    @(negedge clk);de=0;bit_i=0;repeat(128)@(negedge clk);
   end
   @(negedge clk);fe=1;@(negedge clk);fe=0;repeat(2000)@(negedge clk);
   pulse_fs;
   if({ovf,bv,area,fill,ratio,x0,x1,y0,y1}!==expected[n])
    $fatal(1,"CCL case %0d got=%h expected=%h state=%0d",n,{ovf,bv,area,fill,ratio,x0,x1,y0,y1},expected[n],dut.state);
   if(ovf&&dut.fault_flags==0)$fatal(1,"Missing overflow reason"); if(label_ovf&&!limited.fault_flags[1])$fatal(1,"Missing label overflow reason"); if((n==2||n==3)&&g!=0)$fatal(1,"premature stable classification");
   if(n==4&&g!=2)$fatal(1,"three frame classification");
   if(n==5&&(g!=0||fill!=0||area!=0||bv))$fatal(1,"removed target retained");
   if(n==8&&!label_ovf)$fatal(1,"label overflow missing on merged components");
  end
  pulse_fs;if(!dut.fault_flags[3])$fatal(1,"Missing deadline reason");if(!ovf||bv||area||fill||ratio||g)$fatal(1,"unfinished frame must invalidate atomically");
  for(yy=0;yy<H;yy=yy+1)for(xx=0;xx<W;xx=xx+1)begin
   @(negedge clk);de=1;x=xx;y=yy;bit_i=(xx+yy)%2;
  end
  @(negedge clk);de=0;bit_i=0;
  if(!dut.input_overflow)$fatal(1,"FIFO saturation not detected");
  pulse_fs;if(!dut.fault_flags[0])$fatal(1,"Missing FIFO reason");if(!ovf||bv||area||fill||ratio||g)$fatal(1,"FIFO overflow must invalidate result");
  rst=0;repeat(3)@(negedge clk);if(ovf||bv||area||fill||ratio||g)$fatal(1,"reset stale result");
  $display("PASS: 31 flood-fill-reference CCL frames: exact geometry, union, diagonal, ties, borders, exact 64 candidates, candidate/label/FIFO overflow, deadline, removal, class boundaries and stability");$finish;
 end
endmodule
