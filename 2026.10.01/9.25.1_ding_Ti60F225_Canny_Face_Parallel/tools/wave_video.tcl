open_vcd video_alignment.vcd
foreach signal {clk rst de vs hs rgb mode q od ov oh} {
  log_vcd [get_objects /tb_contest_video/$signal]
}
foreach signal {ax ay ade avs ahs ex ey cv ce aligned_sobel raw_preview mode_active} {
  log_vcd [get_objects /tb_contest_video/dut/$signal]
}
# Two complete display frames are sufficient for detailed alignment viewing.
run 270 us
close_vcd
run all
quit
