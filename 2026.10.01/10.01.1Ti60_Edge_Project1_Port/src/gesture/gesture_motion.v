// Deliberately restricted: one blob, two opposite-zone crossings (L-R-L/R-L-R).
module gesture_motion #(parameter WINDOW=60,COOLDOWN=45)(
 input clk,rst_n,frame_start,sample,input [2:0] count,input [5:0] cx,
 output reg wave,output reg [7:0] events);
 reg [1:0] previous_zone;reg [1:0] turns;
 reg [6:0] elapsed,cooldown,missing;
 wire [1:0] zone=(cx<26)?1:((cx>38)?2:0);
 always @(posedge clk)begin
 if(!rst_n)begin
   previous_zone<=0;turns<=0;elapsed<=0;cooldown<=0;missing<=0;wave<=0;events<=0;
 end else begin
   if(frame_start)begin
     if(cooldown!=0)begin cooldown<=cooldown-1'b1;if(cooldown==1)wave<=0;end
     if(elapsed<WINDOW)elapsed<=elapsed+1'b1;
     else begin turns<=0;previous_zone<=0;end
     if(missing<10)missing<=missing+1'b1;
     else begin turns<=0;previous_zone<=0;end
   end
   if(sample)begin
     missing<=0;
     if(count!=1)begin turns<=0;previous_zone<=0;elapsed<=0;end
     else if(cooldown==0 && zone!=0)begin
       if(previous_zone==0 || elapsed>=WINDOW || missing>=10)begin previous_zone<=zone;turns<=0;elapsed<=0;end
       else if(zone!=previous_zone)begin
         previous_zone<=zone;
         if(turns==1)begin
           wave<=1;events<=events+1'b1;cooldown<=COOLDOWN;
           turns<=0;previous_zone<=0;elapsed<=0;
         end else turns<=turns+1'b1;
       end
     end
   end
 end
 end
endmodule
