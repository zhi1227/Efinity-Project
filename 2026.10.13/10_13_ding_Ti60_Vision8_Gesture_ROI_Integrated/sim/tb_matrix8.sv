`timescale 1ns/1ps
module tb_matrix8;
 reg[10:0]x=0;reg[9:0]y=0;reg[2:0]g=0;reg phase=0;
 wire paint;wire[23:0]colour;
 gesture_matrix8 dut(x,y,g,phase,paint,colour);
 integer i,j,k,fd,px,py,count;reg[63:0]expected;
 initial begin
  for(k=0;k<4;k=k+1)begin
   g=k;case(k)1:expected=64'h545454567F7F3E1C;2:expected=64'h1818181F7F7F7E3C;3:expected=64'h66FFFFFF7E3C1800;default:expected=0;endcase
   for(j=0;j<8;j=j+1)for(i=0;i<8;i=i+1)begin
    x=1048+i*24+12;y=92+j*24+12;#1;
    if(!paint||colour!==(expected[63-j*8-i]?24'hFFCB55:24'h30343D))$fatal(1,"Wrong matrix pixel %0d %0d %0d",k,i,j);
    x=1048+i*24;y=92+j*24;#1;if(colour!==24'h12151C)$fatal(1,"Missing cell gap");
   end
   fd=$fopen($sformatf("reports/matrix_%0d.ppm",k),"wb");$fwrite(fd,"P6\n240 248\n255\n");
   for(py=64;py<312;py=py+1)for(px=1024;px<1264;px=px+1)begin x=px;y=py;#1;$fwrite(fd,"%c%c%c",colour[23:16],colour[15:8],colour[7:0]);end
   $fclose(fd);
  end
  g=1;phase=1;x=1048+24+12;y=92+12;#1;if(colour!==24'hFFEAA0)$fatal(1,"Wave animation");
  g=4;#1;if(colour!==24'h30343D)$fatal(1,"Removed gesture has icon");
  x=10;y=10;#1;if(paint)$fatal(1,"Paint outside panel");
  $display("PASS: three exact 8x8 bitmaps, idle grid, cell gaps, wave highlight, no removed gesture icon");$finish;
 end
endmodule
