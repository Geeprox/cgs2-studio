#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Exercise emitted AArch64 bytes, with Qt calls stubbed at observed addresses."""
import hashlib, json, math, struct, sys, time
from pathlib import Path

from unicorn import Uc,UC_ARCH_ARM64,UC_MODE_ARM,UC_HOOK_CODE
from unicorn.arm64_const import *
BASE=Path(__file__).resolve().parents[1]
CAND=BASE/'.local/build-native/brightness'; new=(CAND/'QingSnow2App').read_bytes();old=(CAND/'QingSnow2App.before').read_bytes()
m=json.loads((CAND/'patch-manifest.json').read_text())
CURVE=0x599dc0; ADJUST=0x59a760; CTX=0x100000;STACK=0x200000;TIMER=0x300000;DONE=0x700000
uc=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
for address,size in [(0x400000,0x230000),(CTX,0x1000),(STACK,0x2000),(TIMER,0x1000),(DONE,0x1000)]:uc.mem_map(address,size)
uc.mem_write(0x400000,new[:0x230000]);uc.mem_write(0x4168a0,bytes.fromhex('c0035fd6'));uc.mem_write(0x60af70,bytes.fromhex('c0035fd6'));uc.mem_write(0x59a630,bytes.fromhex('c0035fd6'))
state={};calls=0

def on_code(u,pc,size,user):
 global calls
 if pc in (0x4168a0,0x60af70,0x59a630):
  state.setdefault('events',[]).append((pc,u.reg_read(UC_ARM64_REG_X0),u.reg_read(UC_ARM64_REG_W1)))
  for reg in [UC_ARM64_REG_X0,UC_ARM64_REG_X1,UC_ARM64_REG_X2,UC_ARM64_REG_X3,UC_ARM64_REG_X4,UC_ARM64_REG_X5,UC_ARM64_REG_X6,UC_ARM64_REG_X7,UC_ARM64_REG_X8,UC_ARM64_REG_X9,UC_ARM64_REG_X10,UC_ARM64_REG_X11,UC_ARM64_REG_X12,UC_ARM64_REG_X13,UC_ARM64_REG_X14,UC_ARM64_REG_X15,UC_ARM64_REG_X16,UC_ARM64_REG_X17,UC_ARM64_REG_X18]:u.reg_write(reg,0xdeadbeef)
uc.hook_add(UC_HOOK_CODE,on_code,begin=0x4168a0,end=0x60af70)

def w(off,val):uc.mem_write(CTX+off,struct.pack('<I',val&0xffffffff))
def r(off):return struct.unpack('<I',uc.mem_read(CTX+off,4))[0]
def invoke(pc,x0=CTX,w1=0):
 global calls
 uc.reg_write(UC_ARM64_REG_X0,x0);uc.reg_write(UC_ARM64_REG_W1,w1&0xffffffff)
 uc.reg_write(UC_ARM64_REG_SP,STACK+0x1000);uc.reg_write(UC_ARM64_REG_X30,DONE)
 uc.reg_write(UC_ARM64_REG_X19,0x19191919);uc.reg_write(UC_ARM64_REG_X29,0x29292929)
 uc.emu_start(pc,DONE,count=2000);calls+=1
 assert uc.reg_read(UC_ARM64_REG_PC)==DONE,hex(uc.reg_read(UC_ARM64_REG_PC))
 assert uc.reg_read(UC_ARM64_REG_SP)==STACK+0x1000
 assert uc.reg_read(UC_ARM64_REG_X19)==0x19191919
 assert uc.reg_read(UC_ARM64_REG_X29)==0x29292929
 return uc.reg_read(UC_ARM64_REG_W0)
def curve(lux,previous=0):w(0x3c,previous);return invoke(CURVE,w1=lux)
start=time.monotonic(); checks=0
new_curve=[]
for lux in range(0,2001):
 v=curve(lux); assert 80<=v<=1000
 if new_curve:assert v>=new_curve[-1]
 new_curve.append(v);checks+=1
for lux in (2147483647,1501,1000000):assert curve(lux)==1000;checks+=1
samples=[0,1,3,4,10,25,50,65,100,300,900,1500,2000]; table=[]
new_curve_bytes=bytes(uc.mem_read(CURVE,204));uc.mem_write(CURVE,old[0x199dc0:0x199dc0+204]);uc.ctl_remove_cache(CURVE,CURVE+204)
for lux,v in enumerate(new_curve):
 factory=invoke(CURVE,w1=lux);assert v>=factory,(lux,v,factory);checks+=1
 if lux in samples:table.append({'lux':lux,'factory':factory,'new':v})
uc.mem_write(CURVE,new_curve_bytes);uc.ctl_remove_cache(CURVE,CURVE+204)
for lux in range(0,1501,3):
 target=new_curve[lux]
 for previous in (80,100,180,300,520,536,800,950,1000,target-21,target-20,target,target+20,target+21):
  if not 80<=previous<=1000:continue
  actual=curve(lux,previous)
  assert actual==(previous if abs(target-previous)<=20 else target),(lux,previous,actual,target)
  checks+=1
for lux in (-1,-20,-2147483648):assert curve(lux,536)==536;checks+=1
# The new sensor-store helper must distinguish valid 0 from invalid/negative.
helper=CURVE+m['sensor_store_offset_in_curve']
for raw,ok,expected in [(0,1,0),(65,1,65),(2147483647,1,2147483647),(0,0,536),(65,0,536),(-1,1,536),(-1,0,536)]:
 w(0x40,536);uc.mem_write(STACK+0x1050,bytes([ok]));uc.reg_write(UC_ARM64_REG_X25,CTX)
 invoke(helper,x0=raw);assert r(0x40)==expected,(raw,ok,r(0x40));checks+=1
# Failed opens skip helper altogether: untouched factory path retains previous lux.
assert new[0x199f40:0x199f54]==old[0x199f40:0x199f54]
# Manual, screen-on/off, auto enable/disable and all factory filtering remain exact.
for lo,hi in [(0x599d78,0x599dc0),(0x59a1ac,0x59a630),(0x59a7d0,0x59a83c)]:
 assert new[lo-0x400000:hi-0x400000]==old[lo-0x400000:hi-0x400000];checks+=1
uc.mem_write(CTX+0x20,struct.pack('<Q',TIMER))
# Every one-step difference is checked in both directions. Qt stop/signal/write
# invocations and stack/callee-saved restoration are checked as emitted code.
for current in (20,80,100,180,500,536,800,950,1000):
 for target in range(20,1001):
  w(0x38,current);w(0x3c,target);state['events']=[];invoke(ADJUST)
  step=12 if target>current else 3
  expected=target if abs(target-current)<=step else current+(step if target>current else -step)
  assert r(0x38)==expected,(current,target,r(0x38),expected)
  events=state['events'];assert [e[0] for e in events[-2:]]==[0x60af70,0x59a630]
  assert all(e[1:]==(CTX,expected) for e in events[-2:])
  assert (len(events)==3)==(abs(target-current)<=step)
  if len(events)==3:assert events[0][1]==TIMER
  checks+=1
cycles=[]
for current,target in [(80,1000),(1000,80),(20,1000),(1000,20),(536,536),(80,81),(81,80)]:
 w(0x38,current);w(0x3c,target);prior=current;steps=0
 while True:
  state['events']=[];invoke(ADJUST);after=r(0x38);steps+=1
  assert min(current,target)<=after<=max(current,target)
  assert (after>=prior) if target>=current else (after<=prior)
  if after==target:break
  assert steps<=math.ceil(abs(target-current)/(12 if target>current else 3))+1
  prior=after
 cycles.append({'from':current,'to':target,'ticks':steps,'ramp_ms':steps*30})
# All other file bytes remain exactly the prior customized firmware.
allowed={i for p in m['patches'] for i in range(p['offset'],p['offset']+p['length'])}
assert len(new)==len(old) and all(a==b or i in allowed for i,(a,b) in enumerate(zip(old,new)))
result={'passed':True,'aarch64_emulator':'Unicorn 2.1.4','checks':checks,'machine_code_calls':calls,'seconds':round(time.monotonic()-start,2),'curve_samples':table,'ramp_cycles':cycles,'bounds':[80,1000],'target_hysteresis':20,'runtime_qt_calls_stubbed':True,'real_device_curve_acceptance':False}
(BASE/'.local/brightness-test-results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
