`timescale 1ns/1ps
module tb_controls;
 reg clk=0;always #5 clk=~clk;reg rst=0,rx=1;
 wire[3:0] mode;wire[11:0] low,high;
 reg key_n=0;
 uart_params #(.CLKS_PER_BIT(8),.KEY_DEBOUNCE_CYCLES(8)) u(clk,rst,rx,mode,low,high,key_n);
 reg[3:0] om=0;reg[23:0] rgb=24'h123456;reg de=1,vs=1,hs=1,edgep=1;
 reg[10:0] x=10;reg[9:0] y=10;reg[335:0] boxes=0;reg[3:0] count=1;
 wire[23:0] q;wire od,ov,oh;
 reg [7:0] gray=8'h56;reg cmp=1;
 reg frozen=0;wire[23:0] q_hud;wire hd,hv,hh;
 parallel_overlay #(.WIDTH(64)) dut(.clk(clk),.rst_n(rst),.mode(om),.rgb(rgb),
 .de(de),.vs(vs),.hs(hs),.x(x),.y(y),.edge_pixel(edgep),.count(count),.boxes(boxes),
 .gray_pixel(gray),.compare_edge(cmp),
 .median_strength(8'h77),.raw_edge(cmp),
 .frozen(frozen),
 .rgb_o(q),.de_o(od),.vs_o(ov),.hs_o(oh));
 parallel_overlay #(.WIDTH(256),.HUD_ENABLE(1)) hud(.clk(clk),.rst_n(rst),.mode(om),.rgb(rgb),
 .de(de),.vs(vs),.hs(hs),.x(x),.y(y),.edge_pixel(edgep),.count(4'd0),.boxes(336'd0),
 .gray_pixel(gray),.compare_edge(cmp),
 .median_strength(8'h77),.raw_edge(cmp),
 .frozen(frozen),
 .rgb_o(q_hud),.de_o(hd),.vs_o(hv),.hs_o(hh));
 integer i,j;reg [3:0] active_modes[0:5];
 task send;input[7:0] b;integer k;begin
 rx=0;repeat(8)@(negedge clk);
 for(k=0;k<8;k=k+1)begin rx=b[k];repeat(8)@(negedge clk);end
 rx=1;repeat(12)@(negedge clk);
 end endtask
 task check;input[23:0] exp;begin @(negedge clk);if(q!==exp || {od,ov,oh}!=={de,vs,hs})$fatal(1,"overlay mode %d got %h expected %h",om,q,exp);end endtask
 initial begin
 active_modes[0]=0;active_modes[1]=1;active_modes[2]=3;active_modes[3]=5;
 active_modes[4]=10;active_modes[5]=13;
 repeat(4)@(negedge clk);rst=1;@(negedge clk);
 if(mode!=3 || low!=40 || high!=80)$fatal(1,"defaults");
 repeat(30)@(negedge clk);if(mode!=3)$fatal(1,"held at boot");
 key_n=1;repeat(20)@(negedge clk);
 repeat(3)begin key_n=0;repeat(2)@(negedge clk);key_n=1;repeat(2)@(negedge clk);end
 repeat(20)@(negedge clk);if(mode!=3)$fatal(1,"press bounce");
 key_n=0;repeat(30)@(negedge clk);if(mode!=5)$fatal(1,"first press must skip 4");
 repeat(100)@(negedge clk);if(mode!=5)$fatal(1,"hold repeated");
 repeat(3)begin key_n=1;repeat(2)@(negedge clk);key_n=0;repeat(2)@(negedge clk);end
 repeat(20)@(negedge clk);if(mode!=5)$fatal(1,"release bounce");
 for(j=0;j<6;j=j+1)begin
 key_n=1;repeat(20)@(negedge clk);key_n=0;repeat(20)@(negedge clk);
 i=(4+j)%6;
 if(mode!=active_modes[i])$fatal(1,"button cycle/wrap must skip retired modes");
 if(low!=40 || high!=80)$fatal(1,"button changed threshold");
 end
 key_n=1;repeat(20)@(negedge clk);
 send("3");if(mode!=3)$fatal(1,"mode 3");
 send("2");if(mode!=3)$fatal(1,"retired mode 2 accepted");send("4");if(mode!=3)$fatal(1,"retired mode 4 accepted");
 send("m");if(mode!=5)$fatal(1,"UART cycle must skip 4");
 send("1");send("m");if(mode!=3)$fatal(1,"UART cycle must skip 2");
 send("5");send("6");if(mode!=5)$fatal(1,"retired mode 6 accepted");send("7");if(mode!=5)$fatal(1,"retired mode 7 accepted");
 send("8");if(mode!=5)$fatal(1,"retired mode 8 accepted");send("9");if(mode!=5)$fatal(1,"retired mode 9 accepted");
 send("m");if(mode!=10)$fatal(1,"UART cycle must skip 6/7/8/9");send("0");
 send("a");if(mode!=10)$fatal(1,"mode a");send("b");if(mode!=10)$fatal(1,"retired mode b accepted");
 send("c");if(mode!=10)$fatal(1,"retired mode c accepted");
 send("m");if(mode!=13)$fatal(1,"UART cycle must skip 11/12");
 send("0");send("d");if(mode!=13)$fatal(1,"mode d");
 send("e");if(mode!=13)$fatal(1,"invalid mode accepted");send("m");if(mode!=0)$fatal(1,"mode wrap");
 for(j=0;j<8;j=j+1)begin
 send(8'h30+j);i=(j==2)?1:((j==4)?3:((j>=6)?5:j));
 if(mode!=i)$fatal(1,"numeric mode/retired command");end
 send("+");if(low!=48 || high!=96)$fatal(1,"increase");
 for(j=0;j<150;j=j+1)send("+");if(low>1000 || high<=low)$fatal(1,"upper clamp");
 for(j=0;j<150;j=j+1)send("-");if(low!=8 || high!=16)$fatal(1,"lower clamp");
 send("r");if(mode!=3 || low!=40 || high!=80)$fatal(1,"reset command");
 // Explicit same-cycle arbitration; independent debounce tests remain above.
 force u.key_pulse=1;force u.valid=1;force u.data=8'h35;
 @(negedge clk);if(mode!=5)$fatal(1,"UART numeric did not beat key");
 force u.data=8'h2b;@(negedge clk);if(mode!=10 || low!=48)$fatal(1,"threshold swallowed key");
 force u.data=8'h6d;@(negedge clk);if(mode!=13)$fatal(1,"UART m double increment or retired mode");
 force u.data=8'h62;@(negedge clk);if(mode!=0)$fatal(1,"retired b swallowed key");
 force u.data=8'h61;@(negedge clk);if(mode!=10)$fatal(1,"UART a did not beat key");
 force u.data=8'h63;@(negedge clk);if(mode!=13)$fatal(1,"retired c swallowed key");
 force u.data=8'h35;@(negedge clk);if(mode!=5)$fatal(1,"UART 5 did not beat key");
 force u.data=8'h38;@(negedge clk);if(mode!=10)$fatal(1,"retired 8 swallowed key");
 force u.data=8'h39;@(negedge clk);if(mode!=13)$fatal(1,"retired 9 swallowed key");
 force u.data=8'h72;@(negedge clk);if(mode!=3 || low!=40)$fatal(1,"reset lost collision");
 force u.data=8'h32;@(negedge clk);if(mode!=5)$fatal(1,"retired 2 swallowed key");
 force u.data=8'h34;@(negedge clk);if(mode!=10)$fatal(1,"retired 4 swallowed key");
 force u.data=8'h35;@(negedge clk);if(mode!=5)$fatal(1,"UART 5 did not beat key");
 force u.data=8'h36;@(negedge clk);if(mode!=10)$fatal(1,"retired 6 swallowed key");
 force u.data=8'h37;@(negedge clk);if(mode!=13)$fatal(1,"retired 7 swallowed key");
 force u.data=8'h72;@(negedge clk);if(mode!=3 || low!=40)$fatal(1,"reset lost collision");
 release u.key_pulse;release u.valid;release u.data;repeat(3)@(negedge clk);
 boxes[41:0]={10'd30,10'd10,11'd30,11'd10};
 om=0;check(rgb);om=1;check(24'hffffff);om=2;check(rgb);
 x=20;y=20;check(rgb);x=40;check(rgb);edgep=0;check(rgb);
 om=3;edgep=1;check(24'hffffff);x=10;y=10;check(24'hff0000);
 om=4;x=20;y=20;check(rgb);x=40;check(rgb);edgep=0;check(rgb);
 om=5;x=10;check(24'h565656);x=32;check(24'h00ffff);x=40;check(24'hffffff);cmp=0;check(0);
 om=6;x=10;y=10;check(rgb);om=7;check(rgb);
 om=8;check(rgb);om=9;check(rgb);
 om=10;cmp=1;check(24'hff0000);cmp=0;check(rgb);
 // Unsupported IDs have no old split/ROI output; direct injection falls back to RGB.
 om=11;x=40;check(rgb);om=12;check(rgb);om=13;check(24'h777777);
 // Top left pixel of M at (8,8) must be white/yellow on LIVE/HOLD.
 om=0;x=8;y=8;check(rgb);if(q_hud!==24'hffffff)$fatal(1,"HUD LIVE glyph");
 frozen=1;check(rgb);if(q_hud!==24'hffff00)$fatal(1,"HUD HOLD color");
 de=0;check(0);
 if(q_hud!==0 || hd!==0)$fatal(1,"HUD blanking");
 $display("PASS K1 6-mode cycle 0/1/3/5/10/13, retired UART 2/4/6/7/8/9/b/c ignored including key collisions, clamps/HUD/blanking/sync");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
