from pathlib import Path
import json,hashlib
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
status='User photo confirms live camera video, SELFP, one green face box and visible white Sobel edges in the face ROI. First-acquisition time and closer-distance behavior remain unmeasured.'
f=P/'reports/board_feedback.md';s=f.read_text(encoding='utf-8');s+='''
## 框内边缘现场照片确认

- 用户提供重新运行后的现场照片：codex-clipboard-1ca567aa-5f16-41e2-944c-e2b3fc793478.jpg。
- 可见绿色人脸框，框内眼镜、鼻梁、嘴唇及头发处有清楚的白色真实图像边缘；左上可辨 SELFP、R00、B1。由此确认当前位流的人脸框与框内 Sobel 边缘显示链路已实际工作。
- R00/B1 在短时保持机制下是允许的状态，照片不能证明拍摄时每一轮都检出了人脸。
- 此单张照片不能测出首次等待时间，也不能证明更近距离仍稳定；这两项保持待反馈。
- 该照片只在本地会话中用于观察，未上传到外部服务、未复制进工程源码。
''';f.write_text(s,encoding='utf-8')
f=P/'reports/build_manifest.json';m=json.loads(f.read_text(encoding='utf-8'));m['visual_acceptance']=status;f.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
f=P/'reports/latency_comparison.json';r=json.loads(f.read_text(encoding='utf-8'));r['live_feedback']=status;r['roi_edges_visual']='confirmed by user photo';f.write_text(json.dumps(r,indent=2),encoding='utf-8')
f=P/'README.md';s=f.read_text(encoding='utf-8');s=s.replace('首次出框与近距离现场效果待确认','现场照片已确认人脸框和框内白色边缘，首次出框速度与更近距离效果仍待确认')
s=s.replace('本次首次响应、近距离效果、框内边缘以及长时间稳定性还需现场反馈。','本次框内白色边缘已由现场照片确认；首次响应、更近距离效果以及长时间稳定性仍待现场反馈。');f.write_text(s,encoding='utf-8')
assert all(hashlib.sha256((P/item['path']).read_bytes()).hexdigest()==item['sha256'] for item in m['files'])
print('Recorded visual face-box and ROI-edge confirmation; programmed design unchanged.')
