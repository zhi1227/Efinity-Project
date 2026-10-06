// 8-connected flood fill on an immutable 64 x ROWS binary snapshot.
// Each pixel is cleared on enqueue, so transitive joins and diagonal chains
// are exact; queue capacity equals pixel count. Retain the five largest blobs.
// This replaces upstream blob.sv's incomplete equivalence-chain merging.
module blob_snapshot #(parameter ROWS=36,MIN_AREA=3,MAX_AREA=500)(
 input clk,rst_n,load_we,input [11:0] load_addr,input load_bit,input start,
 output reg busy,done,overflow,output reg [2:0] count,
 output reg [29:0] centers_x,centers_y,output reg [119:0] boxes,
 output reg [59:0] areas);
 localparam PIXELS=64*ROWS;
 (* ram_style="block" *) reg mask_mem[0:PIXELS-1];
 (* ram_style="block" *) reg [11:0] queue_mem[0:PIXELS-1];
 reg mask_q;reg [11:0] queue_q;
 reg [11:0] read_addr,write_addr,queue_ra,queue_wa,queue_wd;
 reg read_en,write_en,write_bit,queue_re,queue_we;
 wire capture_we=load_we&&!busy&&(load_addr<PIXELS);
 wire ram_we=capture_we||write_en;
 wire [11:0] ram_wa=capture_we?load_addr:write_addr;
 wire ram_wd=capture_we?load_bit:write_bit;
 always @(posedge clk)begin
   // Explicit single write port is essential for Efinity block-RAM inference.
   if(ram_we)mask_mem[ram_wa]<=ram_wd;
   if(read_en)mask_q<=mask_mem[read_addr];
   if(queue_we)queue_mem[queue_wa]<=queue_wd;
   if(queue_re)queue_q<=queue_mem[queue_ra];
 end
 localparam IDLE=0,SCAN_R=1,SCAN_T=2,Q_R=3,Q_T=4,N_R=5,N_T=6,
   DIV_START=7,DIV_WAIT=8,STORE=9,ADVANCE=10,FINISH=11;
 reg [3:0] state;
 reg [11:0] scan,head,tail,node,area;
 reg [31:0] sx,sy;
 reg [5:0] xmin,xmax,ymin,ymax;
 reg [2:0] neighbor;
 reg [11:0] neighbor_addr;
 reg neighbor_valid;
 reg [2:0] work_count;
 reg work_overflow;
 reg [11:0] best_area[0:4];
 reg [5:0] best_x[0:4],best_y[0:4];
 reg [23:0] best_box[0:4];
 integer i,k;reg [2:0] slot;reg [11:0] smallest;
 wire [5:0] nx=node[5:0],ny=node[11:6];
 always @*begin
   neighbor_valid=0;neighbor_addr=node;
   case(neighbor)
   0:begin neighbor_valid=nx>0&&ny>0;neighbor_addr=node-65;end
   1:begin neighbor_valid=ny>0;neighbor_addr=node-64;end
   2:begin neighbor_valid=nx<63&&ny>0;neighbor_addr=node-63;end
   3:begin neighbor_valid=nx>0;neighbor_addr=node-1;end
   4:begin neighbor_valid=nx<63;neighbor_addr=node+1;end
   5:begin neighbor_valid=nx>0&&ny<ROWS-1;neighbor_addr=node+63;end
   6:begin neighbor_valid=ny<ROWS-1;neighbor_addr=node+64;end
   7:begin neighbor_valid=nx<63&&ny<ROWS-1;neighbor_addr=node+65;end
   endcase
   slot=0;smallest=best_area[0];
   for(k=1;k<5;k=k+1)if(best_area[k]<smallest)begin slot=k;smallest=best_area[k];end
   if(work_count<5)slot=work_count;
 end
 wire div_go=state==DIV_START;
 wire [31:0] qx,qy;wire vx,vy;
 divider dx(.clk_in(clk),.rst_in(!rst_n),.dividend_in(sx),.divisor_in({20'd0,area}),
   .data_valid_in(div_go),.quotient_out(qx),.remainder_out(),.data_valid_out(vx),.error_out(),.busy_out());
 divider dy(.clk_in(clk),.rst_in(!rst_n),.dividend_in(sy),.divisor_in({20'd0,area}),
   .data_valid_in(div_go),.quotient_out(qy),.remainder_out(),.data_valid_out(vy),.error_out(),.busy_out());
 reg ready_x,ready_y;reg [5:0] cx,cy;
 // Separate combinational RAM controls: reads sampled in *_R are visible in *_T.
 always @*begin
   read_en=0;read_addr=0;write_en=0;write_addr=0;write_bit=0;
   queue_re=0;queue_ra=head;queue_we=0;queue_wa=tail;queue_wd=neighbor_addr;
   if(state==SCAN_R)begin read_en=1;read_addr=scan;end
   if(state==SCAN_T&&mask_q)begin
     write_en=1;write_addr=scan;queue_we=1;queue_wa=0;queue_wd=scan;
   end
   if(state==Q_R&&head<tail)queue_re=1;
   if(state==N_R&&neighbor_valid)begin read_en=1;read_addr=neighbor_addr;end
   if(state==N_T&&neighbor_valid&&mask_q&&tail<PIXELS)begin
     write_en=1;write_addr=neighbor_addr;queue_we=1;
   end
 end
 always @(posedge clk)begin
 if(!rst_n)begin
   state<=IDLE;busy<=0;done<=0;count<=0;overflow<=0;
   centers_x<=0;centers_y<=0;boxes<=0;areas<=0;
   scan<=0;head<=0;tail<=0;node<=0;area<=0;sx<=0;sy<=0;
   xmin<=0;xmax<=0;ymin<=0;ymax<=0;neighbor<=0;
   work_count<=0;work_overflow<=0;ready_x<=0;ready_y<=0;cx<=0;cy<=0;
   for(i=0;i<5;i=i+1)begin best_area[i]<=0;best_x[i]<=0;best_y[i]<=0;best_box[i]<=0;end
 end else begin
   done<=0;
   case(state)
   IDLE:if(start)begin
     busy<=1;scan<=0;work_count<=0;work_overflow<=0;state<=SCAN_R;
     for(i=0;i<5;i=i+1)begin best_area[i]<=0;best_x[i]<=0;best_y[i]<=0;best_box[i]<=0;end
   end
   SCAN_R:state<=SCAN_T;
   SCAN_T:if(mask_q)begin
     head<=0;tail<=1;area<=0;sx<=0;sy<=0;
     xmin<=63;ymin<=63;xmax<=0;ymax<=0;state<=Q_R;
   end else state<=ADVANCE;
   Q_R:if(head<tail)state<=Q_T;
     else if(area>=MIN_AREA&&area<=MAX_AREA)state<=DIV_START;
     else state<=ADVANCE;
   Q_T:begin
     node<=queue_q;head<=head+1'b1;area<=area+1'b1;
     sx<=sx+queue_q[5:0];sy<=sy+queue_q[11:6];
     if(queue_q[5:0]<xmin)xmin<=queue_q[5:0];
     if(queue_q[5:0]>xmax)xmax<=queue_q[5:0];
     if(queue_q[11:6]<ymin)ymin<=queue_q[11:6];
     if(queue_q[11:6]>ymax)ymax<=queue_q[11:6];
     neighbor<=0;state<=N_R;
   end
   N_R:state<=N_T;
   N_T:begin
     if(neighbor_valid&&mask_q)begin
       if(tail<PIXELS)tail<=tail+1'b1;
       else work_overflow<=1;
     end
     if(neighbor==7)state<=Q_R;
     else begin neighbor<=neighbor+1'b1;state<=N_R;end
   end
   DIV_START:begin ready_x<=0;ready_y<=0;state<=DIV_WAIT;end
   DIV_WAIT:begin
     if(vx)begin cx<=qx[5:0];ready_x<=1;end
     if(vy)begin cy<=qy[5:0];ready_y<=1;end
     if(ready_x&&ready_y)state<=STORE;
   end
   STORE:begin
     if(work_count<5 || area>smallest)begin
       best_area[slot]<=area;best_x[slot]<=cx;best_y[slot]<=cy;
       best_box[slot]<={ymax,ymin,xmax,xmin};
     end
     if(work_count<5)work_count<=work_count+1'b1;else work_overflow<=1;
     state<=ADVANCE;
   end
   ADVANCE:if(scan==PIXELS-1)state<=FINISH;else begin scan<=scan+1'b1;state<=SCAN_R;end
   FINISH:begin
     for(i=0;i<5;i=i+1)begin
       centers_x[i*6+:6]<=best_x[i];centers_y[i*6+:6]<=best_y[i];
       boxes[i*24+:24]<=best_box[i];areas[i*12+:12]<=best_area[i];
     end
     count<=work_count;overflow<=work_overflow;done<=1;busy<=0;state<=IDLE;
   end
   default:begin state<=IDLE;busy<=0;end
   endcase
 end
 end
endmodule
