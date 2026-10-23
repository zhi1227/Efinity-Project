// Experimental ONE stationary shape on a plain background inside central ROI.
// Sobel edges -> measured bounding box -> next-frame perimeter/radius support.
// Not face detection, Hough, semantic recognition or arbitrary-scene multi-object CCL.
// Result clears on empty/rejected frames; first observation has no class.
module edge_shape_roi #(parameter WIDTH=1280,HEIGHT=720,BAND=6,MIN_SIZE=32,MIN_EDGES=80)(
 input clk,rst_n,frame_start,de,edge_pixel,input [10:0] x,input [9:0] y,
 output reg [1:0] shape_class,output reg [41:0] box);
 localparam X0=WIDTH/4,X1=WIDTH*3/4-1,Y0=HEIGHT/4,Y1=HEIGHT*3/4-1;
 reg [10:0] xmin,xmax,rx0,rx1;reg [9:0] ymin,ymax,ry0,ry1;
 reg reference_valid;
 wire [11:0] rw={1'b0,rx1}-{1'b0,rx0}+12'd1;
 wire [10:0] rh={1'b0,ry1}-{1'b0,ry0}+11'd1;
 wire [11:0] cx=({1'b0,rx0}+{1'b0,rx1})>>1;
 wire [10:0] cy=({1'b0,ry0}+{1'b0,ry1})>>1;
 wire [11:0] radius=(rw+{1'b0,rh})>>2;
 wire [11:0] rlo=(radius>BAND)?radius-BAND:0,rhi=radius+BAND;
 wire [23:0] low2=rlo*rlo,high2=rhi*rhi;
 reg [11:0] dx1,dy1;reg [23:0] dx2,dy2;
 reg [10:0] x1,x2;reg [9:0] y1,y2;
 reg e1,e2,fs1,fs2;reg [3:0] side1,side2;reg [1:0] quadrant1,quadrant2;
 wire [24:0] distance2={1'b0,dx2}+{1'b0,dy2};
 wire in_roi=x>=X0 && x<=X1 && y>=Y0 && y<=Y1;
 // Side strips also require being near the measured box in the other axis.
 wire in_ref=x+BAND>=rx0 && x<=rx1+BAND && y+BAND>=ry0 && y<=ry1+BAND;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
   e1<=0;e2<=0;fs1<=0;fs2<=0;dx1<=0;dy1<=0;dx2<=0;dy2<=0;
   x1<=0;x2<=0;y1<=0;y2<=0;side1<=0;side2<=0;quadrant1<=0;quadrant2<=0;
 end else begin
   fs1<=frame_start;fs2<=fs1;e1<=de && edge_pixel && in_roi;e2<=e1;
   x1<=x;y1<=y;x2<=x1;y2<=y1;
   dx1<=({1'b0,x}>=cx)?{1'b0,x}-cx:cx-{1'b0,x};
   dy1<=({1'b0,y}>=cy)?{1'b0,y}-cy:cy-{1'b0,y};
   dx2<=dx1*dx1;dy2<=dy1*dy1;
   side1<={in_ref && y+BAND>=ry1 && y<=ry1+BAND,
           in_ref && y+BAND>=ry0 && y<=ry0+BAND,
           in_ref && x+BAND>=rx1 && x<=rx1+BAND,
           in_ref && x+BAND>=rx0 && x<=rx0+BAND};
   side2<=side1;quadrant1<={y>=cy,x>=cx};quadrant2<=quadrant1;
 end
 reg [19:0] total,perimeter,radial;
 reg [19:0] left_n,right_n,top_n,bottom_n,q0,q1,q2,q3;
 wire [11:0] width_now={1'b0,xmax}-{1'b0,xmin}+12'd1;
 wire [10:0] height_now={1'b0,ymax}-{1'b0,ymin}+11'd1;
 wire stable_box=xmin+BAND>=rx0 && rx0+BAND>=xmin && xmax+BAND>=rx1 && rx1+BAND>=xmax
   && ymin+BAND>=ry0 && ry0+BAND>=ymin && ymax+BAND>=ry1 && ry1+BAND>=ymax;
 wire eligible=reference_valid && total>=MIN_EDGES && width_now>=MIN_SIZE && height_now>=MIN_SIZE
   && xmin>X0+BAND && xmax<X1-BAND && ymin>Y0+BAND && ymax<Y1-BAND && stable_box;
 // Reject filled/noisy ROIs. Threshold is generous for the 2-pixel Sobel outline.
 wire sparse=total<((width_now+height_now)*12);
 wire rect_ok=perimeter*100>=total*85 && left_n>=(height_now>>1) && right_n>=(height_now>>1)
   && top_n>=(width_now>>1) && bottom_n>=(width_now>>1);
 wire circle_ok=radial*100>=total*85 && width_now*100>=height_now*85 && width_now*100<=height_now*115
   && q0*10>=total && q1*10>=total && q2*10>=total && q3*10>=total;
 always @(posedge clk or negedge rst_n)
 if(!rst_n) begin
   xmin<=WIDTH-1;xmax<=0;ymin<=HEIGHT-1;ymax<=0;
   rx0<=0;rx1<=0;ry0<=0;ry1<=0;reference_valid<=0;shape_class<=0;box<=0;
   total<=0;perimeter<=0;radial<=0;left_n<=0;right_n<=0;top_n<=0;bottom_n<=0;
   q0<=0;q1<=0;q2<=0;q3<=0;
 end else if(fs2) begin
   shape_class<=0;box<=0;
   if(eligible && sparse) begin
     if(rect_ok) begin shape_class<=1;box<={ymax,ymin,xmax,xmin};end
     else if(circle_ok) begin shape_class<=2;box<={ymax,ymin,xmax,xmin};end
   end
   reference_valid<=total>=MIN_EDGES;
   rx0<=xmin;rx1<=xmax;ry0<=ymin;ry1<=ymax;
   xmin<=WIDTH-1;xmax<=0;ymin<=HEIGHT-1;ymax<=0;
   total<=0;perimeter<=0;radial<=0;left_n<=0;right_n<=0;top_n<=0;bottom_n<=0;
   q0<=0;q1<=0;q2<=0;q3<=0;
 end else if(e2) begin
   if(x2<xmin)xmin<=x2;if(x2>xmax)xmax<=x2;
   if(y2<ymin)ymin<=y2;if(y2>ymax)ymax<=y2;
   total<=total+1'b1;
   if(reference_valid) begin
     if(|side2)perimeter<=perimeter+1'b1;
     if(side2[0])left_n<=left_n+1'b1;if(side2[1])right_n<=right_n+1'b1;
     if(side2[2])top_n<=top_n+1'b1;if(side2[3])bottom_n<=bottom_n+1'b1;
     if(distance2>=low2 && distance2<=high2)radial<=radial+1'b1;
     case(quadrant2)
       0:q0<=q0+1'b1;1:q1<=q1+1'b1;2:q2<=q2+1'b1;3:q3<=q3+1'b1;
     endcase
   end
 end
endmodule
