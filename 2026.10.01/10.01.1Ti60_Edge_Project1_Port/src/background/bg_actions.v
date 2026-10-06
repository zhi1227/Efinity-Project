// Frame-time state machine; samples may arrive only every 2-3 display frames.
// Events: 1 LEFT, 2 RIGHT, 3 WAVE, 4 HOLD. Single pulse per accepted event.
module bg_actions #(parameter WINDOW=90,COOLDOWN=45,DWELL=60,STALE=6,MAX_JUMP=24)(
 input clk,rst_n,frame_start,sample,valid,input[6:0]x,y,
 output reg[2:0]event_code,output reg event_pulse,
 output reg[7:0]event_count,output reg[6:0]hold_progress
);
 reg[6:0]age,timer,cooldown,event_hold;reg[1:0]zone,previous_zone,stable;
 reg have_target,hold_latched,center;reg[6:0]last_x,last_y;reg crossed;
 wire[1:0]new_zone=(x<52)?1:((x>75)?2:0);
 wire new_center=x>=55&&x<=72&&y>=25&&y<=50;
 wire[6:0]dx=(x>last_x)?x-last_x:last_x-x;
 wire[6:0]dy=(y>last_y)?y-last_y:last_y-y;
 wire lost=age>=STALE;
 always @(posedge clk)begin
 if(!rst_n)begin
   age<=STALE;timer<=0;cooldown<=0;event_hold<=0;zone<=0;previous_zone<=0;stable<=0;
   have_target<=0;hold_latched<=0;center<=0;last_x<=0;last_y<=0;crossed<=0;
   event_code<=0;event_pulse<=0;event_count<=0;hold_progress<=0;
 end else begin
   event_pulse<=0;
   if(frame_start)begin
     if(age<127)age<=age+1'b1;
     if(timer<WINDOW)timer<=timer+1'b1;
     if(cooldown!=0)cooldown<=cooldown-1'b1;
     if(event_hold!=0)begin event_hold<=event_hold-1'b1;if(event_hold==1)event_code<=0;end
     if(lost)begin have_target<=0;stable<=0;previous_zone<=0;crossed<=0;hold_progress<=0;hold_latched<=0;end
     else if(center&&stable==3&&!hold_latched&&cooldown==0&&(!sample||(valid&&new_center&&dx<=MAX_JUMP&&dy<=MAX_JUMP)))begin
       if(hold_progress==DWELL-1)begin
         event_code<=4;event_pulse<=1;event_count<=event_count+1'b1;event_hold<=60;
         hold_latched<=1;hold_progress<=DWELL;cooldown<=COOLDOWN;
         previous_zone<=0;crossed<=0;
       end else if(hold_progress<DWELL)hold_progress<=hold_progress+1'b1;
     end else if(!center)begin hold_progress<=0;hold_latched<=0;end
   end
   if(sample)begin
     age<=0;last_x<=x;last_y<=y;center<=new_center;zone<=new_zone;
     if(!valid)begin
       have_target<=0;stable<=0;previous_zone<=0;crossed<=0;center<=0;hold_progress<=0;hold_latched<=0;
     end else if(!have_target||lost||dx>MAX_JUMP||dy>MAX_JUMP)begin
       have_target<=1;stable<=1;previous_zone<=new_zone;crossed<=0;timer<=0;
       hold_progress<=0;hold_latched<=0;
     end else begin
       if(stable<3)stable<=stable+1'b1;
       if(cooldown==0&&stable>=2&&new_zone!=0)begin
         if(previous_zone==0||timer>=WINDOW)begin previous_zone<=new_zone;crossed<=0;timer<=0;end
         else if(new_zone==previous_zone&&!crossed)timer<=0;
         else if(new_zone!=previous_zone)begin
           previous_zone<=new_zone;
           event_pulse<=1;event_count<=event_count+1'b1;event_hold<=60;
           if(crossed)begin event_code<=3;cooldown<=COOLDOWN;crossed<=0;previous_zone<=0;end
           else begin event_code<=(new_zone==1)?1:2;crossed<=1;timer<=0;end
         end
       end
     end
   end
 end
 end
endmodule

