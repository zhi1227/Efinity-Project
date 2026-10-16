`timescale 1ns/1ps
module tb_ram_equivalence;
  reg clk=0, rst_n=0;
  always #5 clk=~clk;
  reg [18:0] data19=0;
  reg [8:0] data9=0;
  reg [7:0] data8=0;
  reg [2:0] data3=0;
  wire [18:0] old19,new19;
  wire [8:0] old9,new9;
  wire [7:0] old8,new8,old_boundary,new_boundary;
  wire [2:0] old3,new3;
  video_delay_baseline #(.BITS(19),.LATENCY(6618)) a0(clk,rst_n,data19,old19);
  video_delay          #(.BITS(19),.LATENCY(6618)) b0(clk,rst_n,data19,new19);
  video_delay_baseline #(.BITS(9),.LATENCY(4963)) a1(clk,rst_n,data9,old9);
  video_delay          #(.BITS(9),.LATENCY(4963)) b1(clk,rst_n,data9,new9);
  video_delay_baseline #(.BITS(8),.LATENCY(6617)) a2(clk,rst_n,data8,old8);
  video_delay          #(.BITS(8),.LATENCY(6617)) b2(clk,rst_n,data8,new8);
  video_delay_baseline #(.BITS(8),.LATENCY(1025)) a3(clk,rst_n,data8,old_boundary);
  video_delay          #(.BITS(8),.LATENCY(1025)) b3(clk,rst_n,data8,new_boundary);
  video_delay_baseline #(.BITS(3),.LATENCY(3309)) a4(clk,rst_n,data3,old3);
  video_delay          #(.BITS(3),.LATENCY(3309)) b4(clk,rst_n,data3,new3);
  reg [5:0] line_id=0,char_index=0;
  reg [3:0] row=0;
  wire [15:0] old_menu,new_menu,old_hdmi,new_hdmi;
  menu_glyph_rom_baseline a5(clk,line_id[4:0],char_index,row,old_menu);
  menu_glyph_rom          b5(clk,line_id[4:0],char_index,row,new_menu);
  vision6_glyph_rom_baseline a6(clk,line_id,char_index,row,old_hdmi);
  vision6_glyph_rom          b6(clk,line_id,char_index,row,new_hdmi);
  integer cycle;
  initial begin
    repeat(2) @(negedge clk);
    for(cycle=0;cycle<80000;cycle=cycle+1) begin
      if(old19!==new19 || old9!==new9 || old8!==new8 ||
         old_boundary!==new_boundary || old3!==new3)
        $fatal(1,"Delay mismatch cycle=%0d",cycle);
      if(old_menu!==new_menu || old_hdmi!==new_hdmi)
        $fatal(1,"Glyph pixel mismatch cycle=%0d",cycle);
      // Exhaust all 65536 line/character/row combinations, including blanks.
      line_id=cycle[15:10];char_index=cycle[9:4];row=cycle[3:0];
      data19=$random;data9=$random;data8=$random;data3=$random;
      rst_n=!(cycle==0 || cycle==2000 || cycle==19000 || cycle==39000);
      @(negedge clk);
    end
    $display("PASS: RAM lossless equivalence, 80000 cycles, five delays, wrap/reset, every glyph input");
    $finish;
  end
endmodule
