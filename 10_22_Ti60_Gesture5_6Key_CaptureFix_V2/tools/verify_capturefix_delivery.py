"""Compatibility entry: current audit acceptance is read-only by default.
Historical implementation is retained in reports/capture_review/tools_historical.
"""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
import verify_capture_review
if __name__=='__main__':
 if len(sys.argv)==1:
  sys.argv+=['--evidence',str(Path(__file__).resolve().parents[1]/'reports/capture_review/selected_evidence.json')]
 print('Current acceptance: verify_capture_review; no historical reports will be overwritten.')
 try:verify_capture_review.main()
 except Exception as e:print('FAIL:',str(e),file=sys.stderr);raise SystemExit(1)
