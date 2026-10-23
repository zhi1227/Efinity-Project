// Skin occupancy -> 8-connected components on a coarse grid.
// Default: 8x8 pixels/cell, 160x90 cells at 720p. Coordinates are expanded
// back to image pixels. This finds FACE CANDIDATES, not identity recognition.
//
// Capture bank and processing bank never overlap. A sequential BFS visits
// each foreground cell once; clearing on enqueue prevents duplicate visits.
// Completed box lists are published only at frame_start. If processing is
// still busy, the newest frame is dropped (overrun=1), never corrupting RAM.
`timescale 1ns/1ps
module face_grid_regions #(
 parameter WIDTH=1280, HEIGHT=720, CELL_SHIFT=3, MAX_FACES=8,
 parameter CELL_MIN=24, MIN_W=40, MIN_H=48, MAX_W=640, MAX_H=640,
 parameter MIN_AREA=1800, MIN_FILL_PERCENT=25,
 parameter MIN_RATIO_X10=6, MAX_RATIO_X10=16
)(
 input clk,input rst_n,input frame_start,
 input skin_valid,input skin,input [10:0] x,input [9:0] y,
 output reg [3:0] face_count,
 output reg [MAX_FACES*42-1:0] boxes,
 output reg busy,output reg overrun,
 input[31:0]source_id_i,output reg published,output reg[31:0]result_id,
 output reg saturated
);
 localparam CELL=1<<CELL_SHIFT, GW=WIDTH/CELL, GH=HEIGHT/CELL;
 localparam N=GW*GH, AW=$clog2(N), CW=$clog2(CELL*CELL+1);
 localparam XW=$clog2(GW), YW=$clog2(GH), QW=AW;
 // Parameters require WIDTH/HEIGHT divisible by CELL and MAX_FACES <= 15.
 reg [CW-1:0] cell_sum[0:GW-1];
 wire [XW-1:0] cx=x>>CELL_SHIFT;
 wire [YW-1:0] cy=y>>CELL_SHIFT;
 wire first_pixel=(x[CELL_SHIFT-1:0]==0)&&(y[CELL_SHIFT-1:0]==0);
 wire [CW-1:0] total=(first_pixel?0:cell_sum[cx])+skin;
 wire cell_last=(&x[CELL_SHIFT-1:0])&&(&y[CELL_SHIFT-1:0]);
 wire last_pixel=skin_valid&&(x==WIDTH-1)&&(y==HEIGHT-1);
 wire [AW-1:0] capture_addr=cy*GW+cx;
 reg capture_bank,process_bank;
 // Two write ports serve disjoint banks. No array reset: every capture cell
 // is written, including zero cells, before its bank becomes readable.
 (* ram_style="block" *) reg grid[0:2*N-1];
 reg [AW-1:0] read_addr;
 reg clear_en;
 reg mask_q;
 always @(posedge clk) begin
   if(skin_valid && x<WIDTH && y<HEIGHT) begin
     cell_sum[cx]<=total;
     if(cell_last) grid[(capture_bank?N:0)+capture_addr] <= (total>=CELL_MIN);
   end
 end
 // Port B reads and clears the SAME address. Separate write/read addresses
 // would infer tens of thousands of flip-flops instead of a dual-port RAM.
 always @(posedge clk) begin
   if(clear_en) grid[(process_bank?N:0)+read_addr] <= 1'b0;
   mask_q <= grid[(process_bank?N:0)+read_addr];
 end
 reg [AW:0] head,tail;
 reg queue_we;
 reg [QW-1:0] queue_d,queue_q;
 reg [AW-1:0] queue_wa;
 // Preserve the complete N-entry FIFO and its synchronous read-first timing.
 // Full 2048-entry chunks use independent 10-bit and remaining-bit planes.
 // A short final tail stays one packed word to avoid wasting two RAM blocks.
 generate if(QW>10 && QW<=15 && N>=2048) begin:banked_queue
   localparam CHUNKS=N/2048, TAIL=N%2048, BANKS=CHUNKS+(TAIL!=0);
   localparam SEL_BITS=(BANKS>1)?$clog2(BANKS):1;
   wire [CHUNKS*QW-1:0] chunk_values;
   reg [SEL_BITS-1:0] read_chunk;
   reg read_in_range;
   always @(posedge clk) begin
     read_chunk<=head[AW-1:0]>>11;
     read_in_range<=head[AW-1:0]<N;
   end
   genvar qb;
   for(qb=0;qb<CHUNKS;qb=qb+1) begin:chunk
     (* ram_style="block" *) reg [9:0] low_mem[0:2047];
     (* ram_style="block" *) reg [QW-11:0] high_mem[0:2047];
     reg [9:0] low_q;
     reg [QW-11:0] high_q;
     always @(posedge clk) begin
       if(queue_we && (queue_wa>>11)==qb) begin
         low_mem[queue_wa[10:0]]<=queue_d[9:0];
         high_mem[queue_wa[10:0]]<=queue_d[QW-1:10];
       end
       low_q<=low_mem[head[10:0]];
       high_q<=high_mem[head[10:0]];
     end
     assign chunk_values[qb*QW+:QW]={high_q,low_q};
   end
   if(TAIL!=0) begin:tail_chunk
     localparam TAW=(TAIL>1)?$clog2(TAIL):1;
     (* ram_style="block" *) reg [QW-1:0] tail_mem[0:TAIL-1];
     reg [QW-1:0] tail_q;
     always @(posedge clk) begin
       if(queue_we && (queue_wa>>11)==CHUNKS && queue_wa<N)
         tail_mem[queue_wa[TAW-1:0]]<=queue_d;
       tail_q<=tail_mem[head[TAW-1:0]];
     end
     always @* begin
       queue_q={QW{1'bx}};
       if(read_in_range) begin
         if(read_chunk==CHUNKS) queue_q=tail_q;
         else queue_q=chunk_values[read_chunk*QW+:QW];
       end
     end
   end else begin:no_tail
     always @* begin
       queue_q={QW{1'bx}};
       if(read_in_range) queue_q=chunk_values[read_chunk*QW+:QW];
     end
   end
 end else begin:direct_queue
   (* ram_style="block" *) reg [QW-1:0] queue[0:N-1];
   always @(posedge clk) begin
     if(queue_we) queue[queue_wa]<=queue_d;
     queue_q<=queue[head[AW-1:0]];
   end
 end endgenerate
 // A queue item is a cell address, not a padded {row,column} pair.
 // Capacity, FIFO timing and BFS order are unchanged. At 160x90 cells
 // this removes one stored bit from every one of the 14400 queue entries.
 wire [XW-1:0] queue_x;
 wire [YW-1:0] queue_y;
 generate if(GW==160 && AW<=14) begin:decode160
   // q/160 = (q>>5)/5. floor(g*205/1024)==floor(g/5)
   // for every 9-bit g; q%32 supplies the five low column bits.
   wire [8:0] group5=queue_q>>5;
   wire [16:0] reciprocal=group5*8'd205;
   wire [6:0] row=reciprocal[16:10];
   wire [8:0] column_group=group5-row*3'd5;
   assign queue_y=row;
   assign queue_x={column_group[2:0],queue_q[4:0]};
 end else begin:decode_generic
   assign queue_y=queue_q/GW;
   assign queue_x=queue_q%GW;
 end endgenerate
 localparam IDLE=0,SCAN_SET=1,SCAN_WAIT=2,SCAN_EVAL=3,
 POP_REQ=4,POP_LOAD=5,NEIGH_SET=6,NEIGH_WAIT=7,NEIGH_EVAL=8,
 FINISH_BOX=9,ADVANCE=10,DONE=11,POP_WAIT=12;
 reg [3:0] state;
 reg [XW-1:0] scan_x,current_x,min_x,max_x;
 reg [YW-1:0] scan_y,current_y,min_y,max_y;
 reg [AW-1:0] scan_addr;
 reg [3:0] neighbour;
 reg [XW-1:0] neighbour_x;
 reg [YW-1:0] neighbour_y;
 reg neighbour_ok;
 reg [AW:0] area;
 reg [3:0] work_count;
 reg [MAX_FACES*42-1:0] work_boxes;
 reg result_ready,work_saturated,pending_saturated;reg[31:0]process_id,pending_id;
 reg [MAX_FACES*42-1:0] pending_boxes;
 reg [3:0] pending_count;
 integer dx,dy;
 always @* begin
   dx=0;dy=0;
   case(neighbour)
    0:begin dx=-1;dy=-1;end 1:begin dx=0;dy=-1;end
    2:begin dx=1;dy=-1;end 3:begin dx=-1;dy=0;end
    4:begin dx=1;dy=0;end 5:begin dx=-1;dy=1;end
    6:begin dx=0;dy=1;end 7:begin dx=1;dy=1;end
    default:begin dx=0;dy=0;end
   endcase
   neighbour_ok=!((dx<0 && current_x==0)||(dx>0 && current_x==GW-1)||
                  (dy<0 && current_y==0)||(dy>0 && current_y==GH-1));
   neighbour_x=current_x+dx; neighbour_y=current_y+dy;
 end
 wire [10:0] pixel_x0=min_x*CELL,pixel_x1=(max_x+11'd1)*CELL-1;
 wire [9:0] pixel_y0=min_y*CELL,pixel_y1=(max_y+10'd1)*CELL-1;
 wire [11:0] bw=(max_x-min_x+12'd1)*CELL;
 wire [10:0] bh=(max_y-min_y+11'd1)*CELL;
 wire [21:0] bbox_area=bw*bh;
 wire [31:0] skin_area=area*(CELL*CELL);
 wire candidate=(bw>=MIN_W)&&(bw<=MAX_W)&&(bh>=MIN_H)&&(bh<=MAX_H)
    &&(skin_area>=MIN_AREA)
    &&(skin_area*100>=bbox_area*MIN_FILL_PERCENT)
    &&(bw*10>=bh*MIN_RATIO_X10)&&(bw*10<=bh*MAX_RATIO_X10);
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     capture_bank<=0;process_bank<=1; state<=IDLE;busy<=0;overrun<=0;
     face_count<=0;boxes<=0;work_count<=0;work_boxes<=0;result_ready<=0;
     pending_boxes<=0;pending_count<=0;published<=0;result_id<=0;saturated<=0;work_saturated<=0;pending_saturated<=0;process_id<=0;pending_id<=0;
     read_addr<=0;clear_en<=0;
     head<=0;tail<=0;queue_we<=0;queue_wa<=0;queue_d<=0;
     scan_x<=0;scan_y<=0;scan_addr<=0;current_x<=0;current_y<=0;
     min_x<=0;max_x<=0;min_y<=0;max_y<=0;area<=0;neighbour<=0;
   end else begin
     clear_en<=0;queue_we<=0;published<=0;
     if(frame_start && result_ready) begin
       boxes<=pending_boxes;face_count<=pending_count;result_ready<=0;published<=1;result_id<=pending_id;saturated<=pending_saturated;
     end
     case(state)
       IDLE: if(last_pixel) begin
         begin
           process_bank<=capture_bank;capture_bank<=~capture_bank;
           busy<=1;state<=SCAN_SET;scan_x<=0;scan_y<=0;scan_addr<=0;
           work_count<=0;work_boxes<=0;work_saturated<=0;process_id<=source_id_i;
         end
       end
       SCAN_SET:begin read_addr<=scan_addr;state<=SCAN_WAIT;end
       SCAN_WAIT:state<=SCAN_EVAL;
       SCAN_EVAL:if(mask_q) begin
         clear_en<=1;
         queue_we<=1;queue_wa<=0;queue_d<=scan_addr;
         head<=0;tail<=1;area<=1;
         min_x<=scan_x;max_x<=scan_x;min_y<=scan_y;max_y<=scan_y;
         state<=POP_REQ;
       end else state<=ADVANCE;
       // A freshly enqueued first item may be written on this clock.
       // Allow a full synchronous RAM read after that write.
       POP_REQ:if(head==tail) state<=FINISH_BOX; else state<=POP_WAIT;
       POP_WAIT:state<=POP_LOAD;
       POP_LOAD:begin
         current_x<=queue_x;current_y<=queue_y;
         head<=head+1'b1;neighbour<=0;state<=NEIGH_SET;
       end
       NEIGH_SET:if(neighbour_ok) begin
         read_addr<=neighbour_y*GW+neighbour_x;state<=NEIGH_WAIT;
       end else if(neighbour==7) state<=POP_REQ;
       else neighbour<=neighbour+1'b1;
       NEIGH_WAIT:state<=NEIGH_EVAL;
       NEIGH_EVAL:begin
         if(mask_q && tail<N) begin
           clear_en<=1;
           queue_we<=1;queue_wa<=tail[AW-1:0];queue_d<=read_addr;
           tail<=tail+1'b1;area<=area+1'b1;
           if(neighbour_x<min_x) min_x<=neighbour_x;
           if(neighbour_x>max_x) max_x<=neighbour_x;
           if(neighbour_y<min_y) min_y<=neighbour_y;
           if(neighbour_y>max_y) max_y<=neighbour_y;
         end
         if(neighbour==7) state<=POP_REQ;
         else begin neighbour<=neighbour+1'b1;state<=NEIGH_SET;end
       end
       FINISH_BOX:begin
         if(candidate && work_count==MAX_FACES)work_saturated<=1;
         if(candidate && work_count<MAX_FACES) begin
           work_boxes[work_count*42+:42]<={pixel_y1,pixel_y0,pixel_x1,pixel_x0};
           work_count<=work_count+1'b1;
         end
         state<=ADVANCE;
       end
       ADVANCE:if(scan_addr==N-1) state<=DONE;
       else begin
         scan_addr<=scan_addr+1'b1;
         if(scan_x==GW-1) begin scan_x<=0;scan_y<=scan_y+1'b1;end
         else scan_x<=scan_x+1'b1;
         state<=SCAN_SET;
       end
       DONE:begin
         pending_boxes<=work_boxes;pending_count<=work_count;pending_saturated<=work_saturated;pending_id<=process_id;
         result_ready<=1;busy<=0;state<=IDLE;
       end
       default:state<=IDLE;
     endcase
     if(last_pixel && busy) overrun<=1;
   end
 end
endmodule
