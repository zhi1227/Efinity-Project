// Palm evidence and motion are separate: tolerate up to six uncertain frames.
// A wave is an excursion and return, either hand translation or wrist rocking.
// Static palm, slow drift, vertical-only motion and non-palms never trigger.
module gesture_wave #(parameter WIDTH=1280,HEIGHT=720,WINDOW=180,HOLD_FRAMES=60,
 LEAN_STEP=18,GRACE=6)(
 input clk,rst_n,enable,frame_done,fault,raw_valid,input[41:0]raw_box,
 input[2:0]raw_class,input lean_valid,input[7:0]lean,
 output reg active,output reg[2:0]phase);
 reg tracked;reg[41:0]previous_box;reg[3:0]history;reg[2:0]missing;
 reg[3:0]credit;reg[7:0]age,hold_count;reg[1:0]dir_x,dir_l;
 reg[10:0]extreme_x,min_x,max_x;reg[7:0]extreme_l,min_l,max_l;
 wire[11:0]cx2={1'b0,raw_box[10:0]}+raw_box[21:11];
 wire[11:0]px2={1'b0,previous_box[10:0]}+previous_box[21:11];
 wire[10:0]cy2={1'b0,raw_box[31:22]}+raw_box[41:32];
 wire[10:0]py2={1'b0,previous_box[31:22]}+previous_box[41:32];
 wire[10:0]cx=cx2[11:1],px=px2[11:1];
 wire[9:0]cy=cy2[10:1],py=py2[10:1];
 wire[10:0]w=raw_box[21:11]-raw_box[10:0]+1,pw=previous_box[21:11]-previous_box[10:0]+1;
 wire[9:0]h=raw_box[41:32]-raw_box[31:22]+1,ph=previous_box[41:32]-previous_box[31:22]+1;
 wire[10:0]dx=cx>px?cx-px:px-cx;wire[9:0]dy=cy>py?cy-py:py-cy;
 wire same=tracked&&dx<=pw/2+WIDTH/16&&dy<=ph/2+HEIGHT/16&&w*2>=pw&&pw*2>=w&&h*2>=ph&&ph*2>=h;
 wire[10:0]step_x=(w>>3)<WIDTH/64?WIDTH/64:((w>>3)>WIDTH/24?WIDTH/24:(w>>3));
 wire[2:0]votes={2'd0,history[0]}+{2'd0,history[1]}+{2'd0,history[2]}+{2'd0,history[3]}+(raw_valid&&raw_class==1);
 wire confirmed=votes>=3;
 wire armed=credit!=0||confirmed;
 wire x_back=(dir_x==1&&cx<extreme_x&&extreme_x-cx>=step_x)||
             (dir_x==2&&cx>extreme_x&&cx-extreme_x>=step_x);
 wire l_back=lean_valid&&((dir_l==1&&lean<extreme_l&&extreme_l-lean>=LEAN_STEP)||
                         (dir_l==2&&lean>extreme_l&&lean-extreme_l>=LEAN_STEP));
 always @(posedge clk)begin
  if(!rst_n||!enable||fault)begin
   active<=0;phase<=0;tracked<=0;previous_box<=0;history<=0;missing<=0;credit<=0;age<=0;hold_count<=0;
   dir_x<=0;dir_l<=0;extreme_x<=0;extreme_l<=120;min_x<=0;max_x<=0;min_l<=120;max_l<=120;
  end else if(frame_done)begin
   history<={history[2:0],raw_valid&&raw_class==1};
   if(!raw_valid)begin
    active<=0;phase<=0;
    if(credit!=0)credit<=credit-1'b1;
    if(missing<3)missing<=missing+1'b1;
    if(missing>=2)begin tracked<=0;credit<=0;age<=0;hold_count<=0;dir_x<=0;dir_l<=0;history<=0;end
   end else if(!same)begin
    tracked<=1;previous_box<=raw_box;history<={3'd0,raw_class==1};missing<=0;credit<=0;age<=0;hold_count<=0;
    dir_x<=0;dir_l<=0;extreme_x<=cx;extreme_l<=lean;min_x<=cx;max_x<=cx;min_l<=lean;max_l<=lean;active<=0;phase<=1;
   end else begin
    previous_box<=raw_box;missing<=0;active<=0;
    if(raw_class==2||raw_class==3)begin
     credit<=0;history<=0;age<=0;hold_count<=0;dir_x<=0;dir_l<=0;extreme_x<=cx;extreme_l<=lean;min_x<=cx;max_x<=cx;min_l<=lean;max_l<=lean;phase<=1;
    end else begin
     if(raw_class==1&&(confirmed||credit!=0))credit<=GRACE;
     else if(credit!=0)credit<=credit-1'b1;
     if(!armed)begin
      phase<=1;age<=0;hold_count<=0;dir_x<=0;dir_l<=0;extreme_x<=cx;extreme_l<=lean;min_x<=cx;max_x<=cx;min_l<=lean;max_l<=lean;
     end else if(hold_count!=0)begin active<=1;phase<=4;hold_count<=hold_count-1'b1;end
     else if(age>=WINDOW)begin phase<=2;age<=0;dir_x<=0;dir_l<=0;extreme_x<=cx;extreme_l<=lean;min_x<=cx;max_x<=cx;min_l<=lean;max_l<=lean;end
     else begin
      age<=age+1'b1;phase<=(dir_x!=0||dir_l!=0)?3:2;
      // Do not generate an event using a stale lean value from a blurred frame.
      if((x_back||l_back)&&raw_class==1)begin active<=1;phase<=4;hold_count<=HOLD_FRAMES-1;age<=0;dir_x<=0;dir_l<=0;min_x<=cx;max_x<=cx;min_l<=lean;max_l<=lean;end
      else begin
       if(dir_x==0)begin
        // Track both ends before choosing direction. A hand starting in the
        // middle must not require twice the useful peak-to-peak amplitude.
        if(cx<min_x)min_x<=cx;if(cx>max_x)max_x<=cx;
        if(cx>min_x&&cx-min_x>=step_x)begin dir_x<=1;extreme_x<=cx;end
        else if(cx<max_x&&max_x-cx>=step_x)begin dir_x<=2;extreme_x<=cx;end
       end else if(dir_x==1&&cx>extreme_x)extreme_x<=cx;
       else if(dir_x==2&&cx<extreme_x)extreme_x<=cx;
       if(lean_valid)begin
        if(dir_l==0)begin
         if(lean<min_l)min_l<=lean;if(lean>max_l)max_l<=lean;
         if(lean>min_l&&lean-min_l>=LEAN_STEP)begin dir_l<=1;extreme_l<=lean;end
         else if(lean<max_l&&max_l-lean>=LEAN_STEP)begin dir_l<=2;extreme_l<=lean;end
        end else if(dir_l==1&&lean>extreme_l)extreme_l<=lean;
        else if(dir_l==2&&lean<extreme_l)extreme_l<=lean;
       end
      end
     end
    end
   end
  end
 end
endmodule
