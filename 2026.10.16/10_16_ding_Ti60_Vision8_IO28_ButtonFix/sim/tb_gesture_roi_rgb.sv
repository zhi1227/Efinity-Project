`timescale 1ns/1ps
// Exercise the real RGB -> skin -> morphology -> expanded ROI -> CCL pipeline.
// Smaller raster uses the same proportional ROI macros as the 1280x720 product.
module tb_gesture_roi_rgb;
 reg clk=0,rst=0,de=0,vs=0,hs=0,vsq=1;
 always #5 clk=~clk;
 reg [23:0]rgb=0;
 reg [31:0]source_id=1;
 wire [10:0]x;wire [9:0]y;wire bv,ov;wire [41:0]box;
 wire [3:0]fault,reject_flags;wire [2:0]gesture;
 raster_xy #(.WIDTH(320)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.SOURCE_TAGGED(1),.WIDTH(320),.HEIGHT(240),.H_TOTAL(400)) dut(
  .clk(clk),.rst_n(rst),.enable(1'b1),.mode_on(1'b1),.rgb(rgb),.de(de),.vs(vs),.hs(hs),
  .fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),.box_valid(bv),.box(box),.gesture(gesture),
  .overflow(ov),.debug_fault(fault),.debug_reject(reject_flags),
  .key_short(1'b0),.key_long(1'b0),.source_id_i(source_id));
 integer v,h,xx,yy,scene=0,frames=0;
 integer fresh_events=0,replayed_events=0;
 reg skin;reg seen_before;reg [31:0]id_before;
 always @(posedge clk)begin
  if(rst&&dut.done)begin
   seen_before=dut.id_seen;id_before=dut.previous_id;
   #1;
   if(seen_before&&dut.previous_id==id_before)begin
    if(dut.fresh_result!==1'b0)$fatal(1,"replayed camera ID accepted: %0d",id_before);
    replayed_events=replayed_events+1;
   end else begin
    if(dut.fresh_result!==1'b1)$fatal(1,"distinct camera ID rejected");
    fresh_events=fresh_events+1;
   end
  end
 end
 task frame(input bit repeated_id);begin
  if(!repeated_id)source_id=source_id+1;
  for(v=0;v<270;v=v+1)for(h=0;h<400;h=h+1)begin
   @(negedge clk);vs=v>=3;hs=h>=4;de=v>=15&&v<255&&h>=40&&h<360;xx=h-40;yy=v-15;
   case(scene)
    0:skin=xx>=18&&xx<=62&&yy>=80&&yy<=170;   // newly admitted left
    1:skin=xx>=214&&xx<=245&&yy>=80&&yy<=170; // newly admitted right
    2:skin=xx>=100&&xx<=170&&yy>=17&&yy<=65; // newly admitted top
    3:skin=xx>=100&&xx<=170&&yy>=185&&yy<=224; // newly admitted bottom
    4:skin=xx>=4&&xx<=40&&yy>=70&&yy<=150;   // left clipped at ROI
    5:skin=xx>=235&&xx<=278&&yy>=70&&yy<=150;// right clipped at ROI
    6:skin=xx>=100&&xx<=170&&yy>=4&&yy<=65;  // top clipped at ROI
    7:skin=xx>=100&&xx<=150&&yy>=185&&yy<=238;// wrist beyond ROI bottom allowed
    default:skin=0;
   endcase
   rgb=de&&skin?24'hC88C6E:24'h204080;
  end
  if(ov||fault)$fatal(1,"ROI pipeline fault scene %0d: %h",scene,fault);
  frames=frames+1;
 end endtask
 task reset_scene;begin
  @(negedge clk);rst=0;de=0;vs=0;rgb=0;
  repeat(8)@(negedge clk);rst=1;
 end endtask
 initial begin
  for(scene=0;scene<9;scene=scene+1)begin
   reset_scene();repeat(7)frame(0);
   if(scene<4||scene==7)begin
    if(!dut.raw_valid||!bv)$fatal(1,"Expanded ROI/wrist rejected scene %0d",scene);
    case(scene)
     0:if(dut.raw_box[10:0]>=40)$fatal(1,"Left region still clipped");
     1:if(dut.raw_box[21:11]<=240)$fatal(1,"Right region still clipped");
     2:if(dut.raw_box[31:22]>=20)$fatal(1,"Top region still clipped");
     3:if(dut.raw_box[41:32]<=220)$fatal(1,"Bottom region still clipped");
     7:if(dut.raw_box[41:32]!=226)$fatal(1,"Bottom wrist did not reach the new ROI boundary");
    endcase
    $display("Accepted RGB scene %0d bbox (%0d,%0d)..(%0d,%0d)",scene,dut.raw_box[10:0],dut.raw_box[31:22],dut.raw_box[21:11],dut.raw_box[41:32]);
   end else begin
    if(dut.raw_valid||bv)$fatal(1,"Clipped/empty scene admitted: %0d",scene);
    if(scene<7&&!reject_flags[0])$fatal(1,"Clipped side lacked CCL border rejection: %0d",scene);
    $display("Rejected RGB scene %0d CCL flags %h",scene,reject_flags);
   end
  end
  scene=0;reset_scene();repeat(7)frame(0);repeat(4)frame(1);
  if(fresh_events<10||replayed_events<3)$fatal(1,"source ID coverage incomplete: distinct=%0d duplicate=%0d",fresh_events,replayed_events);
  $display("PASS: real RGB expanded four sides; CCL left/right/top clipping rejected; bottom wrist accepted; empty rejected; SOURCE_TAGGED distinct=%0d duplicate=%0d across %0d frames",fresh_events,replayed_events,frames);
  $finish;
 end
 initial begin #120000000;$fatal(1,"ROI RGB simulation timeout");end
endmodule
