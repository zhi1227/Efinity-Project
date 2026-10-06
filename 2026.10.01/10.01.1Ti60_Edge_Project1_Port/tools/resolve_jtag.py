"""Discover the connected FT232H using Efinity's own libusb/D2XX resolvers."""
import os,sys,json
from pathlib import Path
sys.path.extend([str(Path(os.environ['EFXPGM_HOME'])/'bin'),str(Path(os.environ['EFXDBG_HOME'])/'bin')])
from efx_pgm.usb_resolver import UsbResolver
devices=[d for d in UsbResolver(console=None,mixed_backend=True).get_usb_connections()
         if d.vendor_id==0x0403 and d.product_id==0x6014]
entries=[{'device':d.part_number,'urls':d.URLS,'description':d.description} for d in devices]
print(json.dumps(entries))
if len(devices)!=1 or len(devices[0].URLS)!=1 or not devices[0].URLS[0]:
 raise SystemExit('Expected exactly one connected FT232H JTAG interface')
if len(sys.argv)>1:Path(sys.argv[1]).write_text(devices[0].URLS[0],encoding='ascii')
