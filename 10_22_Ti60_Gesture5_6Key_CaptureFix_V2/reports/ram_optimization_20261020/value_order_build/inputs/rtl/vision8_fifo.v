// Dual-clock 32-bit FIFO, registered RAM prefetch; no combinational RAM read.
// Pointer-only reset must be requested after outstanding DDR traffic drains.
module vision8_fifo #(parameter AB=10)(
 input wr_clk,rd_clk,reset,input wr_en,input[31:0]wr_data,
 input rd_en,output reg[31:0]rd_data,output full,empty,
 output[AB:0]wr_level,rd_level);
 (* ram_style="block" *)reg[31:0]mem[0:(1<<AB)-1];
 reg[AB:0]wp,rp,wg,rg;
 (* async_reg="true" *)reg[AB:0]rm,rs,wm,ws;
 function[AB:0]decode;input[AB:0]g;integer i;begin decode[AB]=g[AB];for(i=AB-1;i>=0;i=i-1)decode[i]=decode[i+1]^g[i];end endfunction
 wire[AB:0]wn=wp+(wr_en&&!full),rn=rp+(rd_en&&!empty);
 assign wr_level=wp-decode(rs);assign rd_level=decode(ws)-rp;
 assign full=wr_level==(1<<AB);assign empty=(rg==ws);
 always @(posedge wr_clk or posedge reset)begin
  if(reset)begin wp<=0;wg<=0;rm<=0;rs<=0;end
  else begin rm<=rg;rs<=rm;wp<=wn;wg<=wn^(wn>>1);if(wr_en&&!full)mem[wp[AB-1:0]]<=wr_data;end
 end
 always @(posedge rd_clk)rd_data<=mem[rn[AB-1:0]];
 always @(posedge rd_clk or posedge reset)begin
  if(reset)begin rp<=0;rg<=0;wm<=0;ws<=0;end
  else begin wm<=wg;ws<=wm;rp<=rn;rg<=rn^(rn>>1);end
 end
endmodule
