from pathlib import Path
import json
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'reports/board_feedback.md';s=f.read_text(encoding='utf-8');s+='\n- 重新下载后，用户明确确认“画面正常，显示 SELFP”。当前新版的摄像头显示与板上已知图计算自检已得到现场确认；首次检出时间、近距离检出和框内白色边缘待本次有效测试反馈。\n';f.write_text(s,encoding='utf-8')
f=P/'reports/build_manifest.json';r=json.loads(f.read_text(encoding='utf-8'));r['visual_acceptance']='After reconnect and same-bit reprogramming, user confirmed live video and SELFP. Waiting for valid acquisition-time, near-face and ROI-edge observations.';f.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
f=P/'reports/latency_comparison.json';r=json.loads(f.read_text(encoding='utf-8'));r['live_feedback']='Live video and SELFP confirmed after reconnection; acquisition time, near distance and ROI edges pending.';f.write_text(json.dumps(r,indent=2),encoding='utf-8')
f=P/'reports/model_audit.json';r=json.loads(f.read_text());r['audit_only_not_applied']=True;r['normalization_comparison']={'current_and_cornell':[0,0,24,24],'opencv_reference':[1,1,22,22]};r['stage_threshold_comparison']={'current_and_cornell':'0.4 * integer model threshold','opencv_reference':'original model threshold minus a small epsilon'};r['interpretation']='Behavioral differences found; not yet identified as the cause of this user\u0027s live issue, and no FPGA change has been made from this audit.';f.write_text(json.dumps(r,indent=2),encoding='utf-8')
print('Recorded confirmed live video and SELFP; model audit remains unapplied.')
