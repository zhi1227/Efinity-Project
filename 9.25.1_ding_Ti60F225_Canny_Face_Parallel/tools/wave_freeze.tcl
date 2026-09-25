open_vcd freeze.vcd
log_vcd [get_objects /tb_freeze/clk]
log_vcd [get_objects /tb_freeze/pixel_clk]
log_vcd [get_objects /tb_freeze/reset]
log_vcd [get_objects /tb_freeze/key_n]
log_vcd [get_objects /tb_freeze/pulse]
log_vcd [get_objects /tb_freeze/request]
log_vcd [get_objects /tb_freeze/wr]
log_vcd [get_objects /tb_freeze/rd]
log_vcd [get_objects /tb_freeze/ws]
log_vcd [get_objects /tb_freeze/rs]
log_vcd [get_objects /tb_freeze/frozen]
log_vcd [get_objects /tb_freeze/have_frame]
run all
close_vcd
quit
