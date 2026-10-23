# SPDX-License-Identifier: MIT
"""Small deterministic static ELF packer for this freestanding single object.
Rejects every undefined symbol or unsupported relocation; no executable input.
"""
import argparse,struct,json,hashlib,sys
if not __debug__:raise SystemExit("Run without Python -O")
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args();b=args.input.read_bytes();h=struct.unpack_from('<16sHHIQQQIHHHHHH',b);assert h[2]==183
sections=[struct.unpack_from('<IIQQQQIIQQ',b,h[6]+i*h[11])for i in range(h[12])]
def align(n,a):return (n+a-1)//a*a
addresses={};out=bytearray(4096);regions=[]
for mask,flags in [(4,5),(0,4)]:
 start=align(len(out),4096);out.extend(bytes(start-len(out)))
 for i,s in enumerate(sections):
  if not s[2]&2 or (s[2]&4)!=mask:continue
  assert not s[2]&1 and s[1]!=8,'Unexpected writable allocation'
  off=align(len(out),max(1,s[8]));out.extend(bytes(off-len(out)));addresses[i]=0x400000+off;out.extend(b[s[4]:s[4]+s[5]])
 regions.append((start,len(out)-start,flags))
symbols={};names={}
for i,s in enumerate(sections):
 if s[1]!=2:continue
 st=sections[s[6]];strings=b[st[4]:st[4]+st[5]]
 for j in range(0,s[5],24):
  name,info,other,section,value,size=struct.unpack_from('<IBBHQQ',b,s[4]+j);n=strings[name:strings.index(b'\0',name)].decode()
  if section==0:assert j==0,'Undefined symbol: '+n;address=0
  elif section==0xfff1:address=value
  else:address=addresses.get(section,0)+value
  symbols[j//24]=address
  if n:names[n]=address
for s in sections:
 if s[1]!=4 or s[7]not in addresses:continue
 for j in range(0,s[5],24):
  offset,info,addend=struct.unpack_from('<QQq',b,s[4]+j);kind=info&0xffffffff;target=symbols[info>>32]+addend;pc=addresses[s[7]]+offset;o=pc-0x400000;word=struct.unpack_from('<I',out,o)[0]
  if kind==275:
   imm=((target&~4095)-(pc&~4095))//4096;assert -(1<<20)<=imm<1<<20;word=(word&~0x60ffffe0)|((imm&3)<<29)|(((imm>>2)&0x7ffff)<<5)
  elif kind==277:word=(word&~0x3ffc00)|((target&4095)<<10)
  elif kind in (278,284,285,286,299):
   scale={278:0,284:1,285:2,286:3,299:4}[kind];assert target%(1<<scale)==0;word=(word&~0x3ffc00)|(((target&4095)>>scale)<<10)
  elif kind==257:struct.pack_into('<Q',out,o,target);continue
  elif kind in (282,283):
   delta=target-pc;assert delta%4==0 and -(1<<27)<=delta<1<<27;word=(word&0xfc000000)|((delta//4)&0x3ffffff)
  else:raise AssertionError('Unsupported relocation '+str(kind))
  struct.pack_into('<I',out,o,word)
ident=b'\x7fELF\x02\x01\x01'+bytes(9);struct.pack_into('<16sHHIQQQIHHHHHH',out,0,ident,2,183,1,names['_start'],64,0,0,64,56,len(regions),0,0,0)
for i,(off,size,flags)in enumerate(regions):struct.pack_into('<II6Q',out,64+i*56,1,flags,off,0x400000+off,0x400000+off,size,size,4096)
args.output.write_bytes(out);args.output.chmod(0o755)
print(json.dumps({'bytes':len(out),'sha256':hashlib.sha256(out).hexdigest(),'entry':hex(names['_start']),'undefinedSymbols':0,'regions':regions}))
