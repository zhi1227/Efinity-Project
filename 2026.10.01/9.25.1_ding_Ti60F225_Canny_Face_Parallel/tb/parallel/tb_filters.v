`timescale 1ns/1ps
module tb_filters;
 reg clk=0;always #5 clk=~clk;reg rst=0,valid=0;
 reg [71:0] win=0;reg [10:0] x=0;reg [9:0] y=0;
 wire [7:0] g,m;wire gv,mv;wire [10:0] gx,mx;wire [9:0] gy,my;
 gaussian3x3 a(clk,rst,valid,x,y,win,g,gv,gx,gy);
 median3x3 b(clk,rst,valid,x,y,win,m,mv,mx,my);
 integer p[0:8],s[0:8],i,j,k,n,sum,tmp,expected_g;
 initial begin
 repeat(5)@(negedge clk);rst=1;
 for(n=0;n<1012;n=n+1)begin
 sum=0;valid=n%5!=0;x=n%1280;y=n%720;
 for(i=0;i<9;i=i+1)begin
   if(n==0)p[i]=0;else if(n==1)p[i]=255;
   else if(n<11)p[i]=(i==n-2)?255:0;else p[i]=$random&255;
   s[i]=p[i];win[71-i*8-:8]=p[i];
   sum=sum+p[i]*((i%3==1)?2:1)*((i/3==1)?2:1);
 end
 for(i=0;i<8;i=i+1)for(j=i+1;j<9;j=j+1)if(s[i]>s[j])begin tmp=s[i];s[i]=s[j];s[j]=tmp;end
 expected_g=(sum+8)>>4;
 @(negedge clk);
 if(g!==expected_g[7:0] || m!==s[4][7:0])$fatal(1,"filter mismatch n=%d g=%d/%d m=%d/%d",n,g,expected_g,m,s[4]);
 if({gv,gx,gy}!=={valid,x,y} || {mv,mx,my}!=={valid,x,y})$fatal(1,"filter sync");
 end
 $display("PASS Gaussian and median: 1012 windows, zero/full-scale, all impulse positions, randomized sort/math, coordinates/valid");$finish;
 end
endmodule
