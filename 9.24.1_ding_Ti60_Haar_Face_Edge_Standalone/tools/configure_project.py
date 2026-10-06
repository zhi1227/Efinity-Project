from pathlib import Path
import xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1]
f=P/'example_top.v';t=f.read_text(encoding='utf-8-sig');t=t.replace('parallel_video u_parallel','haar_face_video u_haar');f.write_text(t,encoding='utf-8')
f=P/'src/parallel/uart_params.v';t=f.read_text(encoding='utf-8-sig');t=t.replace('mode<=3','mode<=1').replace("mode<=3'd3","mode<=3'd1");f.write_text(t,encoding='utf-8')
f=P/'Ti60_Demo.xml';ns='http://www.efinixinc.com/enf_proj';ET.register_namespace('efx',ns);r=ET.parse(f);d=r.find(f'{{{ns}}}design_info')
keep={'src/vision/rgb565_to_gray.v','src/vision/rgb565_to_rgb888.v','src/vision/line_buffer_3x3.v','src/vision/sobel3x3.v','src/parallel/uart_params.v','src/parallel/video_delay.v'}
for el in list(d):
 name=el.get('name','')
 if any(name.startswith(q) for q in ['src/vision/','src/face/','src/parallel/']) and name not in keep:d.remove(el)
for name in ['src/haar/haar_engine.v','src/haar/haar_face_video.v']:ET.SubElement(d,f'{{{ns}}}design_file',{'name':name,'version':'default','library':'default'})
r.write(f,encoding='utf-8',xml_declaration=True)
