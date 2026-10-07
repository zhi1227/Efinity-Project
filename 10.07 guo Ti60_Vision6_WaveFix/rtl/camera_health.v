// Activity diagnostics. Each event crosses a domain as a toggle, never a pulse.
module camera_health #(parameter SYS_HZ=96000000,FRAME_BYTES=1843200,RGB_TIMEOUT=37000000,RGB_MAX=50000000)(
 input sys_clk,sys_rst_n,cam_clk,cam_vs,cam_de,input[7:0]cam_data,
 input cfg_done,cfg_ack,cal_done,cal_pass,buffer_ready,
 input pixel_clk,pixel_rst_n,pixel_de,input[23:0]pixel_rgb,
 output reg retry_config,output reg[7:0]health);
 reg[9:0]pcnt;reg vsq,vtoggle;reg[21:0]byte_count;reg complete_toggle;
 always @(posedge cam_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin pcnt<=0;vsq<=0;vtoggle<=0;byte_count<=0;complete_toggle<=0;end
 else begin
   pcnt<=pcnt+1'b1;vsq<=cam_vs;
   if(vsq&&!cam_vs)begin
     vtoggle<=~vtoggle;
     if(byte_count==FRAME_BYTES)complete_toggle<=~complete_toggle;
     byte_count<=0;
   end else if(cam_de&&byte_count<FRAME_BYTES+4096)byte_count<=byte_count+1'b1;
 end
 (* async_reg="true" *)reg[2:0]cam_meta,cam_sync;
 reg[2:0]last;reg[26:0]p_age,v_age,f_age;reg[27:0]retry_age;
 reg[7:0]status_sys;
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin cam_meta<=0;cam_sync<=0;last<=0;p_age<=SYS_HZ;v_age<=SYS_HZ;f_age<=SYS_HZ;retry_age<=0;retry_config<=0;status_sys<=0;end
 else begin
   cam_meta<={complete_toggle,vtoggle,pcnt[9]};cam_sync<=cam_meta;last<=cam_sync;
   if(cam_sync[0]!=last[0])p_age<=0;else if(p_age<SYS_HZ)p_age<=p_age+1'b1;
   if(cam_sync[1]!=last[1])v_age<=0;else if(v_age<SYS_HZ)v_age<=v_age+1'b1;
   if(cam_sync[2]!=last[2])f_age<=0;else if(f_age<SYS_HZ)f_age<=f_age+1'b1;
   retry_config<=0;
   // Retry the entire register sequence only when no camera frames arrive.
   // Allow a full second for initial power settling and a further two seconds.
   if(!cfg_done||v_age<SYS_HZ/2)retry_age<=0;
   else if(retry_age==SYS_HZ*2-1)begin retry_config<=1;retry_age<=0;end
   else retry_age<=retry_age+1'b1;
   status_sys<={1'b0,buffer_ready&&f_age<SYS_HZ/2,cal_pass,cal_done,v_age<SYS_HZ/2,p_age<SYS_HZ/2,cfg_ack,cfg_done};
 end
 (* async_reg="true" *)reg[6:0]meta,sync;
 reg[25:0]rgb_age;
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin meta<=0;sync<=0;health<=0;rgb_age<=RGB_MAX;end
 else begin
   meta<=status_sys[6:0];sync<=meta;
   if(pixel_de&&pixel_rgb!=0)rgb_age<=0;else if(rgb_age<RGB_MAX)rgb_age<=rgb_age+1'b1;
   health<={rgb_age<RGB_TIMEOUT,sync};
 end
endmodule
