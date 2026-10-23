from pathlib import Path
import json
P=Path(__file__).resolve().parents[1]
p=P/'rtl/menu8_renderer.v';s=p.read_text();s=s.replace(' wire[2:0]mode=', ' `include "vision8_modes.vh"\n wire[2:0]mode=');s=s.replace('wire[9:0]flow_target={7\'d0,mode}*10\'d116;',"wire[9:0]flow_target={7'd0,mode_to_slot(mode)}*10'd116;")
s=s.replace('reg [2:0] tile;','reg [2:0] slot;wire[2:0]tile=slot_to_mode(slot);')
for n in range(8):s=s.replace(f'tile={n};',f'slot={n};')
s=s.replace(' wire[1:0]step=state_i[64:63];','wire canny_mode=mode==1||mode==4;\n wire[1:0]selection=state_i[62:61];\n wire[11:0]high_threshold=state_i[60:49];\n wire[1:0]step=state_i[64:63];')
a=s.index('    if(meta[97:96]!=0&&y>=466');b=s.index('\n   end\n   // A single',a)
s=s[:a]+'''    if(meta[97:96]!=0&&y>=466&&y<482&&mx<112)begin
     tx=mx;ty=y-466;fr=ty;fc=tx;text_on=1;
     if(mx<48)begin line_id=meta[97:96]==1?36:35;ci=tx>>4;end
     else begin line_id=63;tx=mx-48;number=meta[97:96]==1?meta[83:72]:meta[95:84];ci=decimal(number,tx>>4);fc=tx;end
    end
    if(y>=494&&y<510&&mx<128)begin
     fr=y-494;fc=mx;text_on=1;fg=24'ha3b5cd;
     if(meta[97:96]==1)begin
      if(mx<64)begin line_id=37;ci=mx>>4;end
      else begin line_id=63;tx=mx-64;number=meta[95:84];ci=decimal(number,tx>>4);fc=tx;end
     end else begin line_id=63;ci=meta[24+(7-(mx>>4))*4+:4];end
    end''' +s[b:]
a=s.index('    if(x>=64&&x<256&&y>=440');b=s.index('\n   end\n   if(x>=56&&x<376',a)
s=s[:a]+'''    if(canny_mode)begin
     if(x>=64&&x<160&&y>=440&&y<472)begin line_id=36;tx=x-64;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==1?24'h7f96b6:24'h65dbab;end
     if(x>=176&&x<304&&y>=440&&y<472)begin line_id=63;tx=x-176;ty=y-440;ci=decimal(threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==1?24'h7f96b6:24'hecf4ff;end
     if(x>=400&&x<528&&y>=440&&y<472)begin line_id=37;tx=x-400;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==2?24'h7f96b6:24'h65dbab;end
     if(x>=544&&x<672&&y>=440&&y<472)begin line_id=63;tx=x-544;ty=y-440;ci=decimal(high_threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;fg=selection==2?24'h7f96b6:24'hecf4ff;end
     if(x>=720&&x<960&&y>=448&&y<464)begin line_id=selection==0?55+step:58+step;tx=x-720;ty=y-448;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'h65dbab;end
    end else begin
     if(x>=64&&x<256&&y>=440&&y<472)begin line_id=32;tx=x-64;ty=y-440;ci=tx>>5;fr=ty>>1;fc=tx>>1;text_on=1;fg=24'h82b5ff;end
     if(x>=272&&x<400&&y>=440&&y<472)begin line_id=63;tx=x-272;ty=y-440;ci=decimal(threshold,tx>>5);fr=ty>>1;fc=tx>>1;text_on=1;end
     if(x>=448&&x<512&&y>=448&&y<464)begin line_id=38;tx=x-448;ty=y-448;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hafc3dc;end
     if(x>=544&&x<576&&y>=440&&y<472)begin line_id=63;ci=step==0?1:step==1?4:8;fr=(y-440)>>1;fc=(x-544)>>1;text_on=1;fg=24'h65dbab;end
    end
    if(x>=64&&x<592&&y>=482&&y<498)begin line_id=33;tx=x-64;ty=y-482;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end
    if(canny_mode&&x>=608&&x<960&&y>=482&&y<498)begin line_id=52+selection;tx=x-608;ty=y-482;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'h65dbab;end
    if(x>=64&&x<960&&y>=510&&y<526)begin line_id=canny_mode?61:34;tx=x-64;ty=y-510;ci=tx>>4;fr=ty;fc=tx;text_on=1;fg=24'hb8c9de;end''' +s[b:]
s=s.replace("mode==7?(state_i[13]?44:31)","mode==7?(state_i[13]?44:state_i[122]?62:31)")
p.write_text(s)
p=P/'tools/generate_font.py';s=p.read_text(encoding='utf-8');s=s.replace("'06 手势识别','07 人脸识别','08 四帧对比'","'07 手势识别','08 人脸识别','06 四帧对比'");s=s.replace('长按 IO28 开关彩色画中画','短按 K1 开关彩色画中画').replace('07 人脸数量','08 人脸数量').replace('切换至模式7显示','切换至模式8显示');s=s.replace("'T =','','','STEP',''","'T =','LOW','HIGH','STEP',''");s=s.replace("lcd[52:63]=['']*11","lcd[52:63]=['联合调节','仅 HIGH','仅 LOW','L:1 H:2','L:4 H:8','L:8 H:16','STEP 1','STEP 4','STEP 8','K2 选阈值；长按 IO34 步长 / IO35 复位','抓拍失败，请重试']")
p.write_text(s,encoding='utf-8')
p=P/'tools/hdmi_text.json';s=p.read_text(encoding='utf-8').replace('06 手势互动','07 手势互动');p.write_text(s,encoding='utf-8')
# Preserve historical evidence and use a new build report namespace.
p=P/'tools/capture_fix_build.py';s=(P/'tools/inline_threshold_build.py').read_text();s=s.replace("R = P / 'reports/inline_threshold'","R = P / 'reports/capture_fix'").replace("'inline_threshold_build.py'","'capture_fix_build.py'");p.write_text(s)
print('mode mapping, dual-threshold menu and build namespace updated')
