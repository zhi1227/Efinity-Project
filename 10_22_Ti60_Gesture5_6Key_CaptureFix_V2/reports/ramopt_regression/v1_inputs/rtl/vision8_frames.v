// Pixel-domain capture directory, pre-HUD downsampling and final-raster compositor.
// Five DDR slots permit replacing a full four-tile directory atomically.
module vision8_frames #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,input[2:0]mode_i,input[1:0]algorithm_i,
 input pip_i,capture_i,clear_i,freeze_active,input[31:0]source_id,
 input[11:0]low_i,high_i,input[15:0]version_i,input source_ok,processing_ok,
 input[3:0]face_count,input face_valid,face_saturated,
 input[23:0]rgb_i,input de_i,vs_i,hs_i,
 input[15:0]result_i,input result_de,result_vs,input[10:0]result_x,input[9:0]result_y,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,
 output busy,lock_source,main_enable,output[2:0]mode_committed,output[11:0]capture_low,capture_high,output[3:0]capture_backend,
 output reg snap_begin,snap_end,output reg[2:0]snap_slot,output reg snap_bad,snap_reset,
 output reg snap_wr,output reg[31:0]snap_data,input snap_full,
 input snap_done,snap_ok,
 output reg aux_request,output reg[1:0]aux_kind,output reg[15:0]aux_directory,
 input aux_ack,input[31:0]aux_data,input aux_empty,input aux_frame_ready,
 output aux_rd,output reg[3:0]valid_tiles,
 output reg[511:0]metadata,output reg[31:0]underflows,capture_errors);
 localparam HALF_W=WIDTH/2,HALF_H=HEIGHT/2,PIXELS=HALF_W*HALF_H;
 reg[2:0]state,mode_active;reg[1:0]warm,next_tile;reg[2:0]temporary;
 reg vsq,rvsq,pair_phase;reg[15:0]first_pixel;
 reg[18:0]samples;reg cancelled;reg[6:0]reset_count;
 reg[1:0]bound_alg;reg[11:0]bound_low,bound_high;reg[15:0]bound_version;reg[31:0]bound_id;
 reg[11:0]directory,pending_directory;reg[3:0]pending_valid;reg publish;
 reg[2:0]old_slot;reg[511:0]pending_metadata;
 reg done_meta,done_sync,done_seen,ok_meta,ok_sync;
 reg ack_meta,ack_sync,ready_meta,ready_sync;
 reg[10:0]x;reg[9:0]y;reg pixel_half,invalid_frame,pip_active;
 wire frame_blank=vs_i&&!vsq,process_start=result_vs&&!rvsq;
 wire[1:0]tile={y>=HALF_H,x>=HALF_W};
 wire pip_area=x>=WIDTH-WIDTH/4-16&&x<WIDTH-16&&y>=16&&y<16+HEIGHT/4;
 wire compare_pixel=mode_active==7&&valid_tiles[tile];
 wire use_aux=de_i&&(compare_pixel||(pip_active&&pip_area));
 wire read_pixel=use_aux&&!invalid_frame&&ready_sync&&!aux_empty;
 assign aux_rd=read_pixel&&pixel_half;
 wire[15:0]aux_pixel=pixel_half?aux_data[31:16]:aux_data[15:0];
 wire[23:0]expanded={aux_pixel[15:11],aux_pixel[15:13],aux_pixel[10:5],aux_pixel[10:9],aux_pixel[4:0],aux_pixel[4:2]};
 wire[10:0]local_x=x>=HALF_W?x-HALF_W:x;
 wire[9:0]local_y=y>=HALF_H?y-HALF_H:y;
 wire[127:0]tile_meta=metadata[tile*128+:128];
 reg[383:0]label;reg[7:0]label_char;reg[10:0]label_x;reg[9:0]label_y;
 reg label_area;integer c;reg[11:0]label_low,label_high;
 function[7:0]hexchar;input[3:0]n;begin hexchar=n<10?8'h30+n:8'h41+n-10;end endfunction
 function[7:0]digit;input[11:0]v;input[1:0]pos;
 begin case(pos)0:digit=48+v/1000;1:digit=48+(v/100)%10;2:digit=48+(v/10)%10;default:digit=48+v%10;endcase end endfunction
 always @*begin
  label=0;label_char=32;label_x=0;label_y=0;label_area=0;c=0;label_low=low_i;label_high=high_i;
  if(mode_active==7)begin
   label_x=local_x-8;label_y=local_y-8;label_area=local_x>=8&&local_x<584&&local_y>=8&&local_y<24;
   if(valid_tiles[tile])begin
    case(tile_meta[97:96])0:label={"RAW   L:0000 H:0000 F:00000000 V:0000",88'd0};1:label={"CANNY L:0000 H:0000 F:00000000 V:0000",88'd0};
     2:label={"RED   L:0040 H:0040 F:00000000 V:0000",88'd0};default:label={"CYBER L:0040 H:0040 F:00000000 V:0000",88'd0};endcase
    label_low=tile_meta[83:72];label_high=tile_meta[95:84];
   end else label={"EMPTY - IO29 CAPTURE",232'd0};
  end else if(mode_active>=5)begin
   label_x=x-16;label_y=y-8;label_area=x>=16&&x<592&&y>=8&&y<40;
   case(mode_active)
    6:label={"07 FACE CANDIDATES: - ",216'd0};
    5:label={"06 GESTURE - BOARD K1 ENROL",176'd0};
   endcase
  end
  c=label_x/12;
  if(c<48)label_char=label[383-c*8-:8];
  if(mode_active==7&&valid_tiles[tile])begin
   if(c>=8&&c<12&&tile_meta[97:96]<2)label_char=digit(label_low,c-8);
   if(c>=15&&c<19&&tile_meta[97:96]<2)label_char=digit(label_high,c-15);
   if(c>=22&&c<30)label_char=hexchar(tile_meta[24+(29-c)*4+:4]);
   if(c>=33&&c<37)label_char=hexchar(tile_meta[56+(36-c)*4+:4]);
  end
  if(mode_active==6&&c==19)label_char=face_valid?hexchar(face_count):"-";
  if(mode_active==6&&c==20)label_char=face_saturated?"+":" ";
 end
 wire label_ink;
 vision8_ascii text(label_char,mode_active==7?label_y[3:1]:label_y[4:2],(label_x%12)>>1,label_ink);
 assign mode_committed=mode_active;
 assign busy=state!=0||publish;
 assign lock_source=state!=0;
 assign main_enable=mode_i!=7||state!=0;
 assign capture_low=bound_low;assign capture_high=bound_high;
 assign capture_backend=bound_alg==0?4'd0:bound_alg==1?4'd1:bound_alg==2?4'd10:4'd9;
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=0;mode_active<=0;warm<=0;next_tile<=0;temporary<=4;vsq<=1;rvsq<=1;pair_phase<=0;first_pixel<=0;samples<=0;cancelled<=0;reset_count<=0;
   bound_alg<=0;bound_low<=40;bound_high<=80;bound_version<=0;bound_id<=0;directory<=12'h688;pending_directory<=12'h688;pending_valid<=0;publish<=0;old_slot<=0;pending_metadata<=0;
   snap_begin<=0;snap_end<=0;snap_slot<=4;snap_bad<=0;snap_reset<=1;snap_wr<=0;snap_data<=0;aux_request<=0;aux_kind<=0;aux_directory<=0;
   valid_tiles<=0;metadata<=0;underflows<=0;capture_errors<=0;done_meta<=0;done_sync<=0;done_seen<=0;ok_meta<=0;ok_sync<=0;
   ack_meta<=0;ack_sync<=0;ready_meta<=0;ready_sync<=0;x<=0;y<=0;pixel_half<=0;invalid_frame<=0;pip_active<=0;rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;
  end else begin
   vsq<=vs_i;rvsq<=result_vs;snap_wr<=0;
   done_meta<=snap_done;done_sync<=done_meta;ok_meta<=snap_ok;ok_sync<=ok_meta;
   ack_meta<=aux_ack;ack_sync<=ack_meta;ready_meta<=aux_frame_ready;ready_sync<=ready_meta;
   if(!vs_i)begin x<=0;y<=0;end else if(de_i)begin if(x==WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;end
   de_o<=de_i;vs_o<=vs_i;hs_o<=hs_i;rgb_o<=de_i?rgb_i:24'd0;
   if(mode_active==7&&de_i)rgb_o<=24'h142235;
   if(read_pixel)begin rgb_o<=expanded;pixel_half<=~pixel_half;end
   else if(use_aux&&!invalid_frame&&(!ready_sync||aux_empty))begin invalid_frame<=1;underflows<=underflows+1'b1;end
   if(pip_active&&de_i&&x>=WIDTH-WIDTH/4-18&&x<WIDTH-14&&y>=14&&y<18+HEIGHT/4&&
    (x<WIDTH-WIDTH/4-16||x>=WIDTH-16||y<16||y>=16+HEIGHT/4))rgb_o<=24'h35d499;
   if(mode_active==7&&de_i&&(x==HALF_W||y==HALF_H))rgb_o<=24'h35d499;
   if(label_area&&de_i)rgb_o<=label_ink?24'he7f3ff:24'h132336;
   if(frame_blank)begin
    mode_active<=mode_i;pip_active<=pip_i&&mode_i>=1&&mode_i<=3;pixel_half<=0;invalid_frame<=0;
    if(publish)begin directory<=pending_directory;valid_tiles<=pending_valid;metadata<=pending_metadata;publish<=0;end
    if(clear_i)begin valid_tiles<=0;pending_valid<=0;next_tile<=0;publish<=0;metadata<=0;end
    if(ack_sync==aux_request)begin
     aux_kind<=mode_i==7?2'd2:(pip_i&&mode_i>=1&&mode_i<=3?2'd1:2'd0);
     aux_directory<=publish?{pending_valid,pending_directory}:{valid_tiles,directory};
     aux_request<=~aux_request;
    end else invalid_frame<=1;
   end
   if(clear_i)begin cancelled<=1;valid_tiles<=0;pending_valid<=0;publish<=0;next_tile<=0;metadata<=0;end
   if(state!=0&&mode_i!=7)cancelled<=1;
   case(state)
    0:begin snap_reset<=1;if(capture_i&&mode_i==7&&source_ok&&ack_sync==aux_request)begin state<=1;warm<=0;cancelled<=0;bound_alg<=algorithm_i;bound_low<=low_i;bound_high<=high_i;bound_version<=version_i;end end
    1:if(process_start&&freeze_active)begin warm<=0;bound_id<=source_id;state<=2;end
    2:if(process_start)begin
     if(source_id!=bound_id)begin bound_id<=source_id;warm<=0;end
     else if(warm==1)begin state<=3;reset_count<=0;snap_slot<=temporary;end else warm<=warm+1'b1;
    end
    3:begin
     snap_reset<=0;
     if(reset_count==63)begin snap_begin<=~snap_begin;state<=4;end else reset_count<=reset_count+1'b1;
    end
    4:if(process_start)begin state<=5;samples<=0;pair_phase<=0;snap_bad<=cancelled||!source_ok||!processing_ok;end
    5:begin
     if(result_de&&!result_x[0]&&!result_y[0])begin
      samples<=samples+1'b1;
      if(!pair_phase)begin first_pixel<=result_i;pair_phase<=1;end
      else begin snap_wr<=!snap_full;snap_data<={result_i,first_pixel};pair_phase<=0;if(snap_full)snap_bad<=1;end
      if(result_x==WIDTH-2&&result_y==HEIGHT-2)begin
       snap_bad<=snap_bad||snap_full||cancelled||clear_i||!source_ok||!processing_ok||source_id!=bound_id||samples!=PIXELS-1;
       snap_end<=~snap_end;state<=6;
      end
     end
    end
    6:if(done_sync!=done_seen)begin
     done_seen<=done_sync;
     if(ok_sync&&!snap_bad&&!cancelled&&!clear_i&&mode_i==7)begin
      old_slot=directory[next_tile*3+:3];
      pending_directory<=directory;pending_directory[next_tile*3+:3]<=temporary;
      pending_valid<=valid_tiles|(4'b1<<next_tile);pending_metadata<=metadata;
      pending_metadata[next_tile*128+:128]<={30'd0,bound_alg,bound_high,bound_low,bound_version,bound_id,24'd0};
      temporary<=old_slot;next_tile<=next_tile+1'b1;publish<=1;
     end else capture_errors<=capture_errors+1'b1;
     state<=0;
    end
   endcase
  end
 end
endmodule
