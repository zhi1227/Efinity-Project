`timescale 1ns/1ps
module tb_menu;
 reg clk=0,source_clk=0,locked=0;
 always #10.416667 clk=~clk;
 always #6.72043 source_clk=~source_clk;
 reg [4:0] state=3;
 wire [4:0] transported;
 menu_status_cdc bridge(source_clk,!locked,state,clk,!locked,transported);
 wire [6:0] c,d0,d1,d2,d3;
 wire reset;
 riscv_menu_top dut(.tx_slowclk(clk),.txpll_locked(locked),.status_i(transported),.lcd_reset(reset),
   .lvds_tx_clk_TX_DATA(c),.lvds_tx0_TX_DATA(d0),.lvds_tx1_TX_DATA(d1),.lvds_tx2_TX_DATA(d2),.lvds_tx3_TX_DATA(d3));
 initial begin #1000;locked=1;end
 initial begin #300000000;$fatal(1,"Timeout: CPU/menu failed to complete");end
 function [6:0] rev(input [6:0] a);
   rev={a[0],a[1],a[2],a[3],a[4],a[5],a[6]};
 endfunction
 wire [6:0] l0=rev(d0),l1=rev(d1),l2=rev(d2),l3=rev(d3);
 wire [23:0] recovered={l3[1:0],l0[5:0],l3[3:2],l1[4:0],l0[6],l3[5:4],l2[3:0],l1[6:5]};
 integer file,pixels,lines,line_pixels,cycles,i,frame_n;
 reg prev_de;
 reg [8:0] expected;
 integer modes[0:5];
 reg [8:0] last_active;
 always @(negedge clk) if(!reset) begin
   if(dut.display.active_state!==last_active && !(dut.display.h==1 && dut.display.v==0))
     $fatal(1,"Menu changed in the middle of a frame");
   last_active=dut.display.active_state;
   if(recovered!==dut.rgb || l2[6]!==dut.de || c!==rev(7'b1100011))
     $fatal(1,"LVDS RGB/DE packing error");
 end else last_active=9'd3;
 initial begin
   modes[0]=0;modes[1]=1;modes[2]=3;modes[3]=5;modes[4]=10;modes[5]=12;
   wait(locked);
   for(i=0;i<6;i=i+1) begin
     // Deliberately change midway through an active raster on later iterations.
     @(negedge source_clk);state={i==5,modes[i][3:0]};expected=9'h100|state;
     wait(dut.display.pending==expected);
     wait(dut.display.active_state==expected);
     frame_n=dut.display.frames;
     file=$fopen($sformatf("reports/menu_%0d.ppm",i),"wb");
     if(!file) $fatal(1,"Could not create frame");
     $fwrite(file,"P6\n1024 600\n255\n");
     pixels=0;lines=0;line_pixels=0;cycles=0;prev_de=0;
     while(dut.display.frames==frame_n) begin
       @(negedge clk);cycles=cycles+1;
       if(dut.de) begin
         if(^recovered===1'bx) $fatal(1,"Unknown pixel");
         $fwrite(file,"%c%c%c",recovered[23:16],recovered[15:8],recovered[7:0]);
         pixels=pixels+1;line_pixels=line_pixels+1;
       end
       if(prev_de && !dut.de) begin
         if(line_pixels!=1024) $fatal(1,"Wrong line length %0d",line_pixels);
         lines=lines+1;line_pixels=0;
       end
       prev_de=dut.de;
     end
     $fclose(file);
     if(pixels!=614400 || lines!=600 || cycles<853438 || cycles>853441)
       $fatal(1,"Frame size/timing failed: pixels=%0d lines=%0d cycles=%0d",pixels,lines,cycles);
     $display("PASS: mode %0d, RISC-V write, frame commit, %0d pixels, %0d clocks",modes[i],pixels,cycles);
     wait(dut.display.v==200);
   end
   $display("PASS: all six menu modes, LIVE/HOLD, CPU boot, CDC, LVDS packing, frame timing");
   $finish;
 end
endmodule
