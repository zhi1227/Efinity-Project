// Pixel-domain capture directory, pre-HUD downsampling and final-raster compositor.
// Five DDR slots permit replacing a full four-tile directory atomically.
module vision8_frames #(parameter WIDTH=1280,HEIGHT=720,WATCHDOG_CYCLES=4*1650*750,DIAGNOSTICS=1)(
 input clk,rst_n,input[2:0]mode_i,input[1:0]algorithm_i,
 input pip_i,capture_i,clear_i,freeze_active,input[31:0]source_id,
 input[11:0]low_i,high_i,input[15:0]version_i,input source_ok,processing_ok,
 input[3:0]face_count,input face_valid,face_saturated,
 input[23:0]rgb_i,input de_i,vs_i,hs_i,
 input[15:0]result_i,input result_de,result_vs,input[10:0]result_x,input[9:0]result_y,
 output reg[23:0]rgb_o,output reg de_o,vs_o,hs_o,
 output busy,lock_source,main_enable,output[2:0]mode_committed,output[11:0]capture_low,capture_high,output[3:0]capture_backend,
 output reg snap_abort,output reg snap_begin,snap_end,output reg[2:0]snap_slot,output reg snap_bad,snap_reset,
 output reg snap_wr,output reg[31:0]snap_data,input snap_full,
 input snap_done,snap_ok,
 output reg aux_request,output reg[1:0]aux_kind,output reg[15:0]aux_directory,
 input aux_ack,input[31:0]aux_data,input aux_empty,input aux_frame_ready,
 input[159:0]debug_memory,input[10:0]aux_read_level,input[1:0]freeze_debug,
 output aux_rd,output reg[3:0]valid_tiles,
 output reg[511:0]metadata,output reg[31:0]underflows,capture_errors);
 localparam HALF_W=WIDTH/2,HALF_H=HEIGHT/2,PIXELS=HALF_W*HALF_H;
 reg[7:0]capture_fault;reg[3:0]aux_fault,capture_fault_state;reg[31:0]capture_fault_id,aux_fault_id;
 reg[10:0]first_aux_x;reg[9:0]first_aux_y;
 reg[10:0]aux_min_level;reg[31:0]capture_events;
 reg[3:0]state;reg[2:0]mode_active;reg[1:0]warm,next_tile;reg[2:0]temporary;
 reg vsq,rvsq,pair_phase;reg[15:0]first_pixel;
 reg[18:0]samples;reg cancelled;reg[6:0]reset_count;
 localparam WD_BITS=$clog2(WATCHDOG_CYCLES+1);
 reg[WD_BITS-1:0]watchdog;
 reg[3:0]previous_state;
 reg dma_done,dma_ok;
 reg[20:0]frame_count;
 reg[10:0]expected_x;reg[9:0]expected_y;
 reg frame_bad;reg[31:0]frame_id;
 wire frame_complete=frame_count==WIDTH*HEIGHT&&!frame_bad&&processing_ok&&source_ok&&frame_id==source_id;
 wire timeout=watchdog==WATCHDOG_CYCLES-1;
 wire leave_or_clear=clear_i||mode_i!=7;
 reg[1:0]bound_alg;reg[11:0]bound_low,bound_high;reg[15:0]bound_version;reg[31:0]bound_id;
 reg[11:0]directory,pending_directory;reg[3:0]pending_valid;reg publish;
 reg[2:0]old_slot;reg[511:0]pending_metadata;
 (* async_reg="true" *)reg done_meta,done_sync,ok_meta,ok_sync;
 reg done_seen;reg[1:0]done_wait;
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
 function[63:0]hex32;input[31:0]v;integer h;
 begin for(h=0;h<8;h=h+1)hex32[63-h*8-:8]=hexchar(v[31-h*4-:4]);end endfunction
 function[31:0]hex16;input[15:0]v;
 begin hex16={hexchar(v[15:12]),hexchar(v[11:8]),hexchar(v[7:4]),hexchar(v[3:0])};end endfunction
 function[15:0]hex8;input[7:0]v;begin hex8={hexchar(v[7:4]),hexchar(v[3:0])};end endfunction
 function[7:0]digit;input[11:0]v;input[1:0]pos;
 begin case(pos)0:digit=48+v/1000;1:digit=48+(v/100)%10;2:digit=48+(v/10)%10;default:digit=48+v%10;endcase end endfunction
 always @*begin
  label=0;label_char=32;label_x=0;label_y=0;label_area=0;c=0;label_low=low_i;label_high=high_i;
  if(mode_active==7)begin
   label_x=local_x-8;label_y=local_y-8;label_area=local_x>=8&&local_x<584&&local_y>=8&&local_y<24;
   if(valid_tiles[tile])begin
    case(tile_meta[97:96])0:label={"RAW   T:----        F:00000000 V:0000",88'd0};1:label={"CANNY L:0000 H:0000 F:00000000 V:0000",88'd0};
     2:label={"RED   T:0000        F:00000000 V:0000",88'd0};default:label={"CYBER T:0000        F:00000000 V:0000",88'd0};endcase
    label_low=tile_meta[83:72];label_high=tile_meta[95:84];
   end else if(busy)label={"BUSY - CAPTURE / DRAIN",208'd0};
   else if(capture_errors!=0)label={"CAPTURE FAILED - RETRY",208'd0};
   else label={"EMPTY - IO29 CAPTURE",224'd0};
  end else if(mode_active>=5)begin
   label_x=x-16;label_y=y-8;label_area=x>=16&&x<592&&y>=8&&y<40;
   case(mode_active)
    6:label={"08 FACE CANDIDATES: - ",208'd0};
    5:label={"07 GESTURE - IO34 ENROL",200'd0};
   endcase
  end
  // Two compact diagnostic rows per half screen, using the existing font.
  // Saved pixels are pre-HUD. No metadata or gesture bits are repurposed.
  if(DIAGNOSTICS&&mode_active==7&&y>=HEIGHT-48&&y<HEIGHT-8)begin
   label_x=local_x-8;label_y=(y>=HEIGHT-28)?y-(HEIGHT-28):y-(HEIGHT-48);
   label_area=local_x>=8&&local_x<584&&label_y<16;
   if(x<HALF_W)begin
    if(y<HEIGHT-28)label={"V2.22 S:",hexchar(capture_fault!=0?capture_fault_state:state)," E:",hex8(capture_fault)," A:",hexchar(aux_fault)," U:",hex32(underflows)," L:",hexchar({freeze_debug,lock_source,freeze_active})," P:",hexchar({source_ok,processing_ok,ready_sync,aux_empty}),88'd0};
    else label={"N:",hex32({13'd0,samples})," F:",hex32(capture_fault!=0?capture_fault_id:(aux_fault!=0?aux_fault_id:source_id))," C:",hex32(capture_events),128'd0};
   end else begin
    if(y<HEIGHT-28)label={"W:",hex32(debug_memory[63:32])," M:",hex32(debug_memory[95:64])," X:",hex32(debug_memory[31:0]),128'd0};
    else label={"Q:",hex16({5'd0,aux_read_level})," m:",hex16({5'd0,aux_min_level})," XY:",hex16({5'd0,first_aux_x}),"/",hex16({6'd0,first_aux_y})," D:",hex8(debug_memory[159:152]),136'd0};
   end
  end
  c=label_x/12;
  if(c<48)label_char=label[383-c*8-:8];
  if(mode_active==7&&valid_tiles[tile]&&(!DIAGNOSTICS||y<HEIGHT-48))begin
   if(c>=8&&c<12&&tile_meta[97:96]!=0)label_char=digit(tile_meta[97:96]==1?label_low:label_high,c-8);
   if(c>=15&&c<19&&tile_meta[97:96]==1)label_char=digit(label_high,c-15);
   if(c>=22&&c<30)label_char=hexchar(tile_meta[24+(29-c)*4+:4]);
   if(c>=33&&c<37)label_char=hexchar(tile_meta[56+(36-c)*4+:4]);
  end
  if(mode_active==6&&c==20)label_char=face_valid?hexchar(face_count):"-";
  if(mode_active==6&&c==21)label_char=face_saturated?"+":" ";
 end
 wire label_ink;
 vision8_ascii text(label_char,mode_active==7?label_y[3:1]:label_y[4:2],(label_x%12)>>1,label_ink);
 assign mode_committed=mode_active;
 assign busy=state!=0||publish;
 assign lock_source=state>=1&&state<=6&&!cancelled&&!leave_or_clear;
 assign main_enable=1'b1; // Keep the consuming raster fed even in an idle comparison view.
 assign capture_low=bound_low;assign capture_high=bound_high;
 assign capture_backend=bound_alg==0?4'd0:bound_alg==1?4'd1:bound_alg==2?4'd10:4'd9;
 always @(posedge clk)begin
  if(!rst_n)begin
   capture_fault<=0;aux_fault<=0;capture_fault_state<=0;capture_fault_id<=0;aux_fault_id<=0;first_aux_x<=0;first_aux_y<=0;aux_min_level<=11'd1024;capture_events<=0;
   watchdog<=0;previous_state<=0;dma_done<=0;dma_ok<=0;frame_count<=0;expected_x<=0;expected_y<=0;frame_bad<=1;frame_id<=0;snap_abort<=0;
   state<=0;mode_active<=0;warm<=0;next_tile<=0;temporary<=4;vsq<=1;rvsq<=1;pair_phase<=0;first_pixel<=0;samples<=0;cancelled<=0;reset_count<=0;
   bound_alg<=0;bound_low<=40;bound_high<=80;bound_version<=0;bound_id<=0;directory<=12'h688;pending_directory<=12'h688;pending_valid<=0;publish<=0;old_slot<=0;pending_metadata<=0;
   snap_begin<=0;snap_end<=0;snap_slot<=4;snap_bad<=0;snap_reset<=1;snap_wr<=0;snap_data<=0;aux_request<=0;aux_kind<=0;aux_directory<=0;
   valid_tiles<=0;metadata<=0;underflows<=0;capture_errors<=0;done_meta<=0;done_sync<=0;done_seen<=0;done_wait<=0;ok_meta<=0;ok_sync<=0;
   ack_meta<=0;ack_sync<=0;ready_meta<=0;ready_sync<=0;x<=0;y<=0;pixel_half<=0;invalid_frame<=0;pip_active<=0;rgb_o<=0;de_o<=0;vs_o<=0;hs_o<=0;
  end else begin
   vsq<=vs_i;rvsq<=result_vs;snap_wr<=0;
   if(read_pixel&&aux_read_level<aux_min_level)aux_min_level<=aux_read_level;
   if(use_aux&&!invalid_frame&&(!ready_sync||aux_empty)&&aux_fault==0)begin
    aux_fault<=!ready_sync?4'h1:4'h2;first_aux_x<=x;first_aux_y<=y;aux_fault_id<=source_id;
   end
   if(state>=1&&state<=6&&capture_fault==0)begin
    capture_fault_id<=source_id;capture_fault_state<=state;
    if(timeout)capture_fault<=state==1?8'h01:state==2?8'h02:8'h08;
    else if(state==5)begin
     if(source_id!=bound_id)capture_fault<=8'h03;
     else if(!source_ok||!processing_ok)capture_fault<=8'h09;
     else if(result_de&&(result_x!=expected_x||result_y!=expected_y))capture_fault<=8'h04;
     else if(snap_full&&result_de&&!result_x[0]&&!result_y[0]&&pair_phase)capture_fault<=8'h06;
     else if(process_start)capture_fault<=8'h05;
    end else if(state==6&&dma_done&&process_start&&(!dma_ok||snap_bad))capture_fault<=8'h07;
   end
   previous_state<=state;
   if(state==0||state>=7||state!=previous_state||(state==5&&result_de)||(state==2&&process_start&&frame_complete))watchdog<=0;
   else if(!timeout)watchdog<=watchdog+1'b1;
   // Bundled result remains stable until the next completion. Allow two
   // extra pixel clocks after the synchronized event before sampling status.
   if(done_sync!=done_seen)begin done_seen<=done_sync;done_wait<=2;end
   else if(done_wait!=0)begin
    done_wait<=done_wait-1'b1;
    if(done_wait==1)begin dma_done<=1;dma_ok<=ok_sync;end
   end
   // Validate every coordinate, including the final odd row/column. Bind
   // the source tag at the first valid sample, after the source CDC settles.
   if(process_start)begin frame_count<=0;expected_x<=0;expected_y<=0;frame_bad<=0;end
   else if(result_de)begin
    if(frame_count==0)frame_id<=source_id;
    else if(source_id!=frame_id)frame_bad<=1;
    if(result_x!=expected_x||result_y!=expected_y||frame_count>=WIDTH*HEIGHT)frame_bad<=1;
    if(!source_ok||!processing_ok)frame_bad<=1;
    if(frame_count<WIDTH*HEIGHT+1)frame_count<=frame_count+1'b1;
    if(expected_x==WIDTH-1)begin expected_x<=0;expected_y<=expected_y+1'b1;end else expected_x<=expected_x+1'b1;
   end
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
   case(state)
    0:begin
     snap_reset<=1;snap_abort<=0;
     if(capture_i&&mode_i==7&&!clear_i)begin
      capture_events<=capture_events+1'b1;capture_fault<=0;aux_fault<=0;aux_min_level<=11'd1024;
      state<=1;warm<=0;cancelled<=0;dma_done<=0;snap_bad<=0;
      bound_alg<=algorithm_i;bound_low<=low_i;bound_high<=high_i;bound_version<=version_i;
     end
    end
    1:if(process_start&&freeze_active&&source_ok)begin warm<=0;state<=2;end
    2:if(process_start)begin
     if(frame_complete&&freeze_active)begin
      bound_id<=frame_id;
      if(warm==1)begin state<=3;reset_count<=0;snap_slot<=temporary;end else warm<=warm+1'b1;
     end else warm<=0;
    end
    3:begin
     snap_reset<=0;
     if(reset_count==63)begin snap_begin<=~snap_begin;state<=4;end else reset_count<=reset_count+1'b1;
    end
    4:if(process_start)begin state<=5;samples<=0;pair_phase<=0;snap_bad<=!source_ok||!processing_ok;end
    5:begin
     if(!source_ok||!processing_ok||source_id!=bound_id)snap_bad<=1;
     if(result_de)begin
      if(result_x!=expected_x||result_y!=expected_y)snap_bad<=1;
      if(!result_x[0]&&!result_y[0])begin
       samples<=samples+1'b1;
       if(!pair_phase)begin first_pixel<=result_i;pair_phase<=1;end
       else begin snap_wr<=!snap_full;snap_data<={result_i,first_pixel};pair_phase<=0;if(snap_full)snap_bad<=1;end
      end
      if(result_x==WIDTH-1&&result_y==HEIGHT-1)begin
       snap_bad<=snap_bad||frame_bad||pair_phase||source_id!=bound_id||samples!=PIXELS||frame_count!=WIDTH*HEIGHT-1||!source_ok||!processing_ok;
       snap_end<=~snap_end;state<=6;
      end
     end
     if(process_start)begin snap_bad<=1;cancelled<=1;snap_abort<=1;state<=7;capture_errors<=capture_errors+1'b1;end
    end
    6:if(dma_done&&process_start&&!leave_or_clear&&!timeout)begin
     if(dma_ok&&!snap_bad&&!cancelled&&source_ok&&processing_ok&&source_id==bound_id&&mode_i==7)begin
      old_slot=directory[next_tile*3+:3];
      pending_directory<=directory;pending_directory[next_tile*3+:3]<=temporary;
      pending_valid<=valid_tiles|(4'b1<<next_tile);pending_metadata<=metadata;
      pending_metadata[next_tile*128+:128]<={30'd0,bound_alg,bound_high,bound_low,bound_version,bound_id,24'd0};
      temporary<=old_slot;next_tile<=next_tile+1'b1;publish<=1;
     end else capture_errors<=capture_errors+1'b1;
     state<=8;reset_count<=0;snap_reset<=1;
    end
    7:begin
     // DMA owns the FIFO until it acknowledges all presented AW/W/B.
     snap_abort<=1;
     if(dma_done)begin snap_abort<=0;snap_reset<=1;reset_count<=0;state<=8;end
    end
    8:begin
     snap_abort<=0;snap_reset<=1;
     if(reset_count==63)state<=0;else reset_count<=reset_count+1'b1;
    end
    default:state<=0;
   endcase
   // Highest priority: discard publication and release the source immediately.
   // Never reset a FIFO belonging to an outstanding snapshot transaction.
   if((leave_or_clear||timeout)&&state>=1&&state<=6)begin
    cancelled<=1;snap_bad<=1;snap_wr<=0;publish<=0;
    if(timeout)capture_errors<=capture_errors+1'b1;
    if(state<=3)begin state<=0;snap_reset<=1;snap_begin<=snap_begin;end
    else if(dma_done)begin state<=8;reset_count<=0;snap_reset<=1;end
    else begin state<=7;snap_abort<=1;end
   end
   if(leave_or_clear)begin
    valid_tiles<=0;pending_valid<=0;metadata<=0;pending_metadata<=0;publish<=0;next_tile<=0;
    directory<=12'h688;pending_directory<=12'h688;temporary<=4;
    capture_fault<=0;aux_fault<=0;aux_min_level<=11'd1024;capture_errors<=0;if(clear_i||mode_active==7)underflows<=0;
   end

  end
 end
endmodule
