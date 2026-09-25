`timescale 1ns/1ps
module tb_controls;
 reg clk=0;always #5 clk=~clk;reg rst=0,rx=1;
 wire[3:0] mode;wire[11:0] low,high;
 reg key_n=0;
 uart_params #(.CLKS_PER_BIT(8),.KEY_DEBOUNCE_CYCLES(8)) u(clk,rst,rx,mode,low,high,key_n);
 reg[3:0] om=0;reg[23:0] rgb=24'h123456;reg de=1,vs=1,hs=1,edgep=1;
 reg[10:0] x=10;reg[9:0] y=10;reg[335:0] boxes=0;reg[3:0] count=1;
 wire[23:0] q;wire od,ov,oh;
 reg [7:0] gray=8'h56;reg cmp=1,raw_skin=1,clean_skin=0;
 reg [7:0] raw_strength=0;reg frozen=0;wire[23:0] q_hud;wire hd,hv,hh;
 wire[23:0] q_debug;wire dd,dv,dh;
 parallel_overlay #(.WIDTH(64)) dut(.clk(clk),.rst_n(rst),.mode(om),.rgb(rgb),
 .de(de),.vs(vs),.hs(hs),.x(x),.y(y),.edge_pixel(edgep),.count(count),.boxes(boxes),
 .gray_pixel(gray),.compare_edge(cmp),.raw_skin(raw_skin),.clean_skin(clean_skin),
 .raw_strength(raw_strength),.median_pixel(8'h44),.median_strength(8'h77),.raw_edge(cmp),
 .frozen(frozen),.shape_class(2'd0),.shape_box(42'd0),
 .rgb_o(q),.de_o(od),.vs_o(ov),.hs_o(oh));
 parallel_overlay #(.WIDTH(64),.DEBUG_BOXES(1)) dbg(.clk(clk),.rst_n(rst),.mode(om),.rgb(rgb),
 .de(de),.vs(vs),.hs(hs),.x(x),.y(y),.edge_pixel(edgep),.count(count),.boxes(boxes),
 .gray_pixel(gray),.compare_edge(cmp),.raw_skin(raw_skin),.clean_skin(clean_skin),
 .rgb_o(q_debug),.de_o(dd),.vs_o(dv),.hs_o(dh));
 parallel_overlay #(.WIDTH(256),.HUD_ENABLE(1)) hud(.clk(clk),.rst_n(rst),.mode(om),.rgb(rgb),
 .de(de),.vs(vs),.hs(hs),.x(x),.y(y),.edge_pixel(edgep),.count(4'd0),.boxes(336'd0),
 .gray_pixel(gray),.compare_edge(cmp),.raw_skin(raw_skin),.clean_skin(clean_skin),
 .raw_strength(raw_strength),.median_pixel(8'h44),.median_strength(8'h77),.raw_edge(cmp),
 .frozen(frozen),.shape_class(2'd0),.shape_box(42'd0),
 .rgb_o(q_hud),.de_o(hd),.vs_o(hv),.hs_o(hh));
 integer i,j;
 task send;input[7:0] b;integer k;begin
 rx=0;repeat(8)@(negedge clk);
 for(k=0;k<8;k=k+1)begin rx=b[k];repeat(8)@(negedge clk);end
 rx=1;repeat(12)@(negedge clk);
 end endtask
 task check;input[23:0] exp;begin @(negedge clk);if(q!==exp || {od,ov,oh}!=={de,vs,hs})$fatal(1,"overlay mode %d got %h expected %h",om,q,exp);end endtask
 initial begin
 repeat(4)@(negedge clk);rst=1;@(negedge clk);
 if(mode!=3 || low!=40 || high!=80)$fatal(1,"defaults");
 repeat(30)@(negedge clk);if(mode!=3)$fatal(1,"held at boot");
 key_n=1;repeat(20)@(negedge clk);
 repeat(3)begin key_n=0;repeat(2)@(negedge clk);key_n=1;repeat(2)@(negedge clk);end
 repeat(20)@(negedge clk);if(mode!=3)$fatal(1,"press bounce");
 key_n=0;repeat(30)@(negedge clk);if(mode!=4)$fatal(1,"first press");
 repeat(100)@(negedge clk);if(mode!=4)$fatal(1,"hold repeated");
 repeat(3)begin key_n=1;repeat(2)@(negedge clk);key_n=0;repeat(2)@(negedge clk);end
 repeat(20)@(negedge clk);if(mode!=4)$fatal(1,"release bounce");
 for(j=0;j<14;j=j+1)begin
 key_n=1;repeat(20)@(negedge clk);key_n=0;repeat(20)@(negedge clk);
 if(mode!=((5+j)%14))$fatal(1,"button cycle/wrap");
 if(low!=40 || high!=80)$fatal(1,"button changed threshold");
 end
 key_n=1;repeat(20)@(negedge clk);
 send("4");if(mode!=4)$fatal(1,"mode");send("m");if(mode!=5)$fatal(1,"new mode 5");
 send("6");if(mode!=6)$fatal(1,"new mode 6");send("7");if(mode!=7)$fatal(1,"new mode 7");
 send("8");if(mode!=8)$fatal(1,"mode 8");send("9");if(mode!=9)$fatal(1,"mode 9");
 send("a");if(mode!=10)$fatal(1,"mode a");send("b");if(mode!=11)$fatal(1,"mode b");
 send("c");if(mode!=12)$fatal(1,"mode c");send("d");if(mode!=13)$fatal(1,"mode d");
 send("e");if(mode!=13)$fatal(1,"invalid mode accepted");send("m");if(mode!=0)$fatal(1,"mode wrap");
 for(j=0;j<8;j=j+1)begin send(8'h30+j);if(mode!=j)$fatal(1,"numeric mode");end
 send("+");if(low!=48 || high!=96)$fatal(1,"increase");
 for(j=0;j<150;j=j+1)send("+");if(low>1000 || high<=low)$fatal(1,"upper clamp");
 for(j=0;j<150;j=j+1)send("-");if(low!=8 || high!=16)$fatal(1,"lower clamp");
 send("r");if(mode!=3 || low!=40 || high!=80)$fatal(1,"reset command");
 // Explicit same-cycle arbitration; independent debounce tests remain above.
 force u.key_pulse=1;force u.valid=1;force u.data=8'h39;
 @(negedge clk);if(mode!=9)$fatal(1,"UART numeric did not beat key");
 force u.data=8'h2b;@(negedge clk);if(mode!=10 || low!=48)$fatal(1,"threshold swallowed key");
 force u.data=8'h6d;@(negedge clk);if(mode!=11)$fatal(1,"UART m double increment");
 force u.data=8'h72;@(negedge clk);if(mode!=3 || low!=40)$fatal(1,"reset lost collision");
 release u.key_pulse;release u.valid;release u.data;repeat(3)@(negedge clk);
 boxes[41:0]={10'd30,10'd10,11'd30,11'd10};
 om=0;check(rgb);om=1;check(24'hffffff);om=2;check(24'hff0000);
 x=20;y=20;check(24'hffff00);x=40;check(24'h00ff00);edgep=0;check(rgb);
 om=3;edgep=1;check(24'hffffff);x=10;y=10;check(24'hff0000);
 om=4;x=20;y=20;check(24'hffff00);x=40;check(24'h303030);edgep=0;check(0);
 om=5;x=10;check(24'h565656);x=32;check(24'h00ffff);x=40;check(24'hffffff);cmp=0;check(0);
 om=6;x=10;y=10;check(24'hffffff);if(q_debug!==24'hff0000)$fatal(1,"debug box option");
 raw_skin=0;check(0);om=7;check(0);clean_skin=1;check(24'hffffff);
 om=8;raw_strength=8'h81;check(24'h818181);
 om=9;raw_strength=23;check(0);raw_strength=24;check(24'h001860);
 raw_strength=63;check(24'h003ffc);raw_strength=64;check(24'h00ffff);
 raw_strength=127;check(24'h00ffff);raw_strength=128;check(24'h8020ff);
 raw_strength=191;check(24'hbf20ff);raw_strength=192;check(24'hff40e0);raw_strength=255;check(24'hff40e0);
 om=10;cmp=1;check(24'hff0000);cmp=0;check(rgb);
 om=11;x=40;check(24'h444444);om=13;check(24'h777777);
 // Top left pixel of M at (8,8) must be white/yellow on LIVE/HOLD.
 om=0;x=8;y=8;check(rgb);if(q_hud!==24'hffffff)$fatal(1,"HUD LIVE glyph");
 frozen=1;check(rgb);if(q_hud!==24'hffff00)$fatal(1,"HUD HOLD color");
 de=0;check(0);
 if(q_hud!==0 || hd!==0)$fatal(1,"HUD blanking");
 $display("PASS K1 14-mode cycle/debounce, UART 0-9/a-d/m/clamps/collisions, modes/neon thresholds/HUD/blanking/sync");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
