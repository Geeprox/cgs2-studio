#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Patch only pinned ScreenAPI native ranges, preserving all other CGS2 edits."""
import argparse, hashlib, json, struct, subprocess
from pathlib import Path
import sys,shutil
if not __debug__:raise SystemExit("Run without Python -O; safety checks must remain enabled")
BASE=Path(__file__).resolve().parent
PINNED={
0x599dc0:(204,'b20895313fa1884f81d0a02eee11fac4368663ce6e022d66d984035d85293413'),
0x59a760:(112,'329b4b04c54cc051a544d1a5a0486da5db2a799c7f52b22436af0d1a30a59143'),
0x59a048:(4,'69626f521aa6d0a830f21c6b76bf78a10ac69f16621407189627bd2a0e2a829a'),
0x59a050:(4,'0be7e87f91ef9a900b455afc45ffd5a85f97266d95e0ebc980f94737129a4cf9')}
KNOWN={'1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac',
'5892cbc1e82ff70c1282219a805b1747d54893004998b5527e872b24f7b60309'}
def sha(b): return hashlib.sha256(b).hexdigest()
def header(b):
 h=struct.unpack_from('<16sHHIQQQIHHHHHH',b)
 assert h[0][:6]==b'\x7fELF\x02\x01' and h[2]==183,'Expected little-endian ELF64 AArch64'
 return h
def offset(b,addr,n):
 h=header(b)
 for i in range(h[10]):
  p=struct.unpack_from('<IIQQQQQQ',b,h[5]+i*h[9])
  if p[0]==1 and p[3]<=addr and addr+n<=p[3]+p[5]:
   assert p[1]&1,'Target range is not executable'
   return p[2]+addr-p[3]
 raise ValueError('Address has no complete file-backed PT_LOAD mapping')
def obj_sections(b):
 h=header(b); raw=[struct.unpack_from('<IIQQQQIIQQ',b,h[6]+i*h[11]) for i in range(h[12])]
 s=raw[h[13]]; names=b[s[4]:s[4]+s[5]]
 name=lambda o:names[o:names.index(b'\0',o)].decode()
 return {name(s[0]):(s,b[s[4]:s[4]+s[5]]) for s in raw}
def branch(pc,dest,link=False):
 d=dest-pc; assert d%4==0 and -(1<<27)<=d<(1<<27)
 return struct.pack('<I',(0x94000000 if link else 0x14000000)|((d//4)&0x3ffffff))
def build(args):
 src=args.input.read_bytes(); source_sha=sha(src)
 assert source_sha in KNOWN or source_sha==args.expected_sha,'Unrecognized input SHA; select explicit --expected-sha after inspection'
 args.output.mkdir(parents=True,exist_ok=True)
 obj=args.output/'auto-brightness.o'
 subprocess.run([args.clang,'-target','aarch64-linux-gnu','-c',str(BASE/'auto-brightness.S'),'-o',str(obj)],check=True)
 sections=obj_sections(obj.read_bytes())
 sy,st=sections['.symtab'][1],sections['.strtab'][1]
 sym={}
 for i in range(0,len(sy),24):
  n,_,_,_,v,_=struct.unpack_from('<IBBHQQ',sy,i)
  if n: sym[st[n:st.index(b'\0',n)].decode()]=v
 curve=sections['.text.curve'][1]; adjust=bytearray(sections['.text.adjust'][1])
 assert len(curve)<=204 and len(adjust)==112
 for name,target,link in [('call_stop',0x4168a0,True),('call_signal',0x60af70,True),('call_write',0x59a630,False)]:
  o=sym[name]; adjust[o:o+4]=branch(0x59a760+o,target,link)
 patches={0x599dc0:curve+b'\x1f\x20\x03\xd5'*((204-len(curve))//4),
          0x59a760:bytes(adjust),0x59a048:struct.pack('<I',0x910143e1),
          0x59a050:branch(0x59a050,0x599dc0+sym['sensor_store'],True)}
 out=bytearray(src); records=[]
 for addr,new in sorted(patches.items()):
  n,expected=PINNED[addr]; o=offset(src,addr,n); old=src[o:o+n]
  assert len(new)==n and sha(old)==expected,f'Native original bytes differ at {addr:#x}'
  out[o:o+n]=new
  records.append({'address':hex(addr),'offset':o,'length':n,'before_sha256':sha(old),'after_sha256':sha(new),'before_hex':old.hex(),'after_hex':new.hex()})
 changed={i for i,(a,b) in enumerate(zip(src,out)) if a!=b}
 allowed={i for r in records for i in range(r['offset'],r['offset']+r['length'])}
 assert len(out)==len(src) and changed<=allowed
 manifest={'format':'cgs2-native-brightness-v1','source_sha256':source_sha,'patched_sha256':sha(out),
 'file_size':len(src),'modified_bytes':len(changed),'patches':records,
 'curve_lux_brightness':[[0,80],[3,100],[10,180],[50,520],[300,800],[900,950],[1500,1000]],
 'target_hysteresis':20,'factory_sample_ms':1000,'factory_filter_samples':10,'factory_stop_deadband':9,
 'ramp_interval_ms':30,'ramp_up_step':12,'ramp_down_step':3,'sensor_store_offset_in_curve':sym['sensor_store'],
 'manual_and_screen_off_ranges_unchanged':True,'all_other_bytes_unchanged':True}
 (args.output/'QingSnow2App.before').write_bytes(src)
 (args.output/'QingSnow2App').write_bytes(out)
 (args.output/'patch-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({k:v for k,v in manifest.items() if k!='patches'},indent=2))
def rollback(args):
 manifest=json.loads(args.rollback.read_text()); src=args.input.read_bytes()
 assert sha(src)==manifest['patched_sha256'],'Refuse to reverse an unknown binary'
 out=bytearray(src)
 for r in manifest['patches']:
  o,n=r['offset'],r['length']; assert sha(src[o:o+n])==r['after_sha256']
  out[o:o+n]=bytes.fromhex(r['before_hex'])
 assert sha(out)==manifest['source_sha256']
 args.output.mkdir(parents=True,exist_ok=True); (args.output/'QingSnow2App').write_bytes(out)
 print(json.dumps({'restored_sha256':sha(out)}))
if __name__=='__main__':
 p=argparse.ArgumentParser(); p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--expected-sha');p.add_argument('--clang',default=(shutil.which('clang') or 'clang'));p.add_argument('--rollback',type=Path)
 a=p.parse_args(); rollback(a) if a.rollback else build(a)
