`timescale 1ns/1ps
module tb_menu_render;
 reg clk=0,reset=1,visible=0,held=0;
 always #10 clk=~clk;
 reg [10:0] x=0;reg [9:0] y=0;reg [3:0] mode=0;
 wire [23:0] rgb;wire de;
 menu_renderer dut(clk,reset,x,y,visible,mode,held,1'b1,8'hFF,rgb,de);
 integer m,xx,yy,file,count;integer ids[0:5];
 always @(negedge clk) if(de && !reset) begin
   if(^rgb===1'bx) $fatal(1,"Unknown renderer pixel");
   $fwrite(file,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);count=count+1;
 end
 initial begin
   ids[0]=0;ids[1]=1;ids[2]=10;ids[3]=9;ids[4]=14;ids[5]=15;
   repeat(5) @(posedge clk);#1;reset=0;
   for(m=0;m<6;m=m+1) begin
     file=$fopen($sformatf("reports/menu_%0d.ppm",m),"wb");
     $fwrite(file,"P6\n1024 600\n255\n");count=0;mode=ids[m];held=(m==5);
     for(yy=0;yy<600;yy=yy+1) for(xx=0;xx<1024;xx=xx+1) begin
       @(posedge clk);#1;x=xx;y=yy;visible=1;
     end
     @(posedge clk);#1;visible=0;
     repeat(3) @(posedge clk);#1;
     $fclose(file);if(count!=614400) $fatal(1,"Wrong rendered frame length");
     $display("PASS: final-font full raster mode %0d",mode);
   end
   $finish;
 end
endmodule
