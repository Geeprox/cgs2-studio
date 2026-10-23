# SPDX-License-Identifier: MIT
"""Execute emitted hooks, stop at original continuations and real Qt boundaries."""
import json,struct,sys
from pathlib import Path

from unicorn import Uc,UC_ARCH_ARM64,UC_MODE_ARM,UC_HOOK_CODE
from unicorn.arm64_const import *
B=Path(__file__).resolve().parents[1]/'.local/build-native/idle-dim';M=json.loads((B/'manifest.json').read_text());data=(B/'QingSnow2App').read_bytes()
u=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
for addr,size in [(0x400000,0x4b0000),(0x100000,0x4000),(0x200000,0x4000),(0x300000,0x1000)]:u.mem_map(addr,size)
u.mem_write(0x400000,data[:0x452338]);STATE=M['state_address'];CTX=0x100000;API=0x101000;MANAGER=0x102000;SP=0x201000;DONE=0x300000
stops={0x59b140,0x60b4dc,0x59e6dc,0x59a634,0x59a80c,DONE};last=[]
def stop(uc,pc,size,_):
 if pc in stops:last.append(pc);uc.emu_stop()
u.hook_add(UC_HOOK_CODE,stop)
def write(p,n):u.mem_write(p,struct.pack('<I',n&0xffffffff))
def invoke(name,x0=CTX,v=0):
 last.clear();u.reg_write(UC_ARM64_REG_X0,x0);u.reg_write(UC_ARM64_REG_W1,v&0xffffffff);u.reg_write(UC_ARM64_REG_SP,SP);u.reg_write(UC_ARM64_REG_X30,DONE)
 for r in range(19,30):u.reg_write(UC_ARM64_REG_X0+r,0x1000+r)
 u.emu_start(M['stub_address']+M['symbols'][name],DONE,count=100)
 assert len(last)==1 and u.reg_read(UC_ARM64_REG_SP)==SP
 for r in range(19,30):assert u.reg_read(UC_ARM64_REG_X0+r)==0x1000+r
 return last[0],u.reg_read(UC_ARM64_REG_W1)
checks=0
for dim in [0,1]:
 u.mem_write(STATE,bytes([dim]));u.mem_write(API+0x48,b'\x01')
 for value in range(1001):
  pc,out=invoke('writer',API,value);assert pc==0x59a634 and out==(min(value,max(80,min(200,value//4)))if dim else value);checks+=1
for val in [0,20,80,573,1000,-999,-1002]:
 write(CTX+0x14,573);u.mem_write(CTX+0x74,b'\x01')
 assert invoke('manager',v=val)==(0x59b140,val&0xffffffff);assert invoke('runner',v=val)==(0x59e6dc,val&0xffffffff);checks+=2
u.mem_write(CTX+0x10,struct.pack('<Q',API));write(API+0x38,573)
for val,dim in [(-1001,1),(-1000,0),(-1001,1),(-1000,0)]:
 write(MANAGER+0x14,573)
 assert invoke('manager',MANAGER,val)==(0x60b4dc,val&0xffffffff)
 assert struct.unpack('<I',u.mem_read(MANAGER+0x14,4))[0]==573
 assert invoke('runner',v=val)==(0x59a634,143 if dim else 573)
 assert u.mem_read(STATE,1)==bytes([dim]) and struct.unpack('<I',u.mem_read(API+0x38,4))[0]==573;checks+=4
u.mem_write(STATE,b'\x01');assert invoke('wake',API,573)==(0x59a80c,573) and u.mem_read(STATE,1)==b'\x00';checks+=1
result={'passed':True,'checks':checks,'allBacklightLevels':1001,'automaticAndManualTargetsUnchanged':True,'storedValueUnchangedForCommands':True,'zeroPreserved':True,'wakeClearsCap':True,'calleeSavedRegistersPreserved':True,'realQtAndDeviceTested':False}
(B/'native-tests.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
