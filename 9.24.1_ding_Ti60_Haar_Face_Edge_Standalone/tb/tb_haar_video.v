`timescale 1ns/1ps
module tb_haar_video;
 localparam W=1280,H=720,HT=1650,L=HT+1+4;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0;reg[23:0]rgb=0;reg de=0,vs=0,hs=0;reg[2:0]mode=0;
 wire[23:0]out;wire od,ov,oh,overrun;
 haar_face_video #(.DIAGNOSTICS(0),.SELF_TEST(0)) dut(clk,rst_n,rgb,de,vs,hs,mode,12'd40,12'd80,out,od,ov,oh,overrun);
 reg[26:0]q[0:L-1];integer ptr=0,n=0,frames=0,row,col,matched_edges=0;reg[26:0]expected;integer numde=0;
 always @(posedge clk)if(rst_n)begin
  expected=q[ptr];q[ptr]={vs,hs,de,rgb};ptr=(ptr==L-1)?0:ptr+1;n=n+1;
  #1;
  // Sample after NBA: total L+1 stages correspond to L cycles from this edge.
  if(n>L+2)begin
   if({ov,oh,od}!==expected[26:24])$fatal(1,"FAIL control n=%d expected=%b actual=%b",n,expected[26:24],{ov,oh,od});
   if(od&&out!==expected[23:0])$fatal(1,"FAIL RGB passthrough n=%d %h %h",n,out,expected[23:0]);
   if(od)numde=numde+1;
  end
  if(dut.ev&&dut.ade)begin
    if(dut.ex!=dut.ax||dut.ey!=dut.ay)$fatal(1,"FAIL edge alignment %d,%d != %d,%d",dut.ex,dut.ey,dut.ax,dut.ay);
    matched_edges=matched_edges+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  for(frames=0;frames<2;frames=frames+1)begin
   for(row=0;row<750;row=row+1)for(col=0;col<HT;col=col+1)begin
    @(negedge clk);vs=row>=5;hs=col>=40;de=row>=25&&row<745&&col>=200&&col<1480;
    rgb=de?(((col/80+row/40)%2)?24'hffffff:24'h000000):24'd0;
   end
  end
  repeat(L+5)begin @(negedge clk);de=0;rgb=0;end
  if(numde!=2*W*H)$fatal(1,"FAIL pixel count %d",numde);
  if(matched_edges<1000000)$fatal(1,"FAIL missing edges");
  $display("PASS full 720p RGB/control delay and Sobel coordinates pixels=%0d edge_points=%0d",numde,matched_edges);$finish;
 end
endmodule

