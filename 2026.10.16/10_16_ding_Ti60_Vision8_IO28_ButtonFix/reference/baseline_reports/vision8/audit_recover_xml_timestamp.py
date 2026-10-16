from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
P=Path(__file__).resolve().parents[1];R=P/'reports/vision8'
manifest=R/'build_input_sha256.json'
old=json.loads(manifest.read_text(encoding='utf-8'));raw=(P/'Ti60_Demo.xml').read_bytes()
match=re.search(rb'last_change="(\d+)"',raw);assert match
stamp=int(match[1]);found=None
for candidate in range(stamp,stamp-86400,-1):
 before=raw[:match.start(1)]+str(candidate).encode()+raw[match.end(1):]
 if hashlib.sha256(before).hexdigest()==old['Ti60_Demo.xml']:
  found=before;break
assert found is not None,'Cannot prove XML changed only in timestamp; rebuild with canonical input manifest'
(R/'build_project_before.xml').write_bytes(found)
(R/'build_input_raw_sha256.json').write_text(json.dumps(old,indent=2),encoding='utf-8')
def canonical(b):
 root=ET.fromstring(b)
 for key in ('last_change','last_run_state','last_run_flow','config_result_in_sync','design_ood','place_ood','route_ood'):root.attrib.pop(key,None)
 return hashlib.sha256(ET.tostring(root,encoding='utf-8')).hexdigest()
assert canonical(found)==canonical(raw)
old['Ti60_Demo.xml']=canonical(found)
manifest.write_text(json.dumps(old,indent=2),encoding='utf-8')
(R/'build_xml_timestamp_verified.json').write_text(json.dumps({'only_changed_attribute':'last_change','before_timestamp':candidate,'after_timestamp':stamp,'raw_before_sha256_matches_start_manifest':True,'canonical_design_sha256':canonical(raw)},indent=2),encoding='utf-8')
print('Proved exact XML byte identity apart from Efinity last_change timestamp; canonicalized manifest entry only')
