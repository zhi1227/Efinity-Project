from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
top = ROOT / 'example_top.v'
text = top.read_text(encoding='utf-8-sig')
if 'demo_video u_gesture' in text:
    start = text.index(' demo_video u_gesture')
    end = text.index('.alarm_o(face_overrun),.model_ready(),.gesture_valid(),.gesture_id());', start)
    end += len('.alarm_o(face_overrun),.model_ready(),.gesture_valid(),.gesture_id());')
    text = text[:start] + ''' assign freeze_request=1'b0;
 assign face_overrun=1'b0;
 ep1_video u_project1(.clk(clk_pixel),.rst_n(rstn_pixel),.rgb_i({lcd_red,lcd_green,lcd_blue}),
 .de_i(lcd_de),.vs_i(lcd_vs),.hs_i(lcd_hs),
 .key_mode_n(key_mode_n),.key_threshold_n(key_freeze_n),
 .rgb_o(face_overlay_rgb),.de_o(face_overlay_de),.vs_o(face_overlay_vs),.hs_o(face_overlay_hs),
 .mode_o(),.threshold_o(),.gesture_o(),.feature_o(),.box_valid_o());''' + text[end:]
    text = text.replace('// K2 freezes the displayed DDR frame; writer continues.', '// Live frame selection; freeze_request tied low in Project1.')
    top.write_text(text, encoding='utf-8')

ns = 'http://www.efinixinc.com/enf_proj'
ET.register_namespace('efx', ns)
ET.register_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')
base_xml = ROOT.parent.parent / '2026.9.27/Ti60_Sobel_Gesture_Demo/Ti60_Demo.xml'
project = ET.parse(base_xml)
design = project.find(f'{{{ns}}}design_info')
keep = {'src/vision/rgb565_to_rgb888.v', 'src/vision/line_buffer_3x3.v',
        'src/parallel/video_delay.v', 'src/hand/hand_font.v'}
for node in list(design):
    if node.tag == f'{{{ns}}}design_file':
        name = node.get('name')
        algorithm = any(name.startswith('src/' + group + '/') for group in
                        ['gesture','background','hand','vision','parallel','face','project1'])
        if algorithm and name not in keep:
            design.remove(node)
for path in sorted((ROOT / 'src/project1').glob('*.v')):
    node=ET.Element(f'{{{ns}}}design_file', name=path.relative_to(ROOT).as_posix(),
                    version='default', library='default')
    design.insert(list(design).index(design.find(f'{{{ns}}}top_vhdl_arch')),node)
project.getroot().set('description', 'Project1 full Ti60 port: eight video modes and original three-class rule')
ET.indent(project,space='    ')
project.write(ROOT / 'Ti60_Demo.xml', encoding='utf-8', xml_declaration=False)
for node in design.findall(f'{{{ns}}}design_file'):
    assert (ROOT / node.get('name')).is_file(), node.get('name')
print('Prepared independent Ti60 project; all design sources present.')
