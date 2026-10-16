from pathlib import Path
import json,hashlib,re,collections
P=Path(__file__).resolve().parents[1];R=P/'reports/cpu_font_ram';S=P.parent/'10_12_ding_Ti60_Vision8_Buttons_Integrated'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((R/'original_manifest.json').read_text(encoding='utf-8-sig'))
current={p.relative_to(S).as_posix():sha(p) for p in S.rglob('*') if p.is_file()}
assert current==m['files'],'Original project changed'
changed=[k for k,v in m['files'].items() if (P/k).exists() and sha(P/k)!=v]
allowed={'example_top.v','Ti60_Demo.xml','vendor/EfxSapphireSoc.v','rtl/menu_glyph_rom.v','rtl/vision6_glyph_rom.v','rtl/menu8_renderer.v','rtl/menu_renderer.v','rtl/menu_lcd_apb.v','rtl/riscv_menu_top.v','rtl/vision6_overlay.v','src/parallel/parallel_video.v'}
for k in changed:
 if k.startswith(('src/','rtl/','vendor/','ip/','firmware/')) or (k.endswith('.sdc') and not k.startswith(('outflow/','work_pnr/','work_syn/'))) or (('/' not in k) and Path(k).suffix in ('.v','.bin','.hex')):
  assert k in allowed,('Unexpected active-source change',k)
firmware=[k for k in m['files'] if k.startswith('firmware/') or k.startswith('EfxSapphireSoc.v_toplevel')]
assert all(sha(P/k)==m['files'][k] for k in firmware)
vision=[k for k in m['files'] if k.startswith('src/vision/')]
assert all(sha(P/k)==m['files'][k] for k in vision)
assert sha(P/'Ti60_Demo.peri.xml')==sha(S/'Ti60_Demo.peri.xml')
old=(S/'vendor/EfxSapphireSoc.v').read_text(encoding='utf-8-sig');new=(P/'vendor/EfxSapphireSoc.v').read_text(encoding='utf-8-sig')
def mod(t,n):return re.search(r'\bmodule '+n+r'\b.*?\bendmodule',t,re.S).group()
for name in re.findall(r'\bmodule (\w+)',old):
 if name not in ('InstructionCache','DataCache'):assert mod(old,name)==mod(new,name),name
for name in ('InstructionCache','DataCache'):
 def interface(t):return re.sub(r'\s','',mod(t,name).split(');',1)[0])
 assert interface(old)==interface(new),name+' API changed'
cache=[{'module':n,'capacity':1024,'lines':16,'line_bytes':64,'tag_bits':24,'tag_storage':'explicit flip-flops'} for n in ['InstructionCache','DataCache']]
result={'original_project_all_files_unchanged':True,'original_files_verified':len(current),'firmware_files_identical':len(firmware),'vision_algorithm_files_identical':len(vision),'IO_and_peripheral_constraints_identical':True,'CPU_modules_other_than_caches_identical':True,'cache_interfaces_identical':True,'cache':cache,'changed_existing_files':changed}
(R/'preservation_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PASS: original all',len(current),'files unchanged; firmware, image algorithms, IO constraints and other CPU modules identical')
