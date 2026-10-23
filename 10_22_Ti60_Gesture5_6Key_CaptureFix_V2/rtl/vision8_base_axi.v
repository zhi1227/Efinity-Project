//  by CrazyBird
module vision8_base_axi #(
	parameter 	C_ID_LEN      = 8, 
			C_DATA_LEN    = 128, 
			C_DATA_SIZE   = 4, 	//	C_DATA_LEN=8:0, 16:1, 32:2, 64:3, 128:4, 256:5, 512:6, 1024:7
			
			C_BURST_LEN   = 128,
			
			C_STRB_LEN    = C_DATA_LEN / 8, 
			C_ADDR_INC    = C_BURST_LEN * C_STRB_LEN,
			
			C_BASE_ADDR   = 32'h00000000, 	//	Start at 0x00000000 by default
			C_BUF_SIZE    = 22, 			//	Allocate 2^22 bytes (4MB) by default. The module takes 4*4MB by default. 
			C_RD_END_ADDR = 1280 * 720,
			
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
    output reg                  axi_awvalid     ,
    input  wire                 axi_awready     ,
    
    output       [C_DATA_LEN-1:0]      axi_wdata       ,
    output       [C_STRB_LEN-1:0]      axi_wstrb       ,
    output                   axi_wlast       ,
    output reg                  axi_wvalid      ,
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
    output reg                  axi_arvalid     ,
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
 input main_enable,
 output wire[1:0] raw_slot,output wire[31:0]source_id,output reg[31:0]axi_errors,
 output reg read_frame_good,read_frame_bad,
 input aux_protect,input[1:0]aux_slot
); 
	reg 				r_w_rst = 1;
 wire camera_full,camera_fifo_overflow,camera_reset_busy;reg camera_overflow;

	reg 	[3:0] 	rs_w = 0; 
 reg [21:0] camera_bytes;
 reg camera_vs_q,camera_frame_good;
 (* async_reg="true" *)reg frame_good_meta,frame_good_sync;
 wire [1:0] rc_wframe_index,rc_rframe_index;
 reg[31:0]slot_id[0:3];reg[31:0]sequence_id;reg writer_failed;
 integer si;
 reg r_wframe_inc=0,r_rframe_inc=0;
	wire 				w_wfifo_pempty, w_wfifo_empty; 
	wire 				w_wfifo_ren; 
	wire 	[C_DATA_LEN-1:0] 	w_wfifo_rdata; 
	reg 	[C_BUF_SIZE-1:0] 	rc_w_ptr = 0; 
	reg 	[0:0] 		rc_w_eof = 0; 
	reg 	[1:0] 	r_wframe_sync = 0; 	
	reg 			r_weof_pending = 0; 
reg                             rframe_vsync_dly;
wire                            rframe_vsync_neg;
reg             [4:0]           rfifo_cnt;
reg                             rfifo_rst;
reg                             rfifo_wenb;
reg             [C_DATA_LEN-1:0]          rfifo_wdata;
wire            [ 9:0]          rfifo_wcnt;
wire 					  rfifo_wfull; 
wire                            rfifo_wr_rst_busy;
 wire read_underflow;
 localparam READ_PIXELS=C_RD_END_ADDR/(C_R_WIDTH/8);
 reg[$clog2(READ_PIXELS+2)-1:0]read_pixels;
 reg read_vs_prev;
wire 					w_rfifo_aempty; 
wire 					w_rfifo_empty; 
 (* async_reg="true" *)reg reset_meta,reset_sync,enable_meta,enable_sync;
 reg reset_pending,reset_previous;reg[5:0]settle;
 reg[1:0]rd_state;reg[C_BUF_SIZE-1:0]araddr;
 reg[7:0]read_beats;
	wire 	[3:0] 	ws_w_idle = 0; 
	wire 	[3:0] 	ws_w_wdata = 1; 
	wire 	[3:0] 	ws_w_winc = 2; 
	wire 	[3:0] 	ws_w_eof = 3; 
wire 			w_rfifo_rst = axi_reset || rfifo_rst; 
 always @(posedge rframe_pclk or posedge axi_reset)begin
  if(axi_reset)begin read_frame_good<=0;read_frame_bad<=0;read_pixels<=0;read_vs_prev<=1;end
  else begin
   read_vs_prev<=rframe_vsync;
   if(rframe_vsync&&!read_vs_prev)read_frame_good<=read_pixels==READ_PIXELS&&!read_frame_bad;
   if(!rframe_vsync&&read_vs_prev)begin read_pixels<=0;read_frame_bad<=0;end
   else if(rframe_data_en)begin
    if(read_pixels<READ_PIXELS+1)read_pixels<=read_pixels+1'b1;
    if(w_rfifo_empty||rfifo_wr_rst_busy||w_rfifo_rst||read_pixels>=READ_PIXELS)read_frame_bad<=1;
   end
   if(read_underflow)read_frame_bad<=1;
  end
 end




	
	initial begin
		axi_awvalid <= 0; 
		axi_wvalid <= 0; 
		axi_arvalid <= 0; 
	end

	assign axi_awid    = {C_ID_LEN{1'b0}};
	assign axi_awlen   = C_BURST_LEN - 1'b1;
	assign axi_awsize  = C_DATA_SIZE;
	assign axi_awburst = 2'b01;	//	INCR
	assign axi_awlock  = 1'b0;
	assign axi_awcache = 0;
	assign axi_awprot  = 3'b0;
	assign axi_awqos   = 4'b0;
	assign axi_wstrb   = 32'hFFFFFFFF;
	assign axi_bready = (rs_w==ws_w_winc); 
	    
	assign axi_arid    = {C_ID_LEN{1'b0}};
	assign axi_arlen   = C_BURST_LEN - 1'b1;
	assign axi_arsize  = C_DATA_SIZE;
	assign axi_arburst = 2'b01;	//	INCR
	assign axi_arlock  = 1'b0;
	assign axi_arcache = 0;
	assign axi_arprot  = 3'b0;
	assign axi_arqos   = 4'b0;
	assign axi_rready = 1; 
	
	
	
	
	////////////////////////////////////////////////////////////////
	// Count camera bytes independently of AXI burst padding. A short frame
 // may occupy 900 padded bursts but is still not a complete camera frame.
 always @(posedge wframe_pclk or posedge axi_reset)
 if(axi_reset)begin camera_bytes<=0;camera_vs_q<=0;camera_frame_good<=0;camera_overflow<=0;end
 else begin
   camera_vs_q<=wframe_vsync;
   if(camera_vs_q&&!wframe_vsync)begin
     camera_frame_good<=(camera_bytes==C_RD_END_ADDR)&&!camera_overflow;camera_bytes<=0;camera_overflow<=0;
   end else if(wframe_data_en)begin
     if(camera_bytes<C_RD_END_ADDR+4096)camera_bytes<=camera_bytes+C_W_WIDTH/8;
     if(camera_full||camera_fifo_overflow||r_w_rst||camera_reset_busy)camera_overflow<=1;
   end
 end
 always @(posedge axi_clk or posedge axi_reset)
 if(axi_reset)begin frame_good_meta<=0;frame_good_sync<=0;end
 else begin frame_good_meta<=camera_frame_good;frame_good_sync<=frame_good_meta;end

 //	R/W Schedule
 assign raw_slot=rc_rframe_index;assign source_id=slot_id[rc_rframe_index];
 always @(posedge axi_clk or posedge axi_reset)
 if(axi_reset)begin sequence_id<=0;for(si=0;si<4;si=si+1)slot_id[si]<=0;end
 else if(r_wframe_inc)begin sequence_id<=sequence_id+1'b1;slot_id[rc_wframe_index]<=sequence_id+1'b1;end
 always @(posedge axi_clk or posedge axi_reset)
 if(axi_reset)begin writer_failed<=0;axi_errors<=0;end
 else begin
  if(rs_w==ws_w_eof)writer_failed<=0;
  if(axi_bvalid&&axi_bready&&(axi_bresp!=0||axi_bid!=0))begin writer_failed<=1;axi_errors<=axi_errors+1'b1;end
  if(axi_rvalid&&axi_rready&&(axi_rresp!=0||axi_rid!=0))axi_errors<=axi_errors+1'b1;
 end
 vision8_slots u_frame_slots(
   .clk(axi_clk),.reset(axi_reset),.write_done(r_wframe_inc),.read_start(r_rframe_inc),
   .freeze_async(freeze_request),.write_slot(rc_wframe_index),.read_slot(rc_rframe_index),
   .frozen(freeze_active),.have_frame(frame_ready),.aux_protect(aux_protect),.aux_slot(aux_slot));
	
	
	
	////////////////////////////////////////////////////////////////
	//	AXI Writter


	//	On EOF when ~empty, flush the last data then reset FIFO. 

	//	Write Pointer. Burst bytes is always C_ADDR_INC. 
	
	//	Burst Control
	reg 	[7:0] 	rc_burst = 0; 	//	Compare to C_BURST_LEN - 1. 
	
	//	EOF Monitor. 

	always @(posedge axi_clk or posedge axi_reset) begin
		if(axi_reset) begin
			rs_w <= 0; 
			rc_w_ptr <= 0; 
			rc_w_eof <= 0; 
			r_w_rst <= 1; 
			axi_awvalid <= 0; 
			axi_wvalid <= 0; 
			r_wframe_sync <= 0; 
			r_weof_pending <= 0; 
			r_wframe_inc <= 0; 
			
		end else begin
			rc_w_eof <= 0; 
			r_wframe_inc <= 0; 
			
			//	Raise EOF on falling edge of VSYNC. 
			r_wframe_sync <= {r_wframe_sync, wframe_vsync}; 
			if(r_wframe_sync == 2'b10) begin
				r_weof_pending <= 1; 
			end else begin
			end
			
			if(axi_awready) begin
				axi_awvalid <= 0; 
			end else begin
			end
			
			case (rs_w)
				ws_w_idle: begin
						rc_burst <= 0; 
						r_w_rst <= 0; 
						
						if(~w_wfifo_pempty) begin
							axi_awvalid <= 1; 
							axi_wvalid <= 1; 
							rs_w <= ws_w_wdata; 
						
						end else if(r_weof_pending && (~w_wfifo_empty)) begin
							//	There's some data in the FIFO. write last. 
							axi_awvalid <= 1; 
							axi_wvalid <= 1; 
							rs_w <= ws_w_wdata; 
							
						end else if(r_weof_pending) begin
							//	EOF. Reset FIFO. Increment write pointer. 
							r_w_rst <= 1; 
							r_wframe_inc <= (rc_w_ptr == C_RD_END_ADDR) && frame_good_sync && !writer_failed; 
							rs_w <= ws_w_eof; 
							
						end else begin
						end
					end
					
				ws_w_eof: begin
						//	Wait for some cycles to release reset. 
						r_weof_pending <= 0; 
						rc_w_ptr <= 0; 
						
						rc_w_eof <= rc_w_eof + 1; 
						if(&rc_w_eof)
							rs_w <= ws_w_idle; 
						else begin
						end
					end
					
				ws_w_wdata: begin
						rc_burst <= rc_burst + axi_wready; 
						
						//	On last transaction terminate write. 
						if(axi_wlast && axi_wready) begin
							axi_wvalid <= 0; 
							rs_w <= ws_w_winc; 
						end else begin
						end
					end
					
				ws_w_winc: begin
                         if(axi_bvalid && axi_bready && !axi_awvalid)begin
                             rc_w_ptr <= rc_w_ptr + C_ADDR_INC;
                             rs_w <= ws_w_idle;
                         end
                         end
			endcase
		end
	end
	assign axi_awaddr = C_BASE_ADDR + {rc_wframe_index, rc_w_ptr}; 
	assign axi_wdata = w_wfifo_rdata; 
	assign axi_wlast = (rc_burst >= C_BURST_LEN - 1); 
	
	assign w_wfifo_ren = axi_wvalid && axi_wready; 
	
	
	assign tp_o[1:0] = {rs_w[1:0]}; 
	assign tp_o[2] = axi_wvalid; 
	assign tp_o[3] = wframe_data_en; 
	
	
	generate
		if(C_W_WIDTH == 64) begin: Gen_FIFO_W64
			W0_FIFO_64 u_W0_FIFO_64 
			(
			    .full_o(camera_full),.overflow_o(camera_fifo_overflow),.rst_busy(camera_reset_busy),
                .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 32) begin: Gen_FIFO_W32
			W0_FIFO_32 u_W0_FIFO_32
			(
			    .full_o(camera_full),.overflow_o(camera_fifo_overflow),.rst_busy(camera_reset_busy),
                .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 16) begin: Gen_FIFO_W32
			W0_FIFO_16 u_W0_FIFO_16
			(
			    .full_o(camera_full),.overflow_o(camera_fifo_overflow),.rst_busy(camera_reset_busy),
                .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end else if(C_W_WIDTH == 8) begin: Gen_FIFO_W8
			W0_FIFO_8 u_W0_FIFO_8 
			(
			    .full_o(camera_full),.overflow_o(camera_fifo_overflow),.rst_busy(camera_reset_busy),
                .wr_clk_i       (wframe_pclk    ),
			    .wr_en_i        (wframe_data_en),
			    .wdata          (wframe_data    ),
			    
			    .a_rst_i 	(r_w_rst), 

			    .rd_clk_i       (axi_clk        ),
			    .rd_en_i        (w_wfifo_ren     ),
			    .rdata          (w_wfifo_rdata    ),
			    .prog_empty_o	(w_wfifo_pempty),
			    .empty_o 		(w_wfifo_empty)
			);
		end
	endgenerate





















always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rframe_vsync_dly <= 1'b0;
    else
        rframe_vsync_dly <= rframe_vsync;
end

assign rframe_vsync_neg =  rframe_vsync_dly & ~rframe_vsync;


always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rfifo_cnt <= 5'h1f;
    else
    begin
        if(rframe_vsync_neg == 1'b1)
            rfifo_cnt <= 5'h1f;
        else if(rfifo_cnt > 5'd0)
            rfifo_cnt <= rfifo_cnt - 1'b1;
        else
            rfifo_cnt <= 5'b0;
    end
end


always @(posedge rframe_pclk)
begin
    if(axi_reset == 1'b1)
        rfifo_rst <= 1'b1;
    else
    begin
        if(rfifo_cnt == 5'b0)
            rfifo_rst <= 1'b0;
        else
            rfifo_rst <= 1'b1;
    end
end





generate
	if(C_R_WIDTH == 8) begin: Gen_RFIFO_8
		R0_FIFO_8 u_R0_FIFO_8
		(
			.wr_clk_i		(axi_clk),
			.wr_en_i		(rfifo_wenb),
			.wdata			(rfifo_wdata),
			.a_rst_i		(w_rfifo_rst), 
			.prog_full_o		(rfifo_wfull),
			
			.rd_clk_i		(rframe_pclk),
			.rd_en_i		(rframe_data_en),
			.rdata			(rframe_data),
			.empty_o		(w_rfifo_empty),
			.almost_empty_o	(w_rfifo_aempty),.underflow_o(read_underflow),.rst_busy(rfifo_wr_rst_busy)
		);
	end else if(C_R_WIDTH == 16) begin: Gen_RFIFO_16	
		R0_FIFO_16 u_R0_FIFO_16
		(
			.wr_clk_i		(axi_clk),
			.wr_en_i		(rfifo_wenb),
			.wdata			(rfifo_wdata),
			.a_rst_i		(w_rfifo_rst), 
			.prog_full_o		(rfifo_wfull),
			
			.rd_clk_i		(rframe_pclk),
			.rd_en_i		(rframe_data_en),
			.rdata			(rframe_data),
			.empty_o		(w_rfifo_empty),
			.almost_empty_o	(w_rfifo_aempty),.underflow_o(read_underflow),.rst_busy(rfifo_wr_rst_busy)
		);
	end
endgenerate
		
// Keep descriptors and the slot protected until all returns drain.
 always @(posedge axi_clk or posedge axi_reset)begin
  if(axi_reset)begin reset_meta<=1;reset_sync<=1;reset_previous<=1;enable_meta<=0;enable_sync<=0;reset_pending<=1;settle<=0;
   rd_state<=0;araddr<=0;axi_arvalid<=0;rfifo_wenb<=0;rfifo_wdata<=0;r_rframe_inc<=0;read_beats<=0;end
  else begin
   reset_meta<=w_rfifo_rst;reset_sync<=reset_meta;reset_previous<=reset_sync;enable_meta<=main_enable;enable_sync<=enable_meta;
   rfifo_wenb<=0;r_rframe_inc<=0;
   if(reset_sync&&!reset_previous)reset_pending<=1;
   if(rd_state==0)begin
    if(reset_pending||reset_sync)begin
     araddr<=0;settle<=0;
     if(!reset_sync)begin reset_pending<=0;r_rframe_inc<=1;end
    end else if(settle!=63)settle<=settle+1'b1;
    else if(enable_sync&&frame_ready&&araddr<C_RD_END_ADDR&&!rfifo_wfull)begin axi_arvalid<=1;rd_state<=1;read_beats<=0;end
   end else if(rd_state==1)begin
    if(axi_arvalid&&axi_arready)begin axi_arvalid<=0;rd_state<=2;end
   end else if(axi_rvalid)begin
    read_beats<=read_beats+1'b1;
    rfifo_wdata<=axi_rdata;
    rfifo_wenb<=!reset_pending&&!reset_sync&&axi_rresp==0&&axi_rid==0;
    if(axi_rlast)begin araddr<=araddr+C_ADDR_INC;rd_state<=0;end
   end
  end
 end
 assign axi_araddr=C_BASE_ADDR+{rc_rframe_index,araddr};
endmodule
