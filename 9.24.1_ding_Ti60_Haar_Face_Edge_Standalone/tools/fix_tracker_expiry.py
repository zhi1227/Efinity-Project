from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'src/haar/haar_box_tracker.v';s=f.read_text();s=s.replace('reg best_found,free_found;reg [12:0] best_score;','reg best_found,free_found;reg [12:0] best_score;reg [41:0] best_box;')
s=s.replace('best_score<=0;','best_score<=0;best_box<=0;')
s=s.replace('best_found<=1;best_index<=scan_index;best_score<=distance;','best_found<=1;best_index<=scan_index;best_score<=distance;best_box<=current;')
s=s.replace('smooth(display_boxes[best_index*42+:42],candidate)','smooth(best_box,candidate)')
f.write_text(s)
f=P/'tb/tb_haar_tracker.v';s=f.read_text();old='  $display("PASS timeout, capacity guard, reacquisition and frame-atomic publication");'
new='''  // The old box may expire after it was matched but before APPLY executes.
  // The matcher must preserve those coordinates, not average against cleared RAM.
  repeat(35)frame;
  @(negedge clk);rv=1;count=1;boxes=b;
  @(negedge clk);rv=0;
  wait(dut.state==2);frame;
  repeat(4)@(negedge clk);frame;
  if(dc!=1||db[0+:42]!=b[0+:42])$fatal(1,"FAIL association spanning expiry boundary");
  $display("PASS timeout, capacity guard, reacquisition, expiry race and frame-atomic publication");'''
assert old in s;s=s.replace(old,new);f.write_text(s)
print('Preserved matched coordinates across timeout boundary; added race regression.')
