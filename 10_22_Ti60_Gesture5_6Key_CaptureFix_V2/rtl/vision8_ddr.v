//  by CrazyBird
module vision8_ddr #(
	parameter SNAP_TIMEOUT=134217727,
		C_ID_LEN      = 8, 
			C_DATA_LEN    = 128, 
			C_DATA_SIZE   = 4, 	//	C_DATA_LEN=8:0, 16:1, 32:2, 64:3, 128:4, 256:5, 512:6, 1024:7
			
			C_BURST_LEN   = 128,
			
			C_STRB_LEN    = C_DATA_LEN / 8, 
			C_ADDR_INC    = C_BURST_LEN * C_STRB_LEN,
			
			C_BASE_ADDR   = 32'h00000000, 	//	Start at 0x00000000 by default
			C_BUF_SIZE    = 22, 			//	Allocate 2^22 bytes (4MB) by default. The module takes 4*4MB by default. 
			C_RD_END_ADDR = 1280 * 720,
			
			FRAME_W = 1280, FRAME_H = 720,
            C_W_WIDTH     = 64, 
			C_R_WIDTH     = 8
)(
    input  wire                 axi_clk         ,
    input  wire                 axi_reset       ,
    
    output       [C_ID_LEN-1:0]      axi_awid        ,
    output       [31:0]      axi_awaddr      ,
    output       [ 7:0]      axi_awlen       ,
    output       [ 2:0]      axi_awsize      ,
    output       [ 1:0]      axi_awburst     ,
    output                   axi_awlock      ,
    output       [ 3:0]      axi_awcache     ,
    output       [ 2:0]      axi_awprot      ,
    output       [ 3:0]      axi_awqos       ,
    output wire                  axi_awvalid     ,
    input  wire                 axi_awready     ,
    
    output       [C_DATA_LEN-1:0]      axi_wdata       ,
    output       [C_STRB_LEN-1:0]      axi_wstrb       ,
    output                   axi_wlast       ,
    output wire                  axi_wvalid      ,
    input  wire                 axi_wready      ,
    
    input  wire     [C_ID_LEN-1:0]      axi_bid         ,
    input  wire     [ 1:0]      axi_bresp       ,
    input  wire                 axi_bvalid      ,
    output                   axi_bready      ,
    
    output       [C_ID_LEN-1:0]      axi_arid        ,
    output       [31:0]      axi_araddr      ,
    output       [ 7:0]      axi_arlen       ,
    output       [ 2:0]      axi_arsize      ,
    output       [ 1:0]      axi_arburst     ,
    output                   axi_arlock      ,
    output       [ 3:0]      axi_arcache     ,
    output       [ 2:0]      axi_arprot      ,
    output       [ 3:0]      axi_arqos       ,
    output wire                  axi_arvalid     ,
    input  wire                 axi_arready     ,
    
    input  wire     [C_ID_LEN-1:0]      axi_rid         ,
    input  wire     [C_DATA_LEN-1:0]      axi_rdata       ,
    input  wire     [ 1:0]      axi_rresp       ,
    input  wire                 axi_rlast       ,
    input  wire                 axi_rvalid      ,
    output                   axi_rready      ,
    
    input  wire                 wframe_pclk     ,
    input  wire                 wframe_vsync    ,		//	Writter VSync. Flush on falling edge. Connect to EOF. 
    input  wire                 wframe_data_en  ,
    input  wire     [C_W_WIDTH-1:0]      wframe_data     ,
    
    input  wire                 rframe_pclk     ,
    input  wire                 rframe_vsync    ,		//	Reader VSync. Flush on falling edge. Connect to ~EOF. 
    input  wire                 rframe_data_en  ,
    output wire     [C_R_WIDTH-1:0]      rframe_data     ,
    
    output 		[31:0] 	tp_o,
    input wire freeze_request,
    output wire frame_ready,
    output wire freeze_active,
 input main_enable,input aux_request,input[1:0]aux_kind,input[15:0]aux_directory,
 output reg aux_ack,aux_frame_ready,
 input snap_begin,snap_end,snap_abort,input[2:0]snap_slot,input snap_bad,snap_reset,snap_wr,
 input[31:0]snap_data,output snap_full,
 input aux_rd,output[31:0]aux_data,output aux_empty,
 output reg snap_done,snap_ok,output read_frame_good,read_frame_bad,output[31:0]source_id,
 output[31:0]base_errors,output reg[31:0]memory_errors,output reg main_frame_ok,
 output[159:0]debug_status,output[10:0]aux_read_level
);
 reg[31:0]debug_main_frames;reg[26:0]debug_read_age;reg[7:0]debug_fault;
 wire[31:0]c_awaddr,c_araddr;wire[7:0]c_awlen,c_arlen;
 wire c_awvalid,c_awready,c_arvalid,c_arready,c_wvalid,c_wready,c_wlast,c_bready;
 wire[127:0]c_wdata;wire[1:0]raw_slot;
 wire[31:0]unused_tp;
 reg[1:0]write_owner,read_owner;reg write_turn,read_turn;
 reg[31:0]waddr,raddr;reg[7:0]wlen,rlen;
 reg awvalid,arvalid,write_data,write_response;
 reg aux_protect;reg[1:0]aux_slot;
 wire[31:0]snap_q;wire snap_empty;wire[10:0]snap_wrlevel,snap_level;
 reg[127:0]packed_data;reg[1:0]pack_index;reg packed_valid;
 reg[5:0]snap_beat;reg[19:0]snapshot_bytes;reg snapshot_running,snapshot_failed;
 reg[2:0]snapshot_slot;reg[26:0]snapshot_watchdog;
 (* async_reg="true" *)reg sbm,sbs,sem,ses,badm,bads;
 reg sb_seen,se_seen;
 (* async_reg="true" *)reg abort_meta,abort_sync;
 reg aborting;
 wire abort_now=aborting||abort_sync||snapshot_watchdog>=SNAP_TIMEOUT;
 wire aux_full;wire[10:0]aux_level,aux_rdlevel;
 reg aux_reset,aux_push;reg[127:0]aux_wdata;reg[127:0]pip_pack;reg[1:0]pip_index;
 (* async_reg="true" *)reg arm,ars;
 reg[1:0]kind;reg[15:0]dir;
 reg[9:0]line;reg half_line;reg[11:0]offset;reg[7:0]aux_beats;reg[7:0]return_beats;
 reg[6:0]reset_cycles;reg restart,drop_returns,aux_failed;
 
 wire camera_read=read_owner==1,camera_write=write_owner==1;
 wire snap_pop=snapshot_running&&write_owner==2&&write_data&&!packed_valid&&!snap_empty&&!abort_now;
 wire snapshot_request=snapshot_running&&!abort_now&&snapshot_bytes<FRAME_W*FRAME_H/2&&snap_level>=128;
 wire[31:0]snapshot_address=32'h01000000+{10'd0,snapshot_slot,19'd0}+snapshot_bytes;
 wire[1:0]tile={line>=FRAME_H/2,half_line};
 wire tile_valid=dir[12+tile];
 wire[2:0]physical=dir[tile*3+:3];
 wire end_aux=kind==1?line>=FRAME_H/4:line>=FRAME_H;
 wire auxiliary_request=kind!=0&&!end_aux&&!restart&&!aux_reset&&aux_level<768&&(kind==1||tile_valid);

 assign aux_read_level=aux_rdlevel;
 assign debug_status={debug_fault,read_owner,write_owner,snapshot_running,aux_failed,restart,aux_reset,5'd0,aux_level,
                      5'd0,debug_read_age,debug_main_frames,12'd0,snapshot_bytes,memory_errors};

 vision8_base_axi #(.C_ID_LEN(C_ID_LEN),.C_DATA_LEN(C_DATA_LEN),.C_DATA_SIZE(C_DATA_SIZE),
 .C_BURST_LEN(C_BURST_LEN),.C_BASE_ADDR(C_BASE_ADDR),.C_BUF_SIZE(C_BUF_SIZE),
 .C_RD_END_ADDR(C_RD_END_ADDR),.C_W_WIDTH(C_W_WIDTH),.C_R_WIDTH(C_R_WIDTH)) camera(
 .axi_clk(axi_clk),.axi_reset(axi_reset),
 .axi_awid(),.axi_awaddr(c_awaddr),.axi_awlen(c_awlen),.axi_awsize(),.axi_awburst(),.axi_awlock(),.axi_awcache(),.axi_awprot(),.axi_awqos(),
 .axi_awvalid(c_awvalid),.axi_awready(c_awready),.axi_wdata(c_wdata),.axi_wstrb(),.axi_wlast(c_wlast),.axi_wvalid(c_wvalid),.axi_wready(c_wready),
 .axi_bid(axi_bid),.axi_bresp(axi_bresp),.axi_bvalid(axi_bvalid&&camera_write&&write_response),.axi_bready(c_bready),
 .axi_arid(),.axi_araddr(c_araddr),.axi_arlen(c_arlen),.axi_arsize(),.axi_arburst(),.axi_arlock(),.axi_arcache(),.axi_arprot(),.axi_arqos(),
 .axi_arvalid(c_arvalid),.axi_arready(c_arready),.axi_rid(axi_rid),.axi_rdata(axi_rdata),.axi_rresp(axi_rresp),
 .axi_rlast(axi_rlast),.axi_rvalid(axi_rvalid&&camera_read),.axi_rready(),
 .wframe_pclk(wframe_pclk),.wframe_vsync(wframe_vsync),.wframe_data_en(wframe_data_en),.wframe_data(wframe_data),
 .rframe_pclk(rframe_pclk),.rframe_vsync(rframe_vsync),.rframe_data_en(rframe_data_en),.rframe_data(rframe_data),
 .tp_o(unused_tp),.freeze_request(freeze_request),.frame_ready(frame_ready),.freeze_active(freeze_active),
 .read_frame_good(read_frame_good),.read_frame_bad(read_frame_bad),.main_enable(main_enable),.raw_slot(raw_slot),.source_id(source_id),.axi_errors(base_errors),.aux_protect(aux_protect),.aux_slot(aux_slot));
 assign axi_awid=0;assign axi_arid=0;
 assign axi_awsize=C_DATA_SIZE;assign axi_arsize=C_DATA_SIZE;
 assign axi_awburst=1;assign axi_arburst=1;assign axi_awlock=0;assign axi_arlock=0;
 assign axi_awcache=0;assign axi_arcache=0;assign axi_awprot=0;assign axi_arprot=0;assign axi_awqos=0;assign axi_arqos=0;
 assign axi_awaddr=waddr;assign axi_araddr=raddr;assign axi_awlen=wlen;assign axi_arlen=rlen;
 assign axi_awvalid=awvalid;assign axi_arvalid=arvalid;
 assign c_awready=awvalid&&axi_awready&&camera_write;
 assign c_arready=arvalid&&axi_arready&&camera_read;
 assign c_wready=axi_wready&&camera_write&&write_data;
 assign axi_wstrb={C_STRB_LEN{1'b1}};
 // The vendor camera FIFO output can change when an empty padded beat
 // receives new input. Hold any already-presented stalled AXI beat until
 // its handshake. The normal ready path stays combinational (no latency).
 reg camera_hold_valid;reg[C_DATA_LEN-1:0]camera_hold_data;reg camera_hold_last;
 always @(posedge axi_clk or posedge axi_reset)
 if(axi_reset)begin camera_hold_valid<=0;camera_hold_data<=0;camera_hold_last<=0;end
 else if(camera_write&&write_data)begin
  if(axi_wvalid&&axi_wready)camera_hold_valid<=0;
  else if(c_wvalid&&!axi_wready&&!camera_hold_valid)begin
   camera_hold_valid<=1;camera_hold_data<=c_wdata;camera_hold_last<=c_wlast;
  end
 end
 assign axi_wdata=camera_write?(camera_hold_valid?camera_hold_data:c_wdata):packed_data;
 assign axi_wvalid=write_data&&(camera_write?(camera_hold_valid||c_wvalid):packed_valid);
 assign axi_wlast=camera_write?(camera_hold_valid?camera_hold_last:c_wlast):snap_beat==31;
 assign axi_bready=write_response&&(camera_write?c_bready:1'b1);

 vision8_fifo snapshot_fifo(rframe_pclk,axi_clk,axi_reset||snap_reset,snap_wr,snap_data,snap_pop,snap_q,snap_full,snap_empty,snap_wrlevel,snap_level);

 vision8_aux_fifo auxiliary_fifo(axi_clk,rframe_pclk,axi_reset||aux_reset,aux_push,aux_wdata,aux_rd,aux_data,aux_full,aux_empty,aux_level,aux_rdlevel);
 wire[31:0]auxiliary_address=kind==1?
  {8'd0,aux_slot,22'd0}+line*(FRAME_W*8)+offset:
  32'h01000000+{10'd0,physical,19'd0}+(line>=FRAME_H/2?line-FRAME_H/2:line)*FRAME_W+offset;
 wire[12:0]aux_remaining=(kind==1?FRAME_W*2:FRAME_W)-offset;
 wire[12:0]boundary_space=4096-{1'b0,auxiliary_address[11:0]};
 wire[12:0]candidate_bytes=aux_remaining<512?aux_remaining:13'd512;
 wire[12:0]aux_transfer=candidate_bytes<boundary_space?candidate_bytes:boundary_space;
 assign axi_rready=camera_read?1'b1:!aux_full;
 assign tp_o={memory_errors[15:0],aux_level[7:0],snapshot_running,aux_failed,restart,read_owner,write_owner,packed_valid};
 always @(posedge axi_clk or posedge axi_reset)begin
  if(axi_reset)begin
   debug_main_frames<=0;debug_read_age<=0;debug_fault<=0;
   write_owner<=0;read_owner<=0;write_turn<=0;read_turn<=0;waddr<=0;raddr<=0;wlen<=0;rlen<=0;awvalid<=0;arvalid<=0;write_data<=0;write_response<=0;
   aux_protect<=0;aux_slot<=0;snap_done<=0;snap_ok<=0;memory_errors<=0;main_frame_ok<=0;packed_data<=0;pack_index<=0;packed_valid<=0;snap_beat<=0;snapshot_bytes<=0;
   abort_meta<=0;abort_sync<=0;aborting<=0;snapshot_running<=0;snapshot_failed<=0;snapshot_slot<=0;snapshot_watchdog<=0;sbm<=0;sbs<=0;sem<=0;ses<=0;badm<=0;bads<=0;sb_seen<=0;se_seen<=0;
   aux_reset<=1;aux_push<=0;aux_wdata<=0;pip_pack<=0;pip_index<=0;aux_ack<=0;aux_frame_ready<=0;arm<=0;ars<=0;kind<=0;dir<=0;line<=0;half_line<=0;offset<=0;aux_beats<=0;return_beats<=0;
   reset_cycles<=0;restart<=1;drop_returns<=1;aux_failed<=0;
  end else begin
   if(camera_read&&axi_rvalid&&axi_rready&&axi_rlast&&(raddr[C_BUF_SIZE-1:0]+C_ADDR_INC==C_RD_END_ADDR))debug_main_frames<=debug_main_frames+1'b1;
   if(read_owner==0||(axi_rvalid&&axi_rready))debug_read_age<=0;
   else if(debug_read_age!=27'h7ffffff)debug_read_age<=debug_read_age+1'b1;
   // Report a wedged transaction, never invent completion or reset its owner.
   if(debug_fault==0)begin
    if(axi_bvalid&&axi_bready&&axi_bresp!=0)debug_fault<=8'h11;
    else if(axi_rvalid&&axi_rready&&axi_rresp!=0)debug_fault<=8'h12;
    else if(axi_rvalid&&axi_rready&&axi_rid!=0)debug_fault<=8'h13;
    else if(axi_rvalid&&axi_rready&&axi_rlast!=(return_beats==rlen))debug_fault<=8'h14;
    else if(read_owner!=0&&debug_read_age>=SNAP_TIMEOUT)debug_fault<=8'h15;
    else if(snapshot_running&&snapshot_watchdog>=SNAP_TIMEOUT)debug_fault<=8'h16;
   end
   abort_meta<=snap_abort;abort_sync<=abort_meta;
   sbm<=snap_begin;sbs<=sbm;sem<=snap_end;ses<=sem;badm<=snap_bad;bads<=badm;arm<=aux_request;ars<=arm;
   aux_push<=0;
   if(sbs!=sb_seen&&!snapshot_running&&write_owner==0)begin
    sb_seen<=sbs;snapshot_running<=1;aborting<=0;snapshot_bytes<=0;snapshot_slot<=snap_slot;snapshot_failed<=0;packed_valid<=0;pack_index<=0;se_seen<=ses;snapshot_watchdog<=0;
   end
   if(snapshot_running)begin
    if(snapshot_watchdog!=27'h7ffffff)snapshot_watchdog<=snapshot_watchdog+1'b1;
    if(abort_now)aborting<=1;
    // A cancellation does not need an end-of-frame token. Presented AW/W
    // remain stable; completion waits until that snapshot owner has drained B.
    if((abort_now||(ses!=se_seen&&snapshot_bytes==FRAME_W*FRAME_H/2))&&write_owner!=2)begin
     snap_ok<=!abort_now&&snapshot_bytes==FRAME_W*FRAME_H/2&&!snapshot_failed&&!bads;
     snap_done<=~snap_done;snapshot_running<=0;se_seen<=ses;aborting<=0;
    end
   end
   if(write_owner==0)begin
    if(c_awvalid&&(!snapshot_request||!write_turn))begin write_owner<=1;waddr<=c_awaddr;wlen<=c_awlen;awvalid<=1;write_turn<=1;end
    else if(snapshot_request)begin write_owner<=2;waddr<=snapshot_address;wlen<=31;awvalid<=1;write_turn<=0;snap_beat<=0;packed_valid<=0;pack_index<=0;end
   end
   if(awvalid&&axi_awready)begin awvalid<=0;write_data<=1;end
   if(snap_pop)begin packed_data[pack_index*32+:32]<=snap_q;if(pack_index==3)begin pack_index<=0;packed_valid<=1;end else pack_index<=pack_index+1'b1;end
   if(snapshot_running&&write_owner==2&&write_data&&!packed_valid&&abort_now)begin
    packed_data<=0;packed_valid<=1;pack_index<=0;
   end
   if(axi_wvalid&&axi_wready)begin
    if(write_owner==2)begin packed_valid<=0;snap_beat<=snap_beat+1'b1;end
    if(axi_wlast)begin write_data<=0;write_response<=1;end
   end
   if(axi_bvalid&&axi_bready)begin
    if(write_owner==2)begin snapshot_bytes<=snapshot_bytes+512;if(axi_bresp!=0||axi_bid!=0)snapshot_failed<=1;end
    if(axi_bresp!=0||axi_bid!=0)memory_errors<=memory_errors+1'b1;
    write_response<=0;write_owner<=0;
   end
   // A new raster command cancels only queued work. Accepted returns still drain.
   if(ars!=aux_ack)begin restart<=1;drop_returns<=1;aux_frame_ready<=0;end
   if(restart&&read_owner==0)begin
    aux_reset<=1;reset_cycles<=0;kind<=aux_kind;dir<=aux_directory;aux_slot<=raw_slot;aux_protect<=aux_kind==1;
    line<=0;half_line<=0;offset<=0;pip_index<=0;aux_failed<=0;restart<=0;aux_ack<=ars;
   end else if(aux_reset&&!restart)begin
    if(reset_cycles==63)begin aux_reset<=0;drop_returns<=0;end else reset_cycles<=reset_cycles+1'b1;
   end
   if(kind!=0&&!aux_reset&&!restart&&!aux_failed&&aux_level>=((FRAME_W/2)<640?FRAME_W/2:640))aux_frame_ready<=1;
   if(kind==2&&!end_aux&&!tile_valid&&!restart&&!aux_reset&&read_owner==0)begin
    if(half_line)begin half_line<=0;line<=line+1'b1;end else half_line<=1;
   end
   if(read_owner==0&&!restart&&!aux_reset)begin
    if(c_arvalid&&(!auxiliary_request||!read_turn))begin read_owner<=1;raddr<=c_araddr;rlen<=c_arlen;arvalid<=1;read_turn<=1;return_beats<=0;end
    else if(auxiliary_request)begin
     read_owner<=2;raddr<=auxiliary_address;rlen<=aux_transfer/16-1;arvalid<=1;read_turn<=0;aux_beats<=31;return_beats<=0;
    end
   end else if(read_owner==0&&(restart||aux_reset)&&c_arvalid)begin
    // MAIN drain/prefill continues while the AUX FIFO is reset.
    read_owner<=1;raddr<=c_araddr;rlen<=c_arlen;arvalid<=1;return_beats<=0;
   end
   if(arvalid&&axi_arready)begin arvalid<=0;if(camera_read&&raddr[C_BUF_SIZE-1:0]==0)main_frame_ok<=1;end
   if(axi_rvalid&&axi_rready)begin
    return_beats<=return_beats+1'b1;
    if(axi_rresp!=0||axi_rid!=0||axi_rlast!=(return_beats==rlen))begin
     memory_errors<=memory_errors+1'b1;
     if(read_owner==2)begin aux_failed<=1;aux_frame_ready<=0;end
     else main_frame_ok<=0;
    end
    if(read_owner==2&&!drop_returns&&!restart&&axi_rresp==0&&axi_rid==0)begin
     if(kind==1)begin
      pip_pack[pip_index*32+:32]<={axi_rdata[63:48],axi_rdata[127:112]};
      pip_index<=pip_index+1'b1;
      if(pip_index==3)begin aux_push<=1;aux_wdata<={{axi_rdata[63:48],axi_rdata[127:112]},pip_pack[95:0]};end
     end else begin aux_push<=1;aux_wdata<=axi_rdata;end
    end
    if(axi_rlast)begin
     read_owner<=0;
     if(!camera_read)begin
      if(offset+((rlen+1)*16)>=(kind==1?FRAME_W*2:FRAME_W))begin
       offset<=0;
       if(kind==1)line<=line+1'b1;
       else if(half_line)begin half_line<=0;line<=line+1'b1;end else half_line<=1;
      end else offset<=offset+((rlen+1)*16);
     end
    end
   end

  end
 end
endmodule
