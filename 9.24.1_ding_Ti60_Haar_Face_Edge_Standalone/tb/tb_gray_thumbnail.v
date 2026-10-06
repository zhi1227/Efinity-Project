`timescale 1ns/1ps
module tb_gray_thumbnail;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,valid=0;reg [10:0] x=0;reg [9:0] y=0;reg [7:0] pixel=0;
 wire ov;wire [7:0] op;
 gray_thumbnail #(.WIDTH(16),.HEIGHT(16)) dut(clk,rst,valid,x,y,pixel,ov,op);
 integer sums[0:3];integer expected,idx,outputs=0,f,row,col,n;reg expected_valid;
 always @(posedge clk)if(rst)begin
  expected_valid=valid&&(x%8==7)&&(y%8==7);
  idx=(y/8)*2+x/8;
  if(valid)sums[idx]=sums[idx]+pixel;
  expected=(sums[idx]+32)/64;
  #1;
  if(ov!==expected_valid)$fatal(1,"FAIL thumbnail output timing");
  if(ov)begin
   if(op!==expected[7:0])$fatal(1,"FAIL thumbnail average block=%d actual=%d expected=%d",idx,op,expected);
   outputs=outputs+1;
  end
 end
 initial begin
  for(n=0;n<4;n=n+1)sums[n]=0;
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<2;f=f+1)begin
   for(n=0;n<4;n=n+1)sums[n]=0;
   for(row=0;row<16;row=row+1)for(col=0;col<16;col=col+1)begin
    @(negedge clk);valid=1;x=col;y=row;pixel=f==1?255:(col*17+row*29)%256;
    if((col+row)%5==0)begin @(negedge clk);valid=0;end
   end
   @(negedge clk);valid=0;repeat(4)@(negedge clk);
  end
  if(outputs!=8)$fatal(1,"FAIL output count %d",outputs);
  $display("PASS tb_gray_thumbnail exact 8x8 averages, blanking, white maximum, next-frame reset");$finish;
 end
endmodule
