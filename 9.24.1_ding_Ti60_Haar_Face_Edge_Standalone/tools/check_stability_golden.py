from pathlib import Path
import subprocess,sys,re
P=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(P/'tools/generate_test.py')],check=True)
expected=int(re.search(r'SELF_EXPECTED=(\d+)',(P/'src/haar/haar_face_video.v').read_text())[1])
actual=int(re.search(r'SELF_EXPECTED_COUNT (\d+)',(P/'sim/self_expected_count.vh').read_text())[1])
assert actual==expected,(actual,expected)
print('Startup self-test golden verified:',actual)
