from pathlib import Path
import re,json
P=Path(__file__).resolve().parents[1];S=P.parent/'10_12_ding_Ti60_Vision8_Buttons_Integrated';R=P/'reports/cpu_font_ram'
t=(S/'vendor/EfxSapphireSoc.v').read_text(encoding='utf-8-sig');proof={}
for name in ['InstructionCache','DataCache']:
 m=re.search(r'\bmodule '+name+r'\b.*?\bendmodule',t,re.S);src=m.group();v=src;changes=[]
 # Only the cache modules use these widths for cache data/tag indices.
 for a,b in [(9,7),(21,23),(19,21),(5,3),(6,4)]:
  pattern=r'\[\s*'+str(a)+r'\s*:\s*0\s*\]'
  v,n=re.subn(pattern,'['+str(b)+':0]',v);changes.append([pattern,n])
 v=re.sub(r'\[11\s*:\s*(2|6)\]',lambda m:'[9 : '+m[1]+']',v)
 v=re.sub(r'\[31\s*:\s*12\]','[31 : 10]',v)
 v=re.sub(r'\[21\s*:\s*2\]','[23 : 2]',v)
 v=v.replace('[0:1023]','[0:255]').replace('[0:63]','[0:15]')
 v=re.sub(r'(lineLoader_flushCounter|stageB_flusher_counter)\[6\]',r'\1[4]',v)
 v=v.replace("7'h01","5'h01").replace("7'h0","5'h0")
 for a,b in [(6,4),(10,8),(20,22)]:v=v.replace(str(a)+"'b"+'x'*a,str(b)+"'b"+'x'*b)
 if name=='DataCache':
  v=v.replace("io_mem_cmd_payload_address[3:0] = 6'h0;","io_mem_cmd_payload_address[5:0] = 6'h0;")
  v=v.replace('[3:0]    io_cpu_flush_payload_lineId','[5:0]    io_cpu_flush_payload_lineId')
  v=v.replace("{1'b0,io_cpu_flush_payload_lineId}","{1'b0,io_cpu_flush_payload_lineId[3:0]}")
 assert '[0:1023]' not in v and '[0:63]' not in v
 t=t[:m.start()]+v+t[m.end():];proof[name]={'bytes':1024,'changes':changes}
# Explicit register tags preserve the original synchronous read and write timing.
for name,read_addr,write_addr in [('InstructionCache','_zz_fetchStage_read_waysValues_0_tag_valid','lineLoader_write_tag_0_payload_address'),('DataCache','tagsReadCmd_payload','tagsWriteCmd_payload_address')]:
 m=re.search(r'\bmodule '+name+r'\b.*?\bendmodule',t,re.S);v=m.group()
 assert 'reg [23:0] ways_0_tags [0:15];' in v
 v=v.replace('reg [23:0] ways_0_tags [0:15];',f"""// 16x24 tag bits: explicit registers save two 10K RAM blocks per cache.
 wire[383:0]ways_0_tags_words;
 genvar tag_index;
 generate for(tag_index=0;tag_index<16;tag_index=tag_index+1)begin:tag_registers
  reg[23:0]tag_word;
  always @(posedge io_systemClk)if(_zz_2 && {write_addr}==tag_index)
   tag_word<=_zz_ways_0_tags_port;
  assign ways_0_tags_words[tag_index*24+:24]=tag_word;
 end endgenerate""")
 pattern=r'  always @\(posedge io_systemClk\) begin\s+if\(_zz_2\) begin\s+ways_0_tags\['+write_addr+r'\] <= _zz_ways_0_tags_port;\s+end\s+end'
 v,n=re.subn(pattern,'',v);assert n==1
 v=v.replace('ways_0_tags['+read_addr+']','ways_0_tags_words['+read_addr+'*24+:24]')
 t=t[:m.start()]+v+t[m.end():]
 proof[name]['tag_storage']='16 x 24 bit explicit flip-flops; unchanged synchronous read-before-write'
(P/'vendor/EfxSapphireSoc.v').write_text(t,encoding='utf-8')
(R/'cache_capacity_changes.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
print('Cache modules reduced to 1 KiB, original controller logic retained')
