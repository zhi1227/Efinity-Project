from pathlib import Path
P=Path(__file__).resolve().parents[1]
S=Path(r'D:\Github_Project\Efinity-Project\9.22.2_ding_Ti60F225_Canny_Face_Parallel')
t=(S/'Ti60_Demo.xml').read_text(encoding='utf-8-sig')
keep=['rgb565_to_gray.v','rgb565_to_rgb888.v','line_buffer_3x3.v','sobel3x3.v','uart_params.v','video_delay.v']
lines=[]
for l in t.splitlines():
 if 'design_file' in l and any(s in l for s in ['src/vision/','src/parallel/','src/face/']) and not any(s in l for s in keep):continue
 if 'top_vhdl_arch' in l:
  for n in ['haar_engine.v','haar_face_video.v']:lines.append(f'        <efx:design_file name="src/haar/{n}" version="default" library="default" />')
 lines.append(l)
(P/'Ti60_Demo.xml').write_text('\n'.join(lines)+'\n',encoding='utf-8')
