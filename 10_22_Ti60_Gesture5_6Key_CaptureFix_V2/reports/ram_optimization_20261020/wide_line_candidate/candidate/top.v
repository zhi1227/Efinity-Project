module wide_line_top(input clk,rst_n,frame_start,de_i,input[10:0]x_i,input[9:0]y_i,input[7:0]data_i,
 output[71:0]window_o,output window_valid,output[10:0]x_o,output[9:0]y_o);
 line_buffer_3x3 #(.WIDTH(1280),.DWIDTH(8),.AWIDTH(11)) dut(clk,rst_n,frame_start,de_i,x_i,y_i,data_i,window_o,window_valid,x_o,y_o);
endmodule
