// Confirm the same target with a 5-of-7 vote. Hold at most two missing frames.
// Wave requires a confirmed open palm and two large direction reversals.
module gesture_stabilizer #(parameter WIDTH=1280,HEIGHT=720,
 WAVE_STEP=WIDTH/32,WAVE_WINDOW=90,WAVE_HOLD=30)(
 input clk,rst_n,enable,frame_done,fault,raw_valid,input[41:0]raw_box,
 input[2:0]raw_class,output reg box_valid,output reg[41:0]box,
 output reg[2:0]gesture);
 reg[2:0]history[0:5];reg[1:0]missing;
 wire[11:0]cx_sum={1'b0,raw_box[10:0]}+{1'b0,raw_box[21:11]};
 wire[11:0]px_sum={1'b0,box[10:0]}+{1'b0,box[21:11]};
 wire[10:0]cy_sum={1'b0,raw_box[31:22]}+{1'b0,raw_box[41:32]};
 wire[10:0]py_sum={1'b0,box[31:22]}+{1'b0,box[41:32]};
 wire[10:0]cx=cx_sum[11:1],px=px_sum[11:1];
 wire[9:0]cy=cy_sum[10:1],py=py_sum[10:1];
 wire[10:0]dx=cx>px?cx-px:px-cx;
 wire[9:0]dy=cy>py?cy-py:py-cy;
 wire[10:0]pw=box[21:11]-box[10:0]+1,rw=raw_box[21:11]-raw_box[10:0]+1;
 wire[9:0]ph=box[41:32]-box[31:22]+1,rh=raw_box[41:32]-raw_box[31:22]+1;
 wire same=box_valid&&dx<=(pw>>1)+WIDTH/16&&dy<=(ph>>1)+HEIGHT/16&&
           {1'b0,rw}*2>=pw&&{1'b0,pw}*2>=rw&&{1'b0,rh}*2>=ph&&{1'b0,ph}*2>=rh;
 reg[2:0]winner;integer i,k,n;
 always @*begin
  winner=0;n=0;
  for(k=1;k<=3;k=k+1)begin
   n=(raw_valid&&raw_class==k)?1:0;
   for(i=0;i<6;i=i+1)if(history[i]==k)n=n+1;
   if(n>=5)winner=k;
  end
 end
 reg[1:0]direction,turns;reg[10:0]extreme;
 reg[6:0]age;reg[5:0]wave_hold;
 integer j;
 always @(posedge clk)begin
  if(!rst_n||!enable||fault)begin
   box_valid<=0;box<=0;gesture<=0;missing<=0;
   direction<=0;turns<=0;extreme<=0;age<=0;wave_hold<=0;
   for(j=0;j<6;j=j+1)history[j]<=0;
  end else if(frame_done)begin
   if(!raw_valid)begin
    for(j=5;j>0;j=j-1)history[j]<=history[j-1];history[0]<=0;
    if(age<WAVE_WINDOW)age<=age+1'b1;
    if(missing==2)begin box_valid<=0;box<=0;gesture<=0;direction<=0;turns<=0;age<=0;wave_hold<=0;end
    else begin missing<=missing+1'b1;if(gesture==1)gesture<=0;end
   end else if(!same)begin
    box_valid<=1;box<=raw_box;gesture<=0;missing<=0;
    for(j=0;j<6;j=j+1)history[j]<=0;history[0]<=raw_class;
    direction<=0;turns<=0;extreme<=cx;age<=0;wave_hold<=0;
   end else begin
    box_valid<=1;box<=raw_box;missing<=0;
    for(j=5;j>0;j=j-1)history[j]<=history[j-1];history[0]<=raw_class;
    gesture<=winner==1?3'd0:winner;
    if(winner!=1)begin direction<=0;turns<=0;age<=0;wave_hold<=0;extreme<=cx;end
    else if(wave_hold!=0)begin gesture<=1;wave_hold<=wave_hold-1'b1;end
    else if(raw_class!=1)begin if(age<WAVE_WINDOW)age<=age+1'b1;end
    else begin
     if(age>=WAVE_WINDOW)begin direction<=0;turns<=0;age<=0;extreme<=cx;end
     else begin
      age<=age+1'b1;
      if(direction==0)begin
       if(cx>extreme&&cx-extreme>=WAVE_STEP)begin direction<=1;extreme<=cx;end
       else if(cx<extreme&&extreme-cx>=WAVE_STEP)begin direction<=2;extreme<=cx;end
      end else if(direction==1)begin
       if(cx>extreme)extreme<=cx;
       else if(extreme-cx>=WAVE_STEP)begin
        direction<=2;extreme<=cx;
        if(turns==1)begin gesture<=1;wave_hold<=WAVE_HOLD;turns<=0;direction<=0;age<=0;end
        else turns<=turns+1'b1;
       end
      end else begin
       if(cx<extreme)extreme<=cx;
       else if(cx-extreme>=WAVE_STEP)begin
        direction<=1;extreme<=cx;
        if(turns==1)begin gesture<=1;wave_hold<=WAVE_HOLD;turns<=0;direction<=0;age<=0;end
        else turns<=turns+1'b1;
       end
      end
     end
    end
   end
  end
 end
endmodule
