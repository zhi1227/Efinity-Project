`timescale 1ns/1ps
`include "rgb_balance_config.vh"
// ding, 2026-10-15. Independent byte-level scoreboards and integer references.
module tb_camera_rgb_balance;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,vs=0,de=0;
 reg [7:0] data=0;
 wire uv,ud,bv,bd,tv,td,sv,sd,cv,cd;
 wire [7:0] ub,bb,tb,sb,cb;
 localparam CONFIG_IDENTITY = !`RGB_BALANCE_ENABLE ||
  (`RGB_BALANCE_CENTER_R==256 && `RGB_BALANCE_CENTER_G==256 && `RGB_BALANCE_CENTER_B==256 &&
   `RGB_BALANCE_EDGE_R==256 && `RGB_BALANCE_EDGE_G==256 && `RGB_BALANCE_EDGE_B==256 &&
   (!`RGB_BALANCE_PROFILE_ENABLE || (`RGB_BALANCE_OUTER_R==256 && `RGB_BALANCE_OUTER_G==256 && `RGB_BALANCE_OUTER_B==256 &&
    `RGB_BALANCE_MID_R==256 && `RGB_BALANCE_MID_G==256 && `RGB_BALANCE_MID_B==256 &&
    `RGB_BALANCE_CORE_R==256 && `RGB_BALANCE_CORE_G==256 && `RGB_BALANCE_CORE_B==256)));
 camera_rgb_balance #(.PROFILE_ENABLE(0),.ENABLE(1),.CENTER_R(256),.CENTER_G(256),.CENTER_B(256),.EDGE_R(256),.EDGE_G(256),.EDGE_B(256)) unity(clk,rst_n,vs,de,data,uv,ud,ub);
 camera_rgb_balance #(.ENABLE(0)) disabled(clk,rst_n,vs,de,data,bv,bd,bb);
 // These explicit instances keep the original trial and saturation checks
 // independent of user edits to the header. The configured instance below
 // separately tests the current header/command-line definitions.
 camera_rgb_balance #(.PROFILE_ENABLE(0),.ENABLE(1),.CENTER_R(256),.CENTER_G(240),.CENTER_B(256),.EDGE_R(240),.EDGE_G(256),.EDGE_B(256)) trial(clk,rst_n,vs,de,data,tv,td,tb);
 camera_rgb_balance #(.PROFILE_ENABLE(0),.ENABLE(1),.CENTER_R(512),.CENTER_G(512),.CENTER_B(512),.EDGE_R(512),.EDGE_G(512),.EDGE_B(512)) saturate(clk,rst_n,vs,de,data,sv,sd,sb);
 camera_rgb_balance configured(clk,rst_n,vs,de,data,cv,cd,cb);
 reg [7:0] hist_data [0:5];
 reg hist_de [0:5],hist_vs [0:5];
 reg expected_de [0:7];
 reg [7:0] expected_trial [0:7],expected_sat [0:7],expected_config [0:7];
 integer cycle=0,checked_bytes=0,identity_bytes=0,configured_bytes=0,ref_x=0,ref_y=0;
 integer k,slot,due1,due2,wr,wg,wb,weight,delta,dx,dy,xx,yy;
 reg ref_phase=0,ref_de=0;
 reg [7:0] ref_first;
 reg [15:0] p,trial_pixel,sat_pixel,configured_pixel;
 function integer clip;
  input integer value,limit;
  begin clip=value>limit?limit:value;end
 endfunction
 function integer configured_gain;
  input integer centre_value,edge_value,centre_weight;
  integer magnitude,rounded;
  begin
   // Independent integer reference: interpolate the magnitude and then
   // apply its sign, rounding a half step away from zero in both directions.
   magnitude=(centre_value>=edge_value?centre_value-edge_value:edge_value-centre_value)*centre_weight;
   rounded=(magnitude+128)/256;
   configured_gain=centre_value>=edge_value?edge_value+rounded:edge_value-rounded;
  end
 endfunction
 function integer reference_profile;
  input integer c,e,o,m,k,w;
  integer a,b,n,d,v;
  begin
   if(!`RGB_BALANCE_PROFILE_ENABLE || w<=64) reference_profile=configured_gain(c,e,w);
   else begin
    if(w<=128) begin a=configured_gain(c,e,64);b=o;n=w-64;end
    else if(w<=192) begin a=o;b=m;n=w-128;end
    else begin a=m;b=k;n=w-192;end
    d=b-a;v=((d<0?-d:d)*n+32)/64;
    reference_profile=d<0?a-v:a+v;
   end
  end
 endfunction
 function integer reference_weight;
  input integer px,py;
  integer a,b;
  begin
   a=px<640?px:1279-px;b=py<360?py:719-py;
   a=(a*205+256)/512;b=(b*365+256)/512;
   reference_weight=(a*b+128)/256;
  end
 endfunction
 always @(posedge clk) begin
  #1;
  if(!rst_n) begin
   for(k=0;k<6;k=k+1)begin hist_data[k]=0;hist_de[k]=0;hist_vs[k]=0;end
   for(k=0;k<8;k=k+1)begin expected_de[k]=0;expected_trial[k]=0;expected_sat[k]=0;expected_config[k]=0;end
   cycle=0;ref_x=0;ref_y=0;ref_phase=0;ref_de=0;
   if(ud||bd||td||sd||cd||uv||bv||tv||sv||cv)$fatal(1,"Reset did not clear output");
  end else begin
   if({uv,ud,ub}!=={hist_vs[5],hist_de[5],hist_data[5]})$fatal(1,"Unity latency/identity cycle %0d",cycle);
   if({bv,bd,bb}!=={hist_vs[5],hist_de[5],hist_data[5]})$fatal(1,"Disabled latency/identity cycle %0d",cycle);
   if(tv!==hist_vs[5] || sv!==hist_vs[5] || cv!==hist_vs[5])$fatal(1,"VS latency mismatch cycle %0d",cycle);
   if(ud)identity_bytes=identity_bytes+1;
   slot=cycle%8;
   if(CONFIG_IDENTITY)begin
    if({cv,cd,cb}!=={hist_vs[5],hist_de[5],hist_data[5]})$fatal(1,"Configured identity mismatch cycle %0d",cycle);
   end else begin
    if(cd!==expected_de[slot])$fatal(1,"Configured DE mismatch cycle %0d",cycle);
    if(expected_de[slot] && cb!==expected_config[slot])$fatal(1,"Configured arithmetic mismatch cycle %0d got %h expected %h",cycle,cb,expected_config[slot]);
   end
   if(cd)configured_bytes=configured_bytes+1;
   if(td!==expected_de[slot] || sd!==expected_de[slot])$fatal(1,"Corrected DE/phase mismatch cycle %0d got %b expected %b",cycle,td,expected_de[slot]);
   if(expected_de[slot])begin
    if(tb!==expected_trial[slot])$fatal(1,"Trial mismatch cycle %0d got %h expected %h",cycle,tb,expected_trial[slot]);
    if(sb!==expected_sat[slot])$fatal(1,"Saturation mismatch cycle %0d got %h expected %h",cycle,sb,expected_sat[slot]);
    checked_bytes=checked_bytes+1;
   end
   expected_de[slot]=0;
   for(k=5;k>0;k=k-1)begin hist_data[k]=hist_data[k-1];hist_de[k]=hist_de[k-1];hist_vs[k]=hist_vs[k-1];end
   hist_data[0]=data;hist_de[0]=de;hist_vs[0]=vs;
   if(!vs)begin ref_x=0;ref_y=0;ref_phase=0;end
   else if(!de)begin ref_phase=0;ref_x=0;if(ref_de && ref_y<719)ref_y=ref_y+1;end
   else if(!ref_phase)begin ref_first=data;ref_phase=1;end
   else begin
    p={ref_first,data};ref_phase=0;
    weight=reference_weight(ref_x,ref_y);
    delta=(16*weight+128)/256;
    wr=240+delta;wg=256-delta;wb=256;
    trial_pixel={5'(clip((p[15:11]*wr+128)/256,31)),6'(clip((p[10:5]*wg+128)/256,63)),5'(p[4:0])};
    sat_pixel={5'(clip(p[15:11]*2,31)),6'(clip(p[10:5]*2,63)),5'(clip(p[4:0]*2,31))};
    wr=reference_profile(`RGB_BALANCE_CENTER_R,`RGB_BALANCE_EDGE_R,`RGB_BALANCE_OUTER_R,`RGB_BALANCE_MID_R,`RGB_BALANCE_CORE_R,weight);
    wg=reference_profile(`RGB_BALANCE_CENTER_G,`RGB_BALANCE_EDGE_G,`RGB_BALANCE_OUTER_G,`RGB_BALANCE_MID_G,`RGB_BALANCE_CORE_G,weight);
    wb=reference_profile(`RGB_BALANCE_CENTER_B,`RGB_BALANCE_EDGE_B,`RGB_BALANCE_OUTER_B,`RGB_BALANCE_MID_B,`RGB_BALANCE_CORE_B,weight);
    configured_pixel={5'(clip((p[15:11]*wr+128)/256,31)),6'(clip((p[10:5]*wg+128)/256,63)),5'(clip((p[4:0]*wb+128)/256,31))};
    due1=(cycle+5)%8;due2=(cycle+6)%8;
    if(expected_de[due1]||expected_de[due2])$fatal(1,"Reference schedule collision");
    expected_de[due1]=1;expected_de[due2]=1;
    expected_trial[due1]=trial_pixel[15:8];expected_trial[due2]=trial_pixel[7:0];
    expected_sat[due1]=sat_pixel[15:8];expected_sat[due2]=sat_pixel[7:0];
    expected_config[due1]=configured_pixel[15:8];expected_config[due2]=configured_pixel[7:0];
    if(ref_x<1279)ref_x=ref_x+1;
   end
   ref_de=de;cycle=cycle+1;
  end
 end
 task blank;
  input integer clocks;
  integer n;
  begin for(n=0;n<clocks;n=n+1)begin @(negedge clk);de=0;data=data+8'h37;end end
 endtask
 task pixel;
  input [15:0] value;
  begin @(negedge clk);de=1;data=value[15:8];@(negedge clk);de=1;data=value[7:0];end
 endtask
 task frame_end;
  begin @(negedge clk);vs=0;de=0;blank(20);end
 endtask
 integer i,j,before_bytes,before_identity;
 initial begin
  $display("CONFIG: ENABLE=%0d CENTER=%0d/%0d/%0d EDGE=%0d/%0d/%0d identity=%0d",`RGB_BALANCE_ENABLE,`RGB_BALANCE_CENTER_R,`RGB_BALANCE_CENTER_G,`RGB_BALANCE_CENTER_B,`RGB_BALANCE_EDGE_R,`RGB_BALANCE_EDGE_G,`RGB_BALANCE_EDGE_B,CONFIG_IDENTITY);
  $display("CONFIG: PROFILE=%0d OUTER=%0d/%0d/%0d MID=%0d/%0d/%0d CORE=%0d/%0d/%0d",`RGB_BALANCE_PROFILE_ENABLE,`RGB_BALANCE_OUTER_R,`RGB_BALANCE_OUTER_G,`RGB_BALANCE_OUTER_B,`RGB_BALANCE_MID_R,`RGB_BALANCE_MID_G,`RGB_BALANCE_MID_B,`RGB_BALANCE_CORE_R,`RGB_BALANCE_CORE_G,`RGB_BALANCE_CORE_B);
  for(xx=0;xx<1280;xx=xx+1)
   if(reference_weight(xx,359)!=reference_weight(1279-xx,359))$fatal(1,"Horizontal weight asymmetry");
  for(yy=0;yy<720;yy=yy+1)
   if(reference_weight(639,yy)!=reference_weight(639,719-yy))$fatal(1,"Vertical weight asymmetry");
  if(reference_weight(639,359)!=256 || reference_weight(640,360)!=256 ||
     reference_weight(0,359)!=0 || reference_weight(1279,359)!=0 || reference_weight(639,0)!=0 || reference_weight(639,719)!=0)
   $fatal(1,"Centre/edge weight endpoints");
  repeat(5)@(negedge clk);rst_n=1;blank(10);
  // Exhaustive channel values also prove byte order and black/blue behaviour.
  before_bytes=checked_bytes;before_identity=identity_bytes;
  @(negedge clk);vs=1;
  for(i=0;i<65536;i=i+1)begin pixel(i[15:0]);if((i%1280)==1279)blank(3);end
  frame_end;
  if(checked_bytes-before_bytes!=131072 || identity_bytes-before_identity!=131072)$fatal(1,"Exhaustive byte count");
  $display("PASS: 65536 RGB565 values, unity/disabled identity, six-cycle latency and default/saturating arithmetic");
  // Exercise actual centre rows/columns, all four edges and every full-frame byte.
  before_bytes=checked_bytes;before_identity=identity_bytes;
  @(negedge clk);vs=1;blank(4);
  for(j=0;j<720;j=j+1)begin
   for(i=0;i<1280;i=i+1)pixel(16'hffff);
   if(j!=719)blank(3);
  end
  frame_end;
  if(checked_bytes-before_bytes!=1843200 || identity_bytes-before_identity!=1843200)$fatal(1,"1280x720 frame byte count");
  $display("PASS: full 1280x720 frame, 1843200 bytes, centre/edge/corner gains and symmetry");
  // An odd trailing byte is not allowed to become half of the next line.
  before_bytes=checked_bytes;before_identity=identity_bytes;
  @(negedge clk);vs=1;blank(4);pixel(16'hf800);blank(1);
  @(negedge clk);de=1;data=8'hff;blank(2);
  pixel(16'h001f);blank(2);pixel(16'h07e0);
  @(negedge clk);de=1;data=8'haa;frame_end;
  if(checked_bytes-before_bytes!=6 || identity_bytes-before_identity!=8)$fatal(1,"Odd DE run handling");
  $display("PASS: DE interruptions, odd-byte rejection, high-byte-first recovery and frame-tail drain");
  @(negedge clk);vs=1;pixel(16'hffff);
  @(negedge clk);rst_n=0;vs=0;de=0;
  repeat(3)@(negedge clk);rst_n=1;blank(12);
  before_bytes=checked_bytes;
  @(negedge clk);vs=1;pixel(16'h0000);frame_end;
  if(checked_bytes-before_bytes!=2)$fatal(1,"Reset recovery/black preservation");
  $display("PASS: current configuration reference, positive/negative interpolation, native-channel clipping and identity routing; configured bytes=%0d",configured_bytes);
  $display("PASS: central three-region profile, protected old outer curve, continuous knot interpolation; complete frame scoreboard");
  $display("PASS: camera RGB balance; checked corrected bytes=%0d, identity bytes=%0d; board and optical calibration not tested",checked_bytes,identity_bytes);
  $finish;
 end
 initial begin #40000000;$fatal(1,"RGB balance timeout");end
endmodule
