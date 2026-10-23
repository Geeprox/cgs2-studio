# SPDX-License-Identifier: MIT
"""Pinned native candidate. Does not access the device."""
import argparse,hashlib,json,struct,subprocess,sys,shutil
if not __debug__:raise SystemExit("Run without Python -O; safety checks must remain enabled")
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
from importlib.machinery import SourceFileLoader
tools=SourceFileLoader('wake_build',str(BASE/'touch_wake.py')).load_module()
parser=argparse.ArgumentParser();parser.add_argument('--input',required=True,type=Path);parser.add_argument('--output',required=True,type=Path);args=parser.parse_args()
if args.output.exists():parser.error('Output directory must not exist')
src=args.input.read_bytes()
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(src)=='58a63e428af346b410319d4f61c74be642ac6e35f3a0dff47d3f9542934ae0e0'
outdir=args.output;outdir.mkdir(parents=True)
subprocess.run([(shutil.which('clang') or 'clang'),'-target','aarch64-linux-gnu','-c',str(BASE/'idle-dim.S'),'-o',str(outdir/'idle-dim.o')],check=True)
ss=tools.sections((outdir/'idle-dim.o').read_bytes());code=bytearray(ss['.text.dim'][1]);sy,st=ss['.symtab'][1],ss['.strtab'][1];symbols={}
for i in range(0,len(sy),24):
 n,_,_,_,v,_=struct.unpack_from('<IBBHQQ',sy,i)
 if n:symbols[st[n:st.index(b'\0',n)].decode()]=v
VA=0x851b80;OFF=VA-0x400000;STATE=0x8aa6d0
for n,d in {'manager_continue':0x59b140,'manager_signal':0x60b4dc,'runner_continue':0x59e6dc,'runner_write':0x59a630,'writer_continue':0x59a634,'wake_continue':0x59a80c}.items():
 i=symbols[n];code[i:i+4]=tools.branch(VA+i,d)
for n in ['state_runner','state_writer','state_wake']:
 i=symbols[n];imm=((STATE&~4095)-((VA+i)&~4095))//4096
 code[i:i+8]=struct.pack('<II',0x90000009|((imm&3)<<29)|(((imm>>2)&0x7ffff)<<5),0x91000129|((STATE&4095)<<10))
h=struct.unpack_from('<16sHHIQQQIHHHHHH',src);ph=[list(struct.unpack_from('<II6Q',src,h[5]+i*h[9]))for i in range(h[10])]
assert ph[3][3]+ph[3][6]==STATE
assert OFF>=ph[2][5] and OFF+len(code)<ph[3][2] and src[OFF:OFF+len(code)]==bytes(len(code))
for s,_ in tools.sections(src).values():
 if s[1]!=8 and s[5]:assert OFF+len(code)<=s[4] or OFF>=s[4]+s[5]
patches=[(OFF,bytes(code),'transient backlight cap in unused ELF padding'),(h[5]+2*h[9]+32,struct.pack('<QQ',OFF+len(code),OFF+len(code)),'extend existing RX mapping'),(h[5]+3*h[9]+40,struct.pack('<Q',ph[3][6]+8),'own eight zero-filled state bytes')]
for address,name,expected in [(0x59b13c,'manager','021440b9'),(0x59e6d8,'runner','03d04139'),(0x59a630,'writer','00204139'),(0x59a808,'wake','22008052')]:
 off=address-0x400000;assert src[off:off+4].hex()==expected
 patches.append((off,tools.branch(address,VA+symbols[name]),name+' entry'))
out=bytearray(src);records=[]
for o,b,why in patches:
 old=src[o:o+len(b)];out[o:o+len(b)]=b;records.append(dict(offset=o,length=len(b),purpose=why,before_hex=old.hex(),after_hex=b.hex()))
allowed={i for p in records for i in range(p['offset'],p['offset']+p['length'])};changed={i for i,(a,b)in enumerate(zip(src,out))if a!=b};assert len(src)==len(out) and changed<=allowed
manifest=dict(source_sha256=sha(src),patched_sha256=sha(out),file_size=len(out),modified_bytes=len(changed),stub_address=VA,state_address=STATE,symbols=symbols,patches=records)
(outdir/'QingSnow2App.before').write_bytes(src);(outdir/'QingSnow2App').write_bytes(out);(outdir/'idle-dim.bin').write_bytes(code);(outdir/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
reverse=bytearray(out)
for p in records:reverse[p['offset']:p['offset']+p['length']]=bytes.fromhex(p['before_hex'])
assert bytes(reverse)==src
print(json.dumps({k:v for k,v in manifest.items()if k not in ['patches','symbols']}))
