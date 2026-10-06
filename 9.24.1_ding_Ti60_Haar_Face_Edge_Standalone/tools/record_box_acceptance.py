from pathlib import Path
import json,hashlib
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
status='User confirmed on board: face boxes are noticeably stable and disappear after leaving. White edges inside the face region await separate visual confirmation.'
f=P/'reports/build_manifest.json';m=json.loads(f.read_text(encoding='utf-8'));m['visual_acceptance']=status;f.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
f=P/'tools/record_verified_build.py';s=f.read_text();s=s.replace('Previous diagnostic: unobstructed frontal face detected on board, but boxes flicker. Stability revision awaits live confirmation.',status);f.write_text(s)
f=P/'reports/board_feedback.md';s=f.read_text();s+='\n## 本次稳定性现场确认\n\n用户反馈：“框明显稳定，离开后会消失”。因此绿色框连续性与自动清除已得到现场确认。框内白色边缘仍待第二项观察反馈；尚不将整个轮廓显示效果标记为验收完成。\n';f.write_text(s,encoding='utf-8')
f=P/'README.md';s=f.read_text();s=s.replace('等待此次修订的现场确认','用户已确认“框明显稳定，离开后会消失”；框内白色边缘待单独确认')
s=s.replace('稳定性修订的实际改善、框内边缘效果、不同人脸/背景泛化及长时间稳定性还需现场反馈。','稳定性修订已由用户确认框明显稳定且离开后会消失；框内边缘效果、不同人脸/背景泛化及长时间稳定性还需现场反馈。');f.write_text(s,encoding='utf-8')
assert all(hashlib.sha256((P/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in m['files'])
print('Recorded field acceptance of stable boxes and removal; programmed image still matches manifest.')
