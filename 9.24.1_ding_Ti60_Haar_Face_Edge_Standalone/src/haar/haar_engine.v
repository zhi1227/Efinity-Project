`timescale 1ns/1ps
// Single-lane 25-stage Haar cascade. Cornell BSD model; portable integer RTL.
// Prefix sums wrap modulo 2^18 / 2^26: every <=24x24 rectangle fits those widths.
module haar_engine #(parameter SCALE_COUNT=13, SCAN_STEP=2)(
 input [1:0] scan_phase,
 input clk,rst_n,input load_we,input [13:0] load_addr,input [7:0] load_pixel,input start,
 output reg busy,done,det_valid,output reg [10:0] det_x,output reg [9:0] det_y,
 output reg [9:0] det_size,output reg [31:0] cycles,output reg [15:0] raw_count,
 input [13:0] debug_addr,output reg [7:0] debug_pixel,output reg [4:0] max_stage,output [5:0] debug_state
);
 (* ram_style="block" *) reg [7:0] frame_mem[0:14399];
 (* ram_style="block" *) reg [43:0] integral_mem[0:14399];
 (* ram_style="block" *) reg [119:0] feature_rom[0:2912];
 (* ram_style="block" *) reg [31:0] stage_rom[0:24];
 initial begin $readmemh("model/features.mem",feature_rom);$readmemh("model/stages.mem",stage_rom);end
 reg [13:0] frame_ra,ii_ra,ii_wa; reg ii_we;reg [43:0] ii_wd,ii_q;reg [7:0] pixel_q;
 reg [11:0] node;reg [4:0] stage;reg [119:0] rom_q,feat;reg [31:0] stage_q;
 always @(posedge clk) begin
   if(load_we && load_addr<14400) frame_mem[load_addr]<=load_pixel;
   pixel_q<=frame_mem[frame_ra];debug_pixel<=frame_mem[debug_addr];
   if(ii_we)integral_mem[ii_wa]<=ii_wd;
   ii_q<=integral_mem[ii_ra];
   rom_q<=feature_rom[node];stage_q<=stage_rom[stage];
 end
 localparam IDLE=0,BUILD0=1,BUILD1=2,BUILD2=3,BUILD3=4,WINDOW=5,
 COR0=6,COR1=7,COR2=8,VAR0=9,VAR1=10,VAR2=11,SQ0=12,SQ1=13,
 FEAT0=14,FEAT1=15,FEAT2=16,RECT=17,ACC=18,THR0=19,THR1=20,
 STAGECHECK=21,NEXTWIN=22,DETECT=23,FINISH=24;
 reg [5:0] state;assign debug_state=state;reg [3:0] scale_id;
 reg [1:0] active_phase;reg [2:0] read_cycle;
 reg [4:0] stride;reg [7:0] sw,sh,bx,by,wx,wy;
 reg [11:0] source_x,source_y;
 reg [17:0] row_sum,rect_sum;reg [25:0] row_sq,rect_sq;
 reg [4:0] rx,ry,rw,rh;reg [1:0] corner,rect_id;reg norm_read;
 reg signed [3:0] weight;
 reg [35:0] sq_scaled,mean_sq,variance,trial_sq;
 reg [17:0] root,root_bit,stddev;
 wire [17:0] trial_root=root|root_bit;
 reg signed [23:0] feature_sum,stage_sum;
 reg signed [35:0] threshold_product;
 wire signed [35:0] feature_scaled={{12{feature_sum[23]}},feature_sum} <<< 12;
 wire signed [23:0] leaf=(feature_scaled>=threshold_product)?{{8{feat[119]}},feat[119:104]}:{{8{feat[103]}},feat[103:88]};
 wire signed [23:0] stage_threshold={{4{stage_q[31]}},stage_q[31:12]};
 wire [8:0] cx={1'b0,wx}+rx+(read_cycle[0]?rw:0);
 wire [8:0] cy={1'b0,wy}+ry+(read_cycle[1]?rh:0);
 wire [15:0] px_square=pixel_q*pixel_q;
 wire [17:0] sum_next=row_sum+pixel_q;
 wire [25:0] sq_next=row_sq+px_square;
 wire signed [22:0] weighted_rect=$signed({1'b0,rect_sum})*weight;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n)begin
   state<=IDLE;active_phase<=0;read_cycle<=0;max_stage<=0;busy<=0;done<=0;det_valid<=0;det_x<=0;det_y<=0;det_size<=0;cycles<=0;raw_count<=0;
   ii_we<=0;frame_ra<=0;ii_ra<=0;ii_wa<=0;ii_wd<=0;node<=0;stage<=0;
   scale_id<=0;stride<=8;sw<=160;sh<=90;bx<=0;by<=0;wx<=0;wy<=0;source_x<=0;source_y<=0;
   row_sum<=0;row_sq<=0;rect_sum<=0;rect_sq<=0;corner<=0;rect_id<=0;norm_read<=0;
   rx<=0;ry<=0;rw<=0;rh<=0;weight<=0;feat<=0;feature_sum<=0;stage_sum<=0;
   sq_scaled<=0;mean_sq<=0;variance<=0;trial_sq<=0;root<=0;root_bit<=0;stddev<=1;threshold_product<=0;
 end else begin
   ii_we<=0;done<=0;det_valid<=0;
   if(busy)cycles<=cycles+1'b1;
   case(state)
   IDLE:if(start)begin active_phase<=scan_phase;max_stage<=0;busy<=1;cycles<=0;raw_count<=0;scale_id<=0;stride<=8;sw<=160;sh<=90;bx<=0;by<=0;source_x<=0;source_y<=0;row_sum<=0;row_sq<=0;state<=BUILD0;end
   BUILD0:begin frame_ra<=(source_y>>3)*160+(source_x>>3);ii_ra<=(by==0)?0:(by-1)*160+bx;state<=BUILD1;end
   BUILD1:state<=BUILD2;
   BUILD2:begin
      row_sum<=sum_next;row_sq<=sq_next;ii_wa<=by*160+bx;
      ii_wd[17:0]<=sum_next+((by==0)?18'd0:ii_q[17:0]);
      ii_wd[43:18]<=sq_next+((by==0)?26'd0:ii_q[43:18]);ii_we<=1;state<=BUILD3;
   end
   BUILD3:begin
     if(bx==sw-1)begin bx<=0;source_x<=0;row_sum<=0;row_sq<=0;
       if(by==sh-1)begin wx<=active_phase[0];wy<=active_phase[1];state<=WINDOW;end
       else begin by<=by+1'b1;source_y<=source_y+stride;state<=BUILD0;end
     end else begin bx<=bx+1'b1;source_x<=source_x+stride;state<=BUILD0;end
   end
   WINDOW:begin read_cycle<=0;rx<=0;ry<=0;rw<=24;rh<=24;corner<=0;rect_sum<=0;rect_sq<=0;norm_read<=1;node<=0;stage<=0;stage_sum<=0;state<=COR0;end
   // One address each clock; ii_ra + synchronous RAM impose two clocks of latency.
   // Four corners are issued at clocks 0..3 and accumulated at clocks 2..5.
   COR0:begin
     if(read_cycle<4)ii_ra<=cy*160+cx;
     case(read_cycle)
       2:begin rect_sum<=ii_q[17:0];rect_sq<=ii_q[43:18];end
       3,4:begin rect_sum<=rect_sum-ii_q[17:0];rect_sq<=rect_sq-ii_q[43:18];end
       5:begin rect_sum<=rect_sum+ii_q[17:0];rect_sq<=rect_sq+ii_q[43:18];end
     endcase
     if(read_cycle==5)state<=norm_read?VAR0:ACC;
     else read_cycle<=read_cycle+1'b1;
   end
   VAR0:begin sq_scaled<=rect_sq*10'd576;mean_sq<=rect_sum*rect_sum;state<=VAR1;end
   VAR1:begin variance<=(sq_scaled>mean_sq)?sq_scaled-mean_sq:36'd1;state<=VAR2;end
   VAR2:begin root<=0;root_bit<=18'h20000;state<=SQ0;end
   SQ0:begin trial_sq<=trial_root*trial_root;state<=SQ1;end
   SQ1:begin
     if(trial_sq<=variance)root<=trial_root;
     if(root_bit==1)begin stddev<=(trial_sq<=variance)?trial_root:((root==0)?18'd1:root);state<=FEAT0;end
     else begin root_bit<=root_bit>>1;state<=SQ0;end
   end
   FEAT0:state<=FEAT1;
   FEAT1:begin feat<=rom_q;rect_id<=0;feature_sum<=0;norm_read<=0;state<=FEAT2;end
   FEAT2:begin
     read_cycle<=0;
     rx<=feat[rect_id*20+:5];ry<=feat[rect_id*20+5+:5];rw<=feat[rect_id*20+10+:5];rh<=feat[rect_id*20+15+:5];
     weight<=feat[60+rect_id*4+:4];corner<=0;rect_sum<=0;rect_sq<=0;
     if(feat[60+rect_id*4+:4]==0)begin if(rect_id==2)state<=THR0;else rect_id<=rect_id+1'b1;end
     else state<=COR0;
   end
   ACC:begin feature_sum<=feature_sum+weighted_rect;
     if(rect_id==2)state<=THR0;else begin rect_id<=rect_id+1'b1;state<=FEAT2;end
   end
   THR0:begin threshold_product<=$signed(feat[87:72])*$signed({1'b0,stddev});state<=THR1;end
   THR1:begin stage_sum<=stage_sum+leaf;state<=STAGECHECK;end
   STAGECHECK:begin
     if(node==stage_q[11:0])begin
       if(stage_sum<stage_threshold)state<=NEXTWIN;
       else if(stage==24)begin max_stage<=25;state<=DETECT;end
       else begin if(stage+1>max_stage)max_stage<=stage+1'b1;stage<=stage+1'b1;stage_sum<=0;node<=node+1'b1;state<=FEAT0;end
     end else begin node<=node+1'b1;state<=FEAT0;end
   end
   DETECT:begin det_valid<=1;det_x<=wx*stride+4;det_y<=wy*stride+4;det_size<=24*stride;
     if(raw_count!=16'hffff)raw_count<=raw_count+1'b1;state<=NEXTWIN;end
   NEXTWIN:begin
     if(wx+SCAN_STEP+24<sw)begin wx<=wx+SCAN_STEP;state<=WINDOW;end
     else if(wy+SCAN_STEP+24<sh)begin wx<=active_phase[0];wy<=wy+SCAN_STEP;state<=WINDOW;end
     else if(scale_id==SCALE_COUNT-1)state<=FINISH;
     else begin
       scale_id<=scale_id+1'b1;bx<=0;by<=0;source_x<=0;source_y<=0;row_sum<=0;row_sq<=0;
       case(scale_id)
        0:begin stride<=9;sw<=143;sh<=80;end
        1:begin stride<=10;sw<=128;sh<=72;end
        2:begin stride<=11;sw<=117;sh<=66;end
        3:begin stride<=12;sw<=107;sh<=60;end
        4:begin stride<=14;sw<=92;sh<=52;end
        5:begin stride<=16;sw<=80;sh<=45;end
        6:begin stride<=18;sw<=72;sh<=40;end
        7:begin stride<=20;sw<=64;sh<=36;end
        8:begin stride<=22;sw<=59;sh<=33;end
        9:begin stride<=24;sw<=54;sh<=30;end
        10:begin stride<=26;sw<=50;sh<=28;end
        default:begin stride<=28;sw<=46;sh<=26;end
       endcase
       state<=BUILD0;
     end
   end
   FINISH:begin busy<=0;done<=1;state<=IDLE;end
   default:begin state<=IDLE;busy<=0;end
   endcase
 end end
endmodule
