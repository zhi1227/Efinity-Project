from pathlib import Path
P=Path(__file__).resolve().parents[1];p=P/'rtl/vision8_frames.v';s=p.read_text()
s=s.replace('parameter WIDTH=1280,HEIGHT=720','parameter WIDTH=1280,HEIGHT=720,WATCHDOG_CYCLES=4*1650*750')
s=s.replace('output reg snap_begin,snap_end,','output reg snap_abort,output reg snap_begin,snap_end,')
s=s.replace('reg[2:0]state,mode_active;','reg[3:0]state;reg[2:0]mode_active;')
s=s.replace(' reg[1:0]bound_alg;', ''' localparam WD_BITS=$clog2(WATCHDOG_CYCLES+1);
 reg[WD_BITS-1:0]watchdog;
 reg[3:0]previous_state;
 reg dma_done,dma_ok;
 reg[20:0]frame_count;
 reg[10:0]expected_x;reg[9:0]expected_y;
 reg frame_bad;reg[31:0]frame_id;
 wire frame_complete=frame_count==WIDTH*HEIGHT&&!frame_bad&&processing_ok&&source_ok&&frame_id==source_id;
 wire timeout=watchdog==WATCHDOG_CYCLES-1;
 wire leave_or_clear=clear_i||mode_i!=7;
 reg[1:0]bound_alg;''')
s=s.replace('1:label={"CANNY T:0000        F:00000000 V:0000",88\'d0};','1:label={"CANNY L:0000 H:0000 F:00000000 V:0000",88\'d0};')
s=s.replace('end else label={"EMPTY - IO29 CAPTURE",232\'d0};','end else if(busy)label={"BUSY - CAPTURE / DRAIN",216\'d0};\n   else if(capture_errors!=0)label={"CAPTURE FAILED - RETRY",216\'d0};\n   else label={"EMPTY - IO29 CAPTURE",232\'d0};')
s=s.replace('"07 FACE','"08 FACE').replace('"06 GESTURE','"07 GESTURE')
s=s.replace("if(c>=8&&c<12&&tile_meta[97:96]!=0)label_char=digit(label_high,c-8);", "if(c>=8&&c<12&&tile_meta[97:96]!=0)label_char=digit(tile_meta[97:96]==1?label_low:label_high,c-8);\n   if(c>=15&&c<19&&tile_meta[97:96]==1)label_char=digit(label_high,c-15);")
s=s.replace('assign lock_source=state!=0;','assign lock_source=state>=1&&state<=6&&!cancelled&&!leave_or_clear;')
s=s.replace('assign main_enable=mode_i!=7||state!=0;',"assign main_enable=1'b1; // Keep the consuming raster fed even in an idle comparison view.")
s=s.replace('state<=0;mode_active<=0;', 'watchdog<=0;previous_state<=0;dma_done<=0;dma_ok<=0;frame_count<=0;expected_x<=0;expected_y<=0;frame_bad<=1;frame_id<=0;snap_abort<=0;\n   state<=0;mode_active<=0;')
s=s.replace('   vsq<=vs_i;rvsq<=result_vs;snap_wr<=0;', '''   vsq<=vs_i;rvsq<=result_vs;snap_wr<=0;
   previous_state<=state;
   if(state==0||state>=7||state!=previous_state||(state==5&&result_de)||(state==2&&process_start&&frame_complete))watchdog<=0;
   else if(!timeout)watchdog<=watchdog+1'b1;
   if(done_sync!=done_seen)begin done_seen<=done_sync;dma_done<=1;dma_ok<=ok_sync;end
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
   end''')
a=s.index('   if(clear_i)begin cancelled<=1;');b=s.index('\n  end\n end\nendmodule',a)
s=s[:a]+'''   case(state)
    0:begin
     snap_reset<=1;snap_abort<=0;
     if(capture_i&&mode_i==7&&!clear_i)begin
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
    6:if(dma_done&&process_start)begin
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
    if(state<=3)begin state<=0;snap_reset<=1;end
    else if(dma_done)begin state<=8;reset_count<=0;snap_reset<=1;end
    else begin state<=7;snap_abort<=1;end
   end
   if(leave_or_clear)begin
    valid_tiles<=0;pending_valid<=0;metadata<=0;pending_metadata<=0;publish<=0;next_tile<=0;
    directory<=12'h688;pending_directory<=12'h688;temporary<=4;
    capture_errors<=0;underflows<=0;
   end
''' + s[b:]
p.write_text(s)
print('capture frame controller updated')
