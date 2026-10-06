`include "hand_config.vh"
// A new 128x128 ROI from ORIGINAL RGB: mean of every 4x4 block.
// It is not an enlargement of the old 128x72 tracking thumbnail.
module hand_capture #(parameter X0=`HAND_X0,Y0=`HAND_Y0)(
 input clk,rst_n,frame_start,enable,de,input[10:0]x,input[9:0]y,
 input[23:0]rgb,input[1:0]profile,
 output reg we,output reg[13:0]addr,output reg skin,output reg done);
 wire in_roi=x>=X0&&x<X0+512&&y>=Y0&&y<Y0+512;
 wire[8:0]rx=x-X0,ry=y-Y0;
 reg active,pending;reg[1:0]saved_profile;
 reg[9:0]hr,hg,hb;reg[11:0]vr[0:127],vg[0:127],vb[0:127];
 wire[10:0]sr={1'b0,hr}+rgb[23:16],sg={1'b0,hg}+rgb[15:8],sb={1'b0,hb}+rgb[7:0];
 wire[12:0]tr=(ry[1:0]==0)?sr:({1'b0,vr[rx[8:2]]}+sr);
 wire[12:0]tg=(ry[1:0]==0)?sg:({1'b0,vg[rx[8:2]]}+sg);
 wire[12:0]tb=(ry[1:0]==0)?sb:({1'b0,vb[rx[8:2]]}+sb);
 reg pixel_valid;reg[13:0]pixel_addr;reg[7:0]r,g,b;
 wire signed[18:0]cb_sum=19'sd32768-($signed({1'b0,r})*19'sd43)-($signed({1'b0,g})*19'sd85)+($signed({1'b0,b})*19'sd128);
 wire signed[18:0]cr_sum=19'sd32768+($signed({1'b0,r})*19'sd128)-($signed({1'b0,g})*19'sd107)-($signed({1'b0,b})*19'sd21);
 wire[15:0]ysum=r*16'd77+g*16'd150+b*16'd29;
 wire[7:0]cb=cb_sum[15:8],cr=cr_sum[15:8];
 wire loose=saved_profile==1,strict=saved_profile==2;
 wire hit=ysum[15:8]>=25&&cb>=(loose?65:(strict?82:77))&&cb<=(loose?135:(strict?122:127))
       &&cr>=(loose?128:(strict?138:133))&&cr<=(loose?185:(strict?173:180));
 always @(posedge clk)begin
 if(!rst_n)begin active<=0;pending<=0;we<=0;done<=0;pixel_valid<=0;addr<=0;skin<=0;
   hr<=0;hg<=0;hb<=0;pixel_addr<=0;r<=0;g<=0;b<=0;saved_profile<=0;
 end else begin
   we<=pixel_valid;addr<=pixel_addr;skin<=hit;done<=pending;pending<=0;pixel_valid<=0;
   if(pixel_valid&&pixel_addr==16383)pending<=1;
   if(frame_start)begin active<=enable;hr<=0;hg<=0;hb<=0;saved_profile<=profile;end
   else if(active&&de&&in_roi)begin
     if(rx[1:0]==3)begin
       hr<=0;hg<=0;hb<=0;vr[rx[8:2]]<=tr;vg[rx[8:2]]<=tg;vb[rx[8:2]]<=tb;
       if(ry[1:0]==3)begin pixel_valid<=1;pixel_addr<={ry[8:2],rx[8:2]};r<=tr[11:4];g<=tg[11:4];b<=tb[11:4];end
       if(rx==511&&ry==511)active<=0;
     end else begin hr<=sr;hg<=sg;hb<=sb;end
   end
 end
 end
endmodule
