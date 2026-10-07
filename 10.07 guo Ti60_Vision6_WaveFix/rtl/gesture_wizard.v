// Button-only enrolment. Mode change cancels wizard but preserves saved models.
// K2 long: start/restart; K2 short: two-second countdown then capture.
module gesture_wizard #(parameter COUNTDOWN_FRAMES=120,SETTLE_FRAMES=15,TIMEOUT_FRAMES=360)(
 input clk,rst_n,mode_on,frame_tick,short_press,long_press,
 input skin_done,skin_ok,capture_done,capture_ok,input[1:0]capture_error,
 output reg busy,output reg clear,skin_sample,output reg[2:0]learn,
 output reg[2:0]step,state,output reg[1:0]error,output reg[7:0]countdown);
 reg[9:0]frames;
 // state: 0 off,1 pose/confirm,2 countdown,3 colour,4 settle,5 capture,6 retry.
 always @(posedge clk)begin
  clear<=0;skin_sample<=0;learn<=0;
  if(!rst_n)begin busy<=0;step<=0;state<=0;error<=0;frames<=0;countdown<=0;end
  else if(!mode_on)begin busy<=0;step<=0;state<=0;frames<=0;error<=0;end
  else if(long_press)begin busy<=1;step<=1;state<=1;error<=0;frames<=0;clear<=1;countdown<=0;end
  else if(busy)begin
   if((state==1||state==6)&&short_press)begin state<=2;frames<=0;error<=0;countdown<=COUNTDOWN_FRAMES;end
   else if(state==3&&skin_done)begin
    frames<=0;if(skin_ok)state<=4;else begin state<=6;error<=1;end
   end else if(state==5&&capture_done)begin
    frames<=0;
    if(!capture_ok)begin state<=6;error<=capture_error==2?2:3;end
    else if(step==3)begin busy<=0;step<=0;state<=0;end
    else begin step<=step+1'b1;state<=1;end
   end else if(frame_tick)begin
    if(state==2)begin
     if(frames==COUNTDOWN_FRAMES-1)begin
      frames<=0;countdown<=0;
      if(step==1)begin skin_sample<=1;state<=3;end else state<=4;
     end else begin frames<=frames+1'b1;countdown<=countdown-1'b1;end
    end else if(state==4)begin
     if(frames==SETTLE_FRAMES-1)begin learn<=step;state<=5;frames<=0;end else frames<=frames+1'b1;
    end else if(state==3||state==5)begin
     if(frames==TIMEOUT_FRAMES-1)begin state<=6;error<=3;frames<=0;end else frames<=frames+1'b1;
    end
   end
  end
 end
endmodule
