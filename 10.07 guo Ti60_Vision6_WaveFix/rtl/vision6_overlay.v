`include "gesture_config.vh"
module vision6_overlay #(parameter WIDTH=1280,HEIGHT=720,MAX_FACES=8,HUD_ENABLE=1,GESTURE_DEBUG=0)(
 input clk,rst_n,input[3:0]mode,input[23:0]rgb,input de,vs,hs,
 input[10:0]x,input[9:0]y,input edge_pixel,raw_edge,compare_edge,
 input[7:0]raw_strength,gray_pixel,input frozen,pure_en,detect,
 input[3:0]count,input[MAX_FACES*42-1:0]boxes,
 input[1:0]shape_class,input[41:0]shape_box,
 input hand_valid,input[41:0]hand_box,input[2:0]gesture,input hand_skin,
 input[7:0]health,
 input hand_enable,hand_overflow,input[19:0]debug_raw,debug_clean,debug_ratio,
 input[9:0]debug_fill,input[3:0]debug_reject,debug_fault,input[2:0]debug_class,input[7:0]debug_lower,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,
 input[2:0]learn_step,learn_state,trained,input[1:0]learn_error,input[7:0]learn_countdown,
 input[255:0]preview,input preview_valid,input[2:0]wave_phase);
 wire preview_area=x>=1100&&x<1228&&y>=478&&y<606;
 wire[3:0]preview_x=(x-1100)>>3,preview_y=(y-478)>>3;
 wire crosshair=learn_step==1&&((x>=WIDTH*7/16-18&&x<=WIDTH*7/16+18&&
  (y==HEIGHT/2-18||y==HEIGHT/2+18))||(y>=HEIGHT/2-18&&y<=HEIGHT/2+18&&
  (x==WIDTH*7/16-18||x==WIDTH*7/16+18)));
 reg[23:0]neon,colour;reg face_border;integer i;reg[10:0]bx0,bx1;reg[9:0]by0,by1;
 wire hand_here=hand_valid&&x>=hand_box[10:0]&&x<=hand_box[21:11]&&y>=hand_box[31:22]&&y<=hand_box[41:32];
 wire hand_border=hand_here&&(x-hand_box[10:0]<2||hand_box[21:11]-x<2||y-hand_box[31:22]<2||hand_box[41:32]-y<2);
 wire diag_area,diag_ink;
 gesture_diag_hud diag(x,y,debug_raw,debug_clean,hand_valid,debug_fault,debug_reject,debug_fill,debug_ratio,debug_lower,diag_area,diag_ink);
 wire[10:0]sx0=shape_box[10:0],sx1=shape_box[21:11];
 wire[9:0]sy0=shape_box[31:22],sy1=shape_box[41:32];
 wire shape_border=shape_class!=0&&x>=sx0&&x<=sx1&&y>=sy0&&y<=sy1&&(x-sx0<2||sx1-x<2||y-sy0<2||sy1-y<2);
 wire roi_border=x>=WIDTH/4&&x<WIDTH*3/4&&y>=HEIGHT/4&&y<HEIGHT*3/4&&(x==WIDTH/4||x==WIDTH*3/4-1||y==HEIGHT/4||y==HEIGHT*3/4-1);
 wire guide=x>=`HAND_X0&&x<=`HAND_X1&&y>=`HAND_Y0&&y<=`HAND_Y1&&
  (x-`HAND_X0<2||`HAND_X1-x<2||y-`HAND_Y0<2||`HAND_Y1-y<2);
 reg vs_prev;reg[5:0]animation;
 always @(posedge clk)if(!rst_n)begin vs_prev<=1;animation<=0;end
 else begin vs_prev<=vs;if(vs&&!vs_prev)animation<=animation+1'b1;end
 wire paint;wire[23:0]avatar_rgb;
 gesture_matrix8 avatar(x,y,(mode==15&&hand_valid)?gesture:3'd0,animation[3],paint,avatar_rgb);
 always @*begin
   if(raw_strength<24)neon=0;
   else if(raw_strength<64)neon={8'd0,raw_strength,raw_strength[5:0],2'b00};
   else if(raw_strength<128)neon=24'h00FFFF;
   else if(raw_strength<192)neon={raw_strength,8'h20,8'hFF};
   else neon=24'hFF40E0;
   face_border=0;bx0=0;bx1=0;by0=0;by1=0;
   for(i=0;i<MAX_FACES;i=i+1)begin
     bx0=boxes[i*42+:11];bx1=boxes[i*42+11+:11];by0=boxes[i*42+22+:10];by1=boxes[i*42+32+:10];
     if(i<count&&x>=bx0&&x<=bx1&&y>=by0&&y<=by1&&(x-bx0<2||bx1-x<2||y-by0<2||by1-y<2))face_border=1;
   end
   case(mode)
   0:colour=rgb;
   1:colour={24{edge_pixel}};
   10:colour=raw_edge?24'hFF0000:rgb;
   9:colour=neon;
   14:colour=x==WIDTH/2?24'h00FFFF:(x<WIDTH/2?rgb:{24{edge_pixel}});
   15:begin
     colour=(GESTURE_DEBUG&&hand_skin)?{1'b0,rgb[23:17],1'b1,rgb[15:9],1'b1,rgb[7:1]}:rgb;
     if(hand_here&&hand_skin&&raw_edge)colour=24'hFF0000;
     if(hand_border)colour=gesture==0?24'hFFE040:24'h35D499;
     if(guide)colour=hand_valid?24'h35D499:24'hA4B6C8;
     if(paint)colour=avatar_rgb;
     if(preview_area)colour=preview_valid?(preview[{preview_y,preview_x}]?24'hFFFFFF:24'h08121E):24'h493522;
     if(crosshair)colour=24'hFF40E0;
     if(learn_state==2&&y>=HEIGHT-80&&y<HEIGHT-72&&x>=WIDTH/8&&x<WIDTH/8+learn_countdown*4)colour=24'h35D499;
   end
   5:colour=x==WIDTH/2?24'h00FFFF:(x<WIDTH/2?{3{gray_pixel}}:{24{compare_edge}});
   12:colour=shape_border?(shape_class==1?24'h00FF00:24'hFF00FF):(roi_border?24'h00FFFF:(compare_edge?24'hFFFFFF:rgb));
   8:begin
     if(x<WIDTH/8)colour=24'hFFFFFF;else if(x<WIDTH*2/8)colour=24'hFFFF00;
     else if(x<WIDTH*3/8)colour=24'h00FFFF;else if(x<WIDTH*4/8)colour=24'h00FF00;
     else if(x<WIDTH*5/8)colour=24'hFF00FF;else if(x<WIDTH*6/8)colour=24'hFF0000;
     else if(x<WIDTH*7/8)colour=24'h0000FF;else colour=0;
   end
   default:colour=rgb;
   endcase
   // Detection is an overlay only; neither edge magnitude nor Canny changes.
   if(detect&&!pure_en&&(mode==0||mode==1)&&face_border)colour=24'hFF7048;
 end
 reg[5:0]line_id;reg[5:0]ci;reg[3:0]fr,fc;reg text_on;reg[23:0]bg,fg;reg[10:0]tx;reg[9:0]ty;
 reg[2:0]health_index;
 always @*begin
   line_id=0;ci=0;fr=0;fc=0;text_on=0;bg=colour;fg=24'hFFFFFF;tx=0;ty=0;health_index=(x-16)>>6;
   if(HUD_ENABLE&&!pure_en)begin
     if(x>=16&&x<368&&y>=8&&y<40)begin
       case(mode)0:line_id=0;1:line_id=1;10:line_id=2;9:line_id=3;14:line_id=4;15:line_id=5;5:line_id=6;12:line_id=7;default:line_id=8;endcase
       tx=x-16;ty=y-8;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;bg=24'h101C2C;
     end else if(x>=16&&x<528&&y>=48&&y<64)begin
       line_id=15;tx=x-16;ty=y-48;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h101C2C;
     end else if(x>=16&&x<528&&y>=68&&y<76)begin
       if(((x-16)%64)<52)bg=health[health_index]?24'h35D499:24'hF06A70;
     end else if(detect&&(mode==0||mode==1)&&x>=400&&x<624&&y>=10&&y<26)begin
       line_id=16+(count>8?8:count);tx=x-400;ty=y-10;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h101C2C;
     end
     if(frozen&&x>=640&&x<704&&y>=10&&y<26)begin
       line_id=25;tx=x-640;ty=y-10;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h493522;
     end
     if(mode==15&&x>=1024&&x<1264&&y>=326&&y<358)begin
       line_id=learn_state!=0?40+learn_step:(trained!=7?40:10+((hand_valid&&gesture<=3)?gesture:0));tx=x-1024;ty=y-326;ci=tx>>5;fc=tx>>1;fr=ty>>1;text_on=1;bg=24'h122439;
     end else if(mode==15&&x>=880&&x<1264&&y>=374&&y<390)begin
       line_id=(hand_valid&&gesture>=1&&gesture<=3)?35+gesture:14;tx=x-880;ty=y-374;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
     end
   end
   if(HUD_ENABLE&&!pure_en&&mode==15&&gesture==0&&hand_valid&&debug_class==1&&x>=1024&&x<1264&&y>=410&&y<426)begin
     line_id=39;tx=x-1024;ty=y-410;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
   end
   if(HUD_ENABLE&&!pure_en&&mode==15&&x>=896&&x<1264&&y>=410&&y<426)begin
     if(learn_state==0)begin
      if(trained!=7)line_id=56;
      else if(gesture==2||gesture==3)line_id=51;
      else case(wave_phase)
       0:line_id=61;1:line_id=57;2:line_id=58;3:line_id=59;4:line_id=60;default:line_id=57;
      endcase
     end
     else if(learn_state==1)line_id=44;
     else if(learn_state==2)line_id=45;
     else if(learn_state==3)line_id=46;
     else if(learn_state==4||learn_state==5)line_id=47;
     else line_id=learn_error==1?48:(learn_error==2?49:50);
     tx=x-896;ty=y-410;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
   end
   if(HUD_ENABLE&&!pure_en&&mode==15&&x>=1024&&x<1264&&y>=450&&y<466)begin
     line_id=52;tx=x-1024;ty=y-450;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
   end
   if(HUD_ENABLE&&!pure_en&&mode==15&&y>=HEIGHT-56&&y<HEIGHT-40&&x>=WIDTH*3/16&&x<WIDTH*3/16+640)begin
     line_id=learn_step!=0?52+learn_step:34;tx=x-WIDTH*3/16;ty=y-(HEIGHT-56);ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
   end
   if(HUD_ENABLE&&!pure_en&&mode==15&&y>=HEIGHT-32&&y<HEIGHT-16&&x>=WIDTH*3/16&&x<WIDTH*3/16+640)begin
     line_id=35;tx=x-WIDTH*3/16;ty=y-(HEIGHT-32);ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
   end
   if(GESTURE_DEBUG&&HUD_ENABLE&&!pure_en&&mode==15)begin
     if(x>=880&&x<1264&&y>=410&&y<426)begin
       if(!hand_enable)line_id=26;
       else if(hand_overflow)line_id=29;
       else if(debug_clean==0)line_id=27;
       else if(!hand_valid)line_id=28;
       else if(gesture>=1&&gesture<=3)line_id=10+gesture;
       else if(debug_class==0)line_id=30;
       else line_id=31;
       tx=x-880;ty=y-410;ci=tx>>4;fc=tx[3:0];fr=ty[3:0];text_on=1;bg=24'h122439;
     end
     if(diag_area)begin text_on=0;bg=diag_ink?24'hFFFFFF:24'h122439;end
   end
   // Pure capture means ALL overlays absent, regardless of other controls.
   if(pure_en)begin bg=rgb;text_on=0;end
 end
 wire[15:0]bits;
 vision6_glyph_rom font(clk,line_id,ci,fr,bits);
 reg[3:0]cq;reg tq,dq,vq,hq;reg[23:0]bq,fq;
 always @(posedge clk)begin
   if(!rst_n)begin cq<=0;tq<=0;dq<=0;vq<=0;hq<=0;bq<=0;fq<=0;rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;end
   else begin
     cq<=fc;tq<=text_on;dq<=de;vq<=vs;hq<=hs;bq<=bg;fq<=fg;
     rgb_o<=dq?((tq&&bits[15-cq])?fq:bq):24'd0;de_o<=dq;vs_o<=vq;hs_o<=hq;
   end
 end
endmodule
