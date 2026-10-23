from pathlib import Path
P=Path(__file__).resolve().parents[1]
def edit(rel,changes):
 p=P/rel;s=p.read_text(encoding='utf-8-sig')
 for a,b in changes:
  assert a in s,(rel,a[:90]);s=s.replace(a,b)
 p.write_text(s,encoding='utf-8')
(P/'src/parallel/vision8_modes.vh').write_text('''// Shared presentation mapping. Internal algorithm IDs deliberately stay stable.
function [2:0] slot_to_mode;
 input [2:0] slot;
 begin case(slot)5:slot_to_mode=7;6:slot_to_mode=5;7:slot_to_mode=6;default:slot_to_mode=slot;endcase end
endfunction
function [2:0] mode_to_slot;
 input [2:0] mode;
 begin case(mode)7:mode_to_slot=5;5:mode_to_slot=6;6:mode_to_slot=7;default:mode_to_slot=mode;endcase end
endfunction
''',encoding='utf-8')
edit('rtl/vision8_controls.v',[
 ('// Board K1/K2 ports remain constrained but are ignored by this controller.','// K1 toggles PiP; K2 selects Canny BOTH/HIGH/LOW.'),
 ('parameter DEBOUNCE=1488000,LONG_CYCLES=148800000)(','parameter DEBOUNCE=1488000,LONG_CYCLES=148800000,CONTEXT_BITS=4)('),
 ('input[3:0]context_i','input[CONTEXT_BITS-1:0]context_i'),('reg[3:0]bound;','reg[CONTEXT_BITS-1:0]bound;'),
 (' // The original vision8_key module above is deliberately unchanged. Four\n // external inputs are released-high / pressed-low. K1/K2 are retained ports\n // for pin compatibility but have no control role in this revision.',' `include "vision8_modes.vh"\n // Six released-high / pressed-low inputs; selector changes cancel held edits.'),
 ('wire[3:0]s,l;','wire[5:0]s,l;'),('wire[3:0]key_context={user_mode==5&&learning,user_mode};','wire[5:0]key_context={selected,user_mode==5&&learning,user_mode};'),
 ('.LONG_CYCLES(LONG_CYCLES))', '.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6))'),
 (' wire[11:0]step=', ' vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) e(clk,rst_n,k1_n,key_context,s[4],l[4]);\n vision8_key #(.DEBOUNCE(DEBOUNCE),.LONG_CYCLES(LONG_CYCLES),.CONTEXT_BITS(6)) f(clk,rst_n,k2_n,key_context,s[5],l[5]);\n wire[11:0]step='),
 (' wire[11:0]high_up=increase(high,step,12\'d2040);\n wire[11:0]high_down=decrease(high,step,12\'d2);',''' wire[11:0]up_room=(12'd2040-high)>>1;
 wire[11:0]down_room_low=low-1'b1,down_room_gap=high-low-1'b1;
 wire[11:0]both_up=step<up_room?step:up_room;
 wire[11:0]down_room=down_room_low<down_room_gap?down_room_low:down_room_gap;
 wire[11:0]both_down=step<down_room?step:down_room;
 wire[2:0]next_mode=slot_to_mode(mode_to_slot(user_mode)+3'd1);
 task change_mode;
 input[2:0]target;
 begin
  if(user_mode==7&&target!=7)begin clear<=1;capture_alg<=0;end
  user_mode<=target;freeze_request<=0;diagnostic<=0;pure_o<=0;selected<=0;
 end
 endtask'''),
 ("1:begin high<=increment?high_up:high_down;low<=canny_low(increment?high_up:high_down);end",'''1:begin
     case(selected)
      1:high<=increment?increase(high,step,12'd2040):decrease(high,step,low+1'b1);
      2:low<=increment?increase(low,step,high-1'b1):decrease(low,step,12'd1);
      default:begin low<=increment?low+both_up:low-both_down;high<=increment?high+(both_up<<1):high-(both_down<<1);end
     endcase
    end'''),
 ('1:begin low<=40;high<=80;end','1:begin low<=40;high<=80;selected<=0;end'),
 ('settings_open<=0;selected<=0;','settings_open<=0;'),
 ("if(s[0])begin user_mode<=user_mode+1'b1;freeze_request<=0;diagnostic<=0;pure_o<=0;end","if(s[0])change_mode(next_mode);"),
 ('if(l[0]&&user_mode>=1&&user_mode<=3)pip_enable<=~pip_enable;','if(s[4]&&user_mode>=1&&user_mode<=3)pip_enable<=~pip_enable;\n    if(s[5]&&(user_mode==1||user_mode==4))selected<=selected==2?0:selected+1\'b1;'),
 ('if(l[3])restore_profile(profile);','if(s[5])begin end\n      else if(l[3])restore_profile(profile);'),
 ('if(l[1])clear<=1;','if(l[1])begin clear<=1;capture_alg<=0;end'),
 ('if(serial_data>="0"&&serial_data<="7")begin user_mode<=serial_data-"0";diagnostic<=0;pure_o<=0;freeze_request<=0;end','if(serial_data>="0"&&serial_data<="7")change_mode(slot_to_mode(serial_data[2:0]));'),
 ('"m":begin user_mode<=user_mode+1\'b1;diagnostic<=0;pure_o<=0;freeze_request<=0;end','"m":change_mode(next_mode);'),
 ('"r":begin user_mode<=0;','"r":begin change_mode(0);'),
 ('"p":begin pure_o<=~pure_o;user_mode<=0;diagnostic<=0;end','"p":begin change_mode(0);pure_o<=~pure_o;end'),
 ('begin user_mode<=0;diagnostic<=1;','begin change_mode(0);diagnostic<=1;')
])
# Main FIFO quality is measured in the consuming pixel domain, not from AR alone.
edit('rtl/vision8_base_axi.v',[
 ('input aux_protect,input[1:0]aux_slot','output reg read_frame_good,read_frame_bad,\n input aux_protect,input[1:0]aux_slot'),
 ('wire                            rfifo_wr_rst_busy;','wire                            rfifo_wr_rst_busy;\n wire read_underflow;\n localparam READ_PIXELS=C_RD_END_ADDR/(C_R_WIDTH/8);\n reg[$clog2(READ_PIXELS+2)-1:0]read_pixels;\n reg read_vs_prev;\n always @(posedge rframe_pclk or posedge axi_reset)begin\n  if(axi_reset)begin read_frame_good<=0;read_frame_bad<=0;read_pixels<=0;read_vs_prev<=1;end\n  else begin\n   read_vs_prev<=rframe_vsync;\n   if(rframe_vsync&&!read_vs_prev)read_frame_good<=read_pixels==READ_PIXELS&&!read_frame_bad;\n   if(!rframe_vsync&&read_vs_prev)begin read_pixels<=0;read_frame_bad<=0;end\n   else if(rframe_data_en)begin\n    if(read_pixels<READ_PIXELS+1)read_pixels<=read_pixels+1\'b1;\n    if(w_rfifo_empty||rfifo_wr_rst_busy||w_rfifo_rst||read_pixels>=READ_PIXELS)read_frame_bad<=1;\n   end\n   if(read_underflow)read_frame_bad<=1;\n  end\n end'),
 ('.almost_empty_o\t(w_rfifo_aempty)', '.almost_empty_o\t(w_rfifo_aempty),.underflow_o(read_underflow),.rst_busy(rfifo_wr_rst_busy)')
])
edit('rtl/vision8_ddr.v',[
 ('parameter \tC_ID_LEN', 'parameter SNAP_TIMEOUT=134217727,\n\t\tC_ID_LEN'),
 ('input snap_begin,snap_end,input[2:0]snap_slot','input snap_begin,snap_end,snap_abort,input[2:0]snap_slot'),
 ('output reg snap_done,snap_ok,output[31:0]source_id,','output reg snap_done,snap_ok,output read_frame_good,read_frame_bad,output[31:0]source_id,'),
 ('reg sb_seen,se_seen;','reg sb_seen,se_seen;\n (* async_reg="true" *)reg abort_meta,abort_sync;\n reg aborting;\n wire abort_now=aborting||abort_sync||snapshot_watchdog>=SNAP_TIMEOUT;'),
 ('wire snap_pop=snapshot_running&&write_owner==2&&write_data&&!packed_valid&&!snap_empty;','wire snap_pop=snapshot_running&&write_owner==2&&write_data&&!packed_valid&&!snap_empty&&!abort_now;'),
 ('wire snapshot_request=snapshot_running&&snapshot_bytes<FRAME_W*FRAME_H/2&&snap_level>=128;','wire snapshot_request=snapshot_running&&!abort_now&&snapshot_bytes<FRAME_W*FRAME_H/2&&snap_level>=128;'),
 ('.main_enable(main_enable),.raw_slot(raw_slot)', '.read_frame_good(read_frame_good),.read_frame_bad(read_frame_bad),.main_enable(main_enable),.raw_slot(raw_slot)'),
 ('snapshot_running<=0;snapshot_failed<=0;', 'abort_meta<=0;abort_sync<=0;aborting<=0;snapshot_running<=0;snapshot_failed<=0;'),
 ('sbm<=snap_begin;sbs<=sbm;', 'abort_meta<=snap_abort;abort_sync<=abort_meta;\n   sbm<=snap_begin;sbs<=sbm;'),
 ('sb_seen<=sbs;snapshot_running<=1;', 'sb_seen<=sbs;snapshot_running<=1;aborting<=0;'),
 ('''    if(ses!=se_seen&&(snapshot_bytes==FRAME_W*FRAME_H/2||snapshot_watchdog==27'h7ffffff)&&write_owner==0)begin
     snap_ok<=snapshot_bytes==FRAME_W*FRAME_H/2&&!snapshot_failed&&!bads;snap_done<=~snap_done;snapshot_running<=0;se_seen<=ses;
    end''','''    if(abort_now)aborting<=1;
    // A cancellation does not need an end-of-frame token. Presented AW/W
    // remain stable; completion waits until that snapshot owner has drained B.
    if((abort_now||(ses!=se_seen&&snapshot_bytes==FRAME_W*FRAME_H/2))&&write_owner!=2)begin
     snap_ok<=!abort_now&&snapshot_bytes==FRAME_W*FRAME_H/2&&!snapshot_failed&&!bads;
     snap_done<=~snap_done;snapshot_running<=0;se_seen<=ses;aborting<=0;
    end'''),
 ('   if(axi_wvalid&&axi_wready)begin','''   if(snapshot_running&&write_owner==2&&write_data&&!packed_valid&&abort_now)begin
    packed_data<=0;packed_valid<=1;pack_index<=0;
   end
   if(axi_wvalid&&axi_wready)begin''')
])
edit('example_top.v',[
 ('wire aux_request,aux_ack,aux_frame_ready,snap_begin,snap_end,','wire snap_abort,read_frame_good,read_frame_bad;\n wire aux_request,aux_ack,aux_frame_ready,snap_begin,snap_end,'),
 ('.snap_begin(snap_begin),.snap_end(snap_end),', '.snap_abort(snap_abort),.snap_begin(snap_begin),.snap_end(snap_end),'),
 ('.main_frame_ok(main_frame_ok_axi),', '.read_frame_good(read_frame_good),.read_frame_bad(read_frame_bad),.main_frame_ok(main_frame_ok_axi),'),
 ('.processing_ok(main_frame_ok_pixel)', '.processing_ok(main_frame_ok_pixel&&read_frame_good&&!read_frame_bad)'),
 ('output_user_mode==1||output_user_mode==4?threshold_high:', 'output_user_mode==1||output_user_mode==4?threshold_low:')
])
# Existing pin assignments stay untouched. Only K1/K2 first-stage inputs added.
p=P/'Ti60_Demo.pt.sdc';p.write_text(p.read_text()+'''\n# Board keys: async input exception stops at the first synchronizer D pin.
set_false_path -from [get_ports {key_mode_n}] -to [get_pins {controls/e/meta~FF|D}]
set_false_path -from [get_ports {key_freeze_n}] -to [get_pins {controls/f/meta~FF|D}]
''')
print('updated controls, main-read quality, DMA cancellation and top wiring')
