`timescale 1ns/1ps
module tb_vision8_faces;
 reg clk=0,rst=0,fs=0,sv=0,skin=0;always #5 clk=~clk;
 reg[10:0]x=0;reg[9:0]y=0;reg[31:0]id=77;wire[3:0]count;wire[335:0]boxes;wire busy,overrun,published,saturated;wire[31:0]result_id;
 face_grid_regions #(.WIDTH(64),.HEIGHT(64),.CELL_SHIFT(3),.CELL_MIN(1),.MIN_W(1),.MIN_H(1),.MAX_W(64),.MAX_H(64),.MIN_AREA(1),.MIN_FILL_PERCENT(1))regions(
 .clk(clk),.rst_n(rst),.frame_start(fs),.skin_valid(sv),.skin(skin),.x(x),.y(y),.face_count(count),.boxes(boxes),.busy(busy),.overrun(overrun),.source_id_i(id),.published(published),.result_id(result_id),.saturated(saturated));
 reg pub=0,ok=1,held=0,sat=0;reg[3:0]value=2;reg[31:0]tag=1;wire[3:0]stable;wire valid,stable_sat;
 vision8_count_filter filter(clk,rst,ok,held,pub,tag,value,sat,stable,valid,stable_sat);
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task observe(input integer source,input integer n,input bit plus);begin tag=source;value=n;sat=plus;pub=1;cycles(1);pub=0;cycles(1);end endtask
 task mask_frame(input bit empty);integer xx,yy;
 begin
  fs=1;cycles(1);fs=0;
  for(yy=0;yy<64;yy=yy+1)for(xx=0;xx<64;xx=xx+1)begin x=xx;y=yy;sv=1;skin=!empty&&(xx/8<=4)&&(yy/8<=4)&&!(xx/8%2)&&!(yy/8%2);cycles(1);end
  sv=0;skin=0;wait(!busy);cycles(5);fs=1;cycles(1);fs=0;cycles(1);
 end endtask
 initial begin
  cycles(6);rst=1;cycles(5);mask_frame(0);
  if(count!==8||!saturated||result_id!==77)$fatal(1,"ninth face candidate must display 8+ with correct camera ID");
  id=78;mask_frame(1);if(count!==0||saturated||result_id!==78)$fatal(1,"empty valid frame");
  observe(1,2,0);repeat(12)observe(1,2,0);if(valid)$fatal(1,"duplicate replay confirmed count");
  observe(2,2,0);if(valid)$fatal(1,"only two sources");observe(3,2,0);if(!valid||stable!=2)$fatal(1,"three-source confirmation");
  held=1;observe(4,0,0);observe(5,0,0);observe(6,0,0);if(!valid||stable!=2)$fatal(1,"freeze changed count");held=0;
  ok=0;cycles(1);if(valid)$fatal(1,"camera loss displayed a valid zero");ok=1;
  observe(7,0,0);observe(8,0,0);observe(9,0,0);if(!valid||stable!=0)$fatal(1,"valid zero recovery");
  observe(10,8,1);observe(11,8,1);observe(12,8,1);if(!valid||stable!=8||!stable_sat)$fatal(1,"saturated count confirmation");
  $display("PASS: real CCL nine separated regions/8+ and empty source frames; count confirmation rejects duplicate replay, preserves freeze and marks camera loss unknown");$finish;
 end
 initial begin #2000000;$fatal(1,"face timeout");end
endmodule
