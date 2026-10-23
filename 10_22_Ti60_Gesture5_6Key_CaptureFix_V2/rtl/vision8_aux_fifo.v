// 4KiB asymmetric FIFO: one complete DDR beat per write, 32 bits per read.
// CDC pointers count 128-bit groups. The read Gray pointer advances only after
// all four words in a group are consumed, so no multi-bit Gray jump is sent.
module vision8_aux_fifo #(parameter AB=8)(
 input wr_clk,rd_clk,reset,wr_en,input[127:0]wr_data,input rd_en,
 output[31:0]rd_data,output full,empty,output[10:0]wr_level,rd_level);
 reg[AB:0]wp,wg;
 reg[AB+2:0]rp;
 reg[AB:0]rg;
 (* async_reg="true" *)reg[AB:0]rm,rs,wm,ws;
 function[AB:0]decode;input[AB:0]g;integer i;
 begin decode[AB]=g[AB];for(i=AB-1;i>=0;i=i-1)decode[i]=decode[i+1]^g[i];end endfunction
 wire[AB:0]used=wp-decode(rs);
 assign wr_level=used<<2;
 wire[AB+2:0]published={decode(ws),2'b00};
 assign rd_level=published-rp;
 assign full=used==(1<<AB);
 assign empty=published==rp;
 wire[AB:0]wn=wp+(wr_en&&!full);
 wire[AB+2:0]rn=rp+(rd_en&&!empty);
 wire[AB:0]read_group=rn[AB+2:2];
 wire[127:0]bank_q;
 reg[1:0]bank_select;
 genvar bank;
 generate for(bank=0;bank<4;bank=bank+1)begin:banks
  (* ram_style="block" *)reg[31:0]mem[0:(1<<AB)-1];
  reg[31:0]q;
  always @(posedge wr_clk)if(wr_en&&!full)mem[wp[AB-1:0]]<=wr_data[bank*32+:32];
  always @(posedge rd_clk)q<=mem[rn[AB+1:2]];
  assign bank_q[bank*32+:32]=q;
 end endgenerate
 always @(posedge rd_clk)bank_select<=rn[1:0];
 assign rd_data=bank_q[bank_select*32+:32];
 always @(posedge wr_clk or posedge reset)
 if(reset)begin wp<=0;wg<=0;rm<=0;rs<=0;end
 else begin rm<=rg;rs<=rm;wp<=wn;wg<=wn^(wn>>1);end
 always @(posedge rd_clk or posedge reset)
 if(reset)begin rp<=0;rg<=0;wm<=0;ws<=0;end
 else begin wm<=wg;ws<=wm;rp<=rn;rg<=read_group^(read_group>>1);end
endmodule
