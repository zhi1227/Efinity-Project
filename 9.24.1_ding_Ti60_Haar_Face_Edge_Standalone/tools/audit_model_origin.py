from pathlib import Path
import urllib.request,xml.etree.ElementTree as ET,json,hashlib
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
R=P/'model/reference';R.mkdir(exist_ok=True)
url='https://raw.githubusercontent.com/opencv/opencv/4.x/data/haarcascades/haarcascade_frontalface_default.xml'
data=urllib.request.urlopen(url,timeout=30).read();(R/'haarcascade_frontalface_default.xml').write_bytes(data)
root=ET.fromstring(data).find('cascade');old=json.loads((P/'model/cascade.json').read_text())
features=root.find('features');nodes=[n for s in root.find('stages') for n in s.find('weakClassifiers')]
assert len(nodes)==2913 and len(root.find('stages'))==25
checks={}
checks['stage_count']=len(root.find('stages'))
checks['feature_geometry_matches']=all([int(v) for v in rect.text.split()[:4]]==[old[f'rectangles_array{4*r+j}'][i] for j in range(4)] for i,feat in enumerate(features) for r,rect in enumerate(feat.find('rects')))
checks['weights_match']=all(int(float(rect.text.split()[4])*4096)==old[f'weights_array{r}'][i] for i,feat in enumerate(features) for r,rect in enumerate(feat.find('rects')))
checks['node_threshold_match']=sum(int(float(n.find('internalNodes').text.split()[3])*4096)==old['tree_thresh_array'][i] for i,n in enumerate(nodes))
checks['leaf_match']=sum(int(float(n.find('leafValues').text.split()[j])*256)==old[f'alpha{j+1}_array'][i] for i,n in enumerate(nodes) for j in range(2))
checks['stage_threshold_match']=sum(int(float(n.find('stageThreshold').text)*256)==old['stages_thresh_array'][i] for i,n in enumerate(root.find('stages')))
checks['all_stage_thresholds_negative']=all(x<0 for x in old['stages_thresh_array'])
checks['xml_sha256']=hashlib.sha256(data).hexdigest();checks['source']=url
(P/'reports/model_audit.json').write_text(json.dumps(checks,indent=2),encoding='utf-8');print(json.dumps(checks,indent=2))
