module parallel_overlay #(parameter MAX_FACES=8, THICKNESS=2, WIDTH=1280, HEIGHT=720,HUD_ENABLE=0)(
 input clk,rst_n,input [3:0] mode,input [23:0] rgb,input de,vs,hs,
 input [10:0] x,input [9:0] y,input edge_pixel,
 input [3:0] count,input [MAX_FACES*42-1:0] boxes,
 input [7:0] gray_pixel,input compare_edge,
 output reg [23:0] rgb_o,output reg de_o,vs_o,hs_o,
 input [7:0] median_strength,
 input raw_edge,frozen);
 wire hud_area,hud_ink;
 vision_hud u_hud(x,y,mode,frozen,hud_area,hud_ink);
 integer i;reg border;reg [10:0] x0,x1;reg [9:0] y0,y1;reg [23:0] colour;
 always @* begin
 border=0;x0=0;x1=0;y0=0;y1=0;
 for(i=0;i<MAX_FACES;i=i+1) begin
 x0=boxes[i*42+:11];x1=boxes[i*42+11+:11];y0=boxes[i*42+22+:10];y1=boxes[i*42+32+:10];
 if(i<count && x>=x0 && x<=x1 && y>=y0 && y<=y1) begin
 if(x-x0<THICKNESS || x1-x<THICKNESS || y-y0<THICKNESS || y1-y<THICKNESS) border=1;
 end
 end
 case(mode)
 0:colour=rgb;
 1:colour=edge_pixel?24'hffffff:0;
 3:colour=border?24'hff0000:(edge_pixel?24'hffffff:0);
 // Same-frame unscaled split, not two resized full images.
 5:colour=(x==WIDTH/2)?24'h00ffff:((x<WIDTH/2)?{gray_pixel,gray_pixel,gray_pixel}:(compare_edge?24'hffffff:0));
 10:colour=raw_edge?24'hff0000:rgb;
 13:colour={median_strength,median_strength,median_strength};
 default:colour=rgb;
 endcase
 if(HUD_ENABLE && hud_area)colour=hud_ink?(frozen?24'hffff00:24'hffffff):24'h101020;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
 else begin rgb_o<=de?colour:0;de_o<=de;vs_o<=vs;hs_o<=hs;end
endmodule
