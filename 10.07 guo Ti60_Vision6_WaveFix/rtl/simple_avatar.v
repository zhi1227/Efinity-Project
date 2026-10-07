// Procedural character, no bitmap/model RAM. Unknown gesture leaves idle pose.
module simple_avatar(input[10:0]x,input[9:0]y,input[2:0]gesture,input phase,
 output reg paint,output reg[23:0]colour);
 wire[10:0]xx=x-1040;wire[9:0]yy=y-80;
 wire panel=x>=1024&&x<1264&&y>=64&&y<312;
 wire head=xx>=54&&xx<174&&yy>=26&&yy<134;
 wire body=xx>=64&&xx<164&&yy>=144&&yy<210;
 wire eyes=(xx>=80&&xx<94||xx>=136&&xx<150)&&yy>=66&&yy<82;
 wire mouth=(gesture==2)?(xx>=100&&xx<130&&yy>=104&&yy<116):
 ((xx>=94&&xx<138&&yy>=108&&yy<114)||((xx>=88&&xx<94||xx>=138&&xx<144)&&yy>=100&&yy<110));
 wire left_arm=xx>=28&&xx<60&&yy>=156&&yy<172;
 wire right_arm=(gesture==1||gesture==5)?(xx>=180&&xx<194&&yy>=60&&yy<168):
 (gesture==2)?(xx>=168&&xx<206&&yy>=142&&yy<168):
 (gesture==3||gesture==4)?(xx>=180&&xx<192&&yy>=100&&yy<172):(xx>=170&&xx<198&&yy>=166&&yy<182);
 wire palm=(gesture==1||gesture==5)&&xx>=170&&xx<208&&yy>=34&&yy<68;
 wire finger=gesture==3&&xx>=182&&xx<190&&yy>=76&&yy<110;
 wire v_fingers=gesture==4&&yy>=68&&yy<110&&
  ((xx>=170&&xx<179)||(xx>=192&&xx<201));
 wire wave_marks=gesture==5&&phase&&yy>=32&&yy<88&&((xx>=212&&xx<216)||(xx>=224&&xx<228));
 always @*begin
 paint=panel;colour=24'h122439;
 if(panel)begin
   if(head||body)colour=gesture==0?24'h7696B0:24'h56D8DD;
   if(left_arm||right_arm||palm||finger||v_fingers||wave_marks)colour=24'h56D8DD;
   if(eyes||mouth)colour=24'h112138;
   if(body&&xx>=94&&xx<134&&yy>=162&&yy<190)colour=gesture==2?24'hFF8090:24'hF7D979;
 end
 end
endmodule
