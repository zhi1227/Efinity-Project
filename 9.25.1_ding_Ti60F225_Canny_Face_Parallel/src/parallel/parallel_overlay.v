module parallel_overlay #(parameter MAX_FACES=8, THICKNESS=2, WIDTH=1280, HEIGHT=720, DEBUG_BOXES=0,HUD_ENABLE=0)(
 input clk,rst_n,input [3:0] mode,input [23:0] rgb,input de,vs,hs,
 input [10:0] x,input [9:0] y,input edge_pixel,
 input [3:0] count,input [MAX_FACES*42-1:0] boxes,
 input [7:0] gray_pixel,input compare_edge,raw_skin,clean_skin,
 output reg [23:0] rgb_o,output reg de_o,vs_o,hs_o,
 input [7:0] raw_strength,median_pixel,median_strength,
 input raw_edge,frozen,input [1:0] shape_class,input [41:0] shape_box);
 reg [23:0] neon;
 always @* begin
   if(raw_strength<24)neon=0;
   else if(raw_strength<64)neon={8'd0,raw_strength,raw_strength[5:0],2'b00};
   else if(raw_strength<128)neon=24'h00ffff;
   else if(raw_strength<192)neon={raw_strength,8'h20,8'hff};
   else neon=24'hff40e0;
 end
 wire hud_area,hud_ink;
 vision_hud u_hud(x,y,mode,frozen,shape_class,hud_area,hud_ink);
 wire [10:0] bx0=shape_box[10:0],bx1=shape_box[21:11];
 wire [9:0] by0=shape_box[31:22],by1=shape_box[41:32];
 wire shape_border=shape_class!=0 && x>=bx0 && x<=bx1 && y>=by0 && y<=by1
   && (x-bx0<2 || bx1-x<2 || y-by0<2 || by1-y<2);
 wire roi_border=x>=WIDTH/4 && x<WIDTH*3/4 && y>=HEIGHT/4 && y<HEIGHT*3/4
   && (x==WIDTH/4 || x==WIDTH*3/4-1 || y==HEIGHT/4 || y==HEIGHT*3/4-1);
 integer i;reg inside_box,border;reg [10:0] x0,x1;reg [9:0] y0,y1;reg [23:0] colour;
 always @* begin
 inside_box=0;border=0;x0=0;x1=0;y0=0;y1=0;
 for(i=0;i<MAX_FACES;i=i+1) begin
 x0=boxes[i*42+:11];x1=boxes[i*42+11+:11];y0=boxes[i*42+22+:10];y1=boxes[i*42+32+:10];
 if(i<count && x>=x0 && x<=x1 && y>=y0 && y<=y1) begin
 inside_box=1;
 if(x-x0<THICKNESS || x1-x<THICKNESS || y-y0<THICKNESS || y1-y<THICKNESS) border=1;
 end
 end
 case(mode)
 0:colour=rgb;
 1:colour=edge_pixel?24'hffffff:0;
 2:colour=border?24'hff0000:(edge_pixel?(inside_box?24'hffff00:24'h00ff00):rgb);
 3:colour=border?24'hff0000:(edge_pixel?24'hffffff:0);
 4:colour=border?24'hff0000:(edge_pixel?(inside_box?24'hffff00:24'h303030):0);
 // Same-frame unscaled split, not two resized full images.
 5:colour=(x==WIDTH/2)?24'h00ffff:((x<WIDTH/2)?{gray_pixel,gray_pixel,gray_pixel}:(compare_edge?24'hffffff:0));
 6:colour=(DEBUG_BOXES && border)?24'hff0000:(raw_skin?24'hffffff:0);
 7:colour=(DEBUG_BOXES && border)?24'hff0000:(clean_skin?24'hffffff:0);
 8:colour={raw_strength,raw_strength,raw_strength};
 9:colour=neon;
 10:colour=raw_edge?24'hff0000:rgb;
 11:colour=(x==WIDTH/2)?24'h00ffff:((x<WIDTH/2)?{gray_pixel,gray_pixel,gray_pixel}:{median_pixel,median_pixel,median_pixel});
 12:colour=shape_border?((shape_class==1)?24'h00ff00:24'hff00ff):(roi_border?24'h00ffff:(compare_edge?24'hffffff:rgb));
 13:colour={median_strength,median_strength,median_strength};
 default:colour=rgb;
 endcase
 if(HUD_ENABLE && hud_area)colour=hud_ink?(frozen?24'hffff00:24'hffffff):24'h101020;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de?colour:0;de_o<=de;vs_o<=vs;hs_o<=hs;end
endmodule
