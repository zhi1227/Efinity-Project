from pathlib import Path
import json,hashlib
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'reports/board_feedback.md';s=f.read_text(encoding='utf-8');s+='''
## 断连后的重新下载与反馈澄清

- 用户先反馈“还是稍靠近就不出框”，随后明确说明“项目还没跑，刚刚板卡断连”。因此该回答暂不作为当前新版近距离检测效果的有效验证。
- 重新枚举到 FTDI 0403:6014，JTAG 确认单颗 Ti60，ID 0x10660A79。
- 已重新下载同一已验证位流 A9FDE5EBA56C534ABBCCDD7EEAC4E7D3181ECE271D3552574CAF066CA6B85D66，编程完成、退出码 0。本次没有继续更改检测逻辑或分类阈值。
- 当前先等待用户确认摄像头画面恢复及 SELFP，再评估实际距离与首次检测速度。
- 期间新增的 model/reference 官方模型文件和 reports/model_audit.json 仅用于来源比对；未用于生成或更改当前位流。
''';f.write_text(s,encoding='utf-8')
f=P/'reports/latency_comparison.json';r=json.loads(f.read_text(encoding='utf-8'));r['live_feedback']='Prior near-distance reply invalidated by user clarification of disconnected board; same bit reprogrammed, awaiting live display/self-test confirmation.';f.write_text(json.dumps(r,indent=2),encoding='utf-8')
m=json.loads((P/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((P/item['path']).read_bytes()).hexdigest()==item['sha256'] for item in m['files'])
print('Recorded clarification and same-bit reprogramming; verified implementation unchanged.')
