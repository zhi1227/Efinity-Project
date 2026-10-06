"""Project-local Efinity 2025.1 entry point. Never modifies installed tools.

The bundled JCF calls configure(url, init), but its optional D2XX JTAG engine
accepts configure(url) only. Adapt only the no-extra-GPIO-initialization case.
The underlying vendor scanner/programmer still performs all JTAG operations.
"""
import argparse,os,runpy,sys
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--action',choices=['scan','program'],required=True)
p.add_argument('--url',required=True)
p.add_argument('--bit')
a=p.parse_args()
pgm=Path(os.environ['EFXPGM_HOME'])/'bin'
dbg=Path(os.environ['EFXDBG_HOME'])/'bin'
sys.path.extend([str(pgm),str(dbg)])
if a.url.startswith('hiftdi://'):
 from efx_pgm.hiftdi.jtag import JtagEngine
 original_configure=JtagEngine.configure
 def configure_compatible(self,url,init=None):
  if init:
   raise RuntimeError('D2XX adapter refuses nonempty board GPIO initialization; inspect profile before use')
  return original_configure(self,url)
 JtagEngine.configure=configure_compatible
if a.action=='scan':
 script=pgm/'jtag_chain_detect.py';sys.argv=[str(script),'-f',a.url]
else:
 if not a.bit or not Path(a.bit).is_file():raise SystemExit('Existing timing-checked .bit required')
 script=pgm/'efx_pgm/ftdi_program.py'
 sys.argv=[str(script),'-m','jtag','-u',a.url,'--jtag_clock_freq','6000000',a.bit]
runpy.run_path(str(script),run_name='__main__')
