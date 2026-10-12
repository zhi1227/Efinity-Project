`timescale 1ns/1ps
// Real RGB input exercises skin segmentation, morphology, ROI gating and CCL.
// Coordinates intentionally cover areas excluded by the previous ROI.
module tb_gesture_roi;
 reg clk=0,rst=0,de=0,vs=0,hs=0,vsq=1;always #5 clk=~clk;
 reg[23:0]rgb=0;wire[10:0]x;wire[9:0]y;wire bv,ov;wire[41:0]box;wire[3:0]fault;
 raster_xy #(.WIDTH(320)) xy(clk,rst,vs,de,x,y);
 always @(posedge clk)if(!rst)vsq<=1;else vsq<=vs;
 gesture_branch #(.WIDTH(320),.HEIGHT(240),.H_TOTAL(400)) dut(
 .clk(clk),.rst_n(rst),.enable(1'b1),.mode_on(1'b1),.rgb(rgb),.de(de),.vs(vs),.hs(hs),
 .fs(vs&&!vsq),.x(x),.y(y),.skin_lower(8'd10),.box_valid(bv),.box(box),
 .overflow(ov),.debug_fault(fault),.key_short(1'b0),.key_long(1'b0));
 integer v,h,xx,yy,scene=0;reg skin;
 task frame;begin
  for(v=0;v<270;v=v+1)for(h=0;h<400;h=h+1)begin
   @(negedge clk);vs=v>=3;hs=h>=4;de=v>=15&&v<255&&h>=40&&h<360;xx=h-40;yy=v-15;
   case(scene)
    0:skin=xx>=18&&xx<=62&&yy>=80&&yy<=170;
    1:skin=xx>=214&&xx<=245&&yy>=80&&yy<=170;
    2:skin=xx>=100&&xx<=170&&yy>=17&&yy<=65;
    3:skin=xx>=100&&xx<=170&&yy>=185&&yy<=224;
    4:skin=xx>=4&&xx<=40&&yy>=70&&yy<=150;
    default:skin=0;
   endcase
   rgb=de&&skin?24'hC88C6E:24'h204080;
  end
  if(ov||fault)$fatal(1,"ROI pipeline fault scene %0d: %h",scene,fault);
 end endtask
 initial begin
  for(scene=0;scene<6;scene=scene+1)begin
   rst=0;de=0;vs=0;repeat(5)@(negedge clk);rst=1;repeat(5)frame();
   if(scene<4)begin
    if(!dut.raw_valid||!bv)$fatal(1,"Expanded ROI rejected scene %0d",scene);
    case(scene)
     0:if(dut.raw_box[10:0]>=40)$fatal(1,"Left region still clipped");
     1:if(dut.raw_box[21:11]<=240)$fatal(1,"Right region still clipped");
     2:if(dut.raw_box[31:22]>=20)$fatal(1,"Top region still clipped");
     3:if(dut.raw_box[41:32]<=220)$fatal(1,"Bottom region still clipped");
    endcase
    $display("Expanded ROI scene %0d bbox (%0d,%0d)..(%0d,%0d)",scene,dut.raw_box[10:0],dut.raw_box[31:22],dut.raw_box[21:11],dut.raw_box[41:32]);
   end else if(dut.raw_valid||bv)$fatal(1,"Clipped/empty scene admitted: %0d",scene);
  end
  $display("PASS: expanded left/right/top/bottom regions detected through RGB pipeline; clipped and empty scenes rejected");$finish;
 end
endmodule
