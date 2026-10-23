#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Strict, reversible local candidate; never connects to or installs on a device."""
import argparse, hashlib, json, struct, subprocess
from pathlib import Path
import sys,shutil
if not __debug__:raise SystemExit("Run without Python -O; safety checks must remain enabled")

BASE = Path(__file__).resolve().parent
EXPECTED = '4b0021977341d85c9591990cc51c94c797ee343ed3a231b1f72f31bcf9840b90'
ENTRY = 0x5222c8
STUB_OFFSET = 0x451a30
STUB_VA = 0x851a30
FLAG_VA = 0x8aa6c8

def sha(data): return hashlib.sha256(data).hexdigest()
def branch(pc, dest, link=False):
    delta = dest-pc
    assert delta % 4 == 0 and -(1<<27) <= delta < (1<<27)
    return struct.pack('<I', (0x94000000 if link else 0x14000000) | ((delta//4)&0x3ffffff))
def sections(data):
    h=struct.unpack_from('<16sHHIQQQIHHHHHH',data)
    ss=[struct.unpack_from('<IIQQQQIIQQ',data,h[6]+i*h[11])for i in range(h[12])]
    s=ss[h[13]]; names=data[s[4]:s[4]+s[5]]
    return {names[s[0]:names.index(b'\0',s[0])].decode():(s,data[s[4]:s[4]+s[5]])for s in ss}
def build(args):
    src=args.input.read_bytes()
    assert sha(src)==EXPECTED, 'Refuse unknown firmware: prior Wi-Fi/QML/brightness patches must match exactly'
    h=struct.unpack_from('<16sHHIQQQIHHHHHH',src)
    assert h[0][:6]==b'\x7fELF\x02\x01' and h[2]==183
    ph=[list(struct.unpack_from('<II6Q',src,h[5]+i*h[9]))for i in range(h[10])]
    assert ph[2]==[1,5,0,0x400000,0x400000,0x451a26,0x451a26,0x10000]
    assert ph[3]==[1,6,0x452338,0x862338,0x862338,0x11b54,0x48390,0x10000]
    assert ph[3][3]+ph[3][6]==FLAG_VA
    assert src[ENTRY-0x400000:ENTRY-0x400000+4]==bytes.fromhex('fd7bbea9')
    args.output.mkdir(parents=True,exist_ok=True)
    obj=args.output/'touch-wake.o'
    subprocess.run([(shutil.which('clang') or 'clang'),'-target','aarch64-linux-gnu','-c',str(BASE/'touch-wake.S'),'-o',str(obj)],check=True)
    ss=sections(obj.read_bytes()); code=bytearray(ss['.text.wake'][1]); symbols={}
    sy,st=ss['.symtab'][1],ss['.strtab'][1]
    for i in range(0,len(sy),24):
        n,_,_,_,v,_=struct.unpack_from('<IBBHQQ',sy,i)
        if n:symbols[st[n:st.index(b'\0',n)].decode()]=v
    assert 0 < len(code) < 1024
    for name,dest in [('call_manager',0x59ca38),('call_wake',0x59b6ac),('call_touched',0x5f3590),('call_timer',0x417210)]:
        i=symbols[name];code[i:i+4]=branch(STUB_VA+i,dest,True)
    for name in ['flag_read','flag_clear','flag_set']:
        i=symbols[name];pc=STUB_VA+i;delta=(FLAG_VA&~0xfff)-(pc&~0xfff);imm=delta//4096
        assert -(1<<20)<=imm<(1<<20)
        adrp=0x90000009|((imm&3)<<29)|(((imm>>2)&0x7ffff)<<5)
        add=0x91000129|((FLAG_VA&0xfff)<<10)
        code[i:i+8]=struct.pack('<II',adrp,add)
    end=STUB_OFFSET+len(code)
    assert end < ph[3][2]
    assert src[STUB_OFFSET:end]==bytes(len(code)), 'Cave is not empty file padding'
    for s,_ in sections(src).values():
        if s[1]!=8 and s[5]:assert end<=s[4] or STUB_OFFSET>=s[4]+s[5], 'Padding overlaps a real ELF section'
    ph[2][5]=ph[2][6]=end
    ph[3][6]+=8  # Own a zero-filled byte after existing BSS; all prior BSS intact.
    patches=[(ENTRY-0x400000,branch(ENTRY,STUB_VA),'eventFilter entry'),
             (STUB_OFFSET,bytes(code),'new eventFilter in verified empty padding'),
             (h[5]+2*h[9]+32,struct.pack('<QQ',ph[2][5],ph[2][6]),'RX file and memory size'),
             (h[5]+3*h[9]+40,struct.pack('<Q',ph[3][6]),'RW zero-filled memory size')]
    out=bytearray(src);records=[]
    for off,new,why in patches:
        old=src[off:off+len(new)];out[off:off+len(new)]=new
        records.append(dict(offset=off,length=len(new),purpose=why,before_hex=old.hex(),after_hex=new.hex(),before_sha256=sha(old),after_sha256=sha(new)))
    allowed={i for p in records for i in range(p['offset'],p['offset']+p['length'])}
    changes=[i for i,(a,b) in enumerate(zip(src,out))if a!=b]
    assert len(src)==len(out) and set(changes)<=allowed
    manifest=dict(format='cgs2-touch-wake-candidate-v1',installed=False,source_sha256=sha(src),patched_sha256=sha(out),file_size=len(src),modified_bytes=len(changes),entry=hex(ENTRY),stub_address=hex(STUB_VA),stub_file_offset=STUB_OFFSET,stub_length=len(code),gesture_flag_address=hex(FLAG_VA),new_bss_bytes=8,patches=records,symbols=symbols)
    (args.output/'QingSnow2App.before').write_bytes(src)
    (args.output/'QingSnow2App').write_bytes(out)
    (args.output/'touch-wake.bin').write_bytes(code)
    (args.output/'patch-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:v for k,v in manifest.items()if k not in ['patches','symbols']},indent=2))
def rollback(args):
    m=json.loads(args.rollback.read_text());src=args.input.read_bytes();assert sha(src)==m['patched_sha256']
    out=bytearray(src)
    for r in m['patches']:
        o,n=r['offset'],r['length'];assert sha(src[o:o+n])==r['after_sha256'];out[o:o+n]=bytes.fromhex(r['before_hex'])
    assert sha(out)==EXPECTED==m['source_sha256']
    args.output.mkdir(parents=True,exist_ok=True);(args.output/'QingSnow2App').write_bytes(out)
    print(json.dumps({'restored_sha256':sha(out)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--rollback',type=Path)
    a=p.parse_args();rollback(a)if a.rollback else build(a)
