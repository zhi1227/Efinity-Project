from pathlib import Path
P=Path(r'D:\yilingsi_fpga\Efinity_Project\2026.9.24\Ti60_Haar_Face_Edge_Standalone')
f=P/'src/haar/haar_face_video.v';s=f.read_text();s=s.replace("capture_phase<=test_done?next_phase:2'b00;", "capture_phase<=test_done?((hd&&!test_capture)?next_phase+2'd1:next_phase):2'b00;");f.write_text(s)
# Keep all regression inputs in the verified manifest and do not reuse prior visual acceptance for a new bit.
f=P/'tools/record_verified_build.py';s=f.read_text();s=s.replace("bit=(P/'outflow/Ti60_Demo.bit').stat().st_mtime", "paths.update(f for f in (P/'sim').glob('*') if f.suffix in ('.mem','.vh'))\nbit=(P/'outflow/Ti60_Demo.bit').stat().st_mtime")
s=s.replace('User confirmed on board: face boxes are noticeably stable and disappear after leaving. White edges inside the face region await separate visual confirmation.', 'Latency and near-face revision: awaiting on-board confirmation; prior image had stable boxes but slow acquisition.')
f.write_text(s)
print('Protected scan phase at coincident completion/capture; regression fixtures included in manifest.')
