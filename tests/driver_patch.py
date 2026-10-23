# SPDX-License-Identifier: MIT
"""Offline checks for the exact candidate, including execution of real AArch64 thunks."""
from pathlib import Path
import io, json, struct, sys
BASE = Path(__file__).resolve().parents[1]/'.local/build-driver'

from elftools.elf.elffile import ELFFile
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import *
e = ELFFile(open(BASE / 'skw.ko', 'rb'))
syms = e.get_section_by_name('.symtab')
text = bytearray(e.get_section_by_name('.text').data())
manifest = json.loads((BASE / 'patch-manifest.json').read_text())
relocs = {r['r_offset']: syms.get_symbol(r['r_info_sym']).name
          for r in e.get_section_by_name('.rela.text').iter_relocations()}
assert relocs[0xfc68] == 'mutex_unlock'  # shared peer-context error path preserved
for off in [0xfb48, 0xfbdc, 0x3d24, 0x3e98, 0xfc4c, 0xfe80, 0xfea4]:
    assert off not in relocs
def target(off):
    word = struct.unpack_from('<I', text, off)[0]
    imm = word & 0x3ffffff
    if imm & 0x2000000: imm -= 0x4000000
    return off + imm * 4
assert target(0xfc60) == 0xfbd8
for off in [0xfb48, 0x3d24]: assert target(off) == int(manifest['helper_lock'], 16)
for off in [0xfbdc, 0x3e98]: assert target(off) == int(manifest['helper_unlock'], 16)
CODE = 0x100000
STOP = 0x200000
STACK = 0x300000
LOCK = 0x400000
UNLOCK = LOCK + 4
for r in e.get_section_by_name('.rela.text').iter_relocations():
    if r['r_offset'] < int(manifest['helper_lock'], 16): continue
    dst = LOCK if relocs[r['r_offset']] == 'mutex_lock' else UNLOCK
    delta = dst - (CODE + r['r_offset'])
    struct.pack_into('<I', text, r['r_offset'], 0x94000000 | ((delta >> 2) & 0x3ffffff))
checks = []
for core in [0x5008b0, 0x6008b0, 0x7008b0]:
    for kind in ['lock', 'unlock']:
        uc = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
        uc.mem_map(CODE, 0x30000); uc.mem_write(CODE, bytes(text))
        uc.mem_map(STOP, 0x1000); uc.mem_map(STACK, 0x10000); uc.mem_map(LOCK, 0x1000)
        ret = struct.pack('<I', 0xd65f03c0)
        uc.mem_write(LOCK, ret); uc.mem_write(UNLOCK, ret)
        sp = STACK + 0xf000
        uc.reg_write(UC_ARM64_REG_SP, sp)
        uc.reg_write(UC_ARM64_REG_X0, core)
        uc.reg_write(UC_ARM64_REG_X30, STOP)
        preserved = [UC_ARM64_REG_X19, UC_ARM64_REG_X20, UC_ARM64_REG_X21,
                     UC_ARM64_REG_X22, UC_ARM64_REG_X23, UC_ARM64_REG_X24,
                     UC_ARM64_REG_X25, UC_ARM64_REG_X26, UC_ARM64_REG_X27,
                     UC_ARM64_REG_X28, UC_ARM64_REG_X29]
        for idx, reg in enumerate(preserved): uc.reg_write(reg, 0x123400 + idx)
        calls = []
        def hook(uc, address, size, data):
            if address in [LOCK, UNLOCK]:
                calls.append(('lock' if address == LOCK else 'unlock', uc.reg_read(UC_ARM64_REG_X0)))
                # Model a legal C ABI callee that clobbers every caller-saved argument.
                for reg in [UC_ARM64_REG_X0, UC_ARM64_REG_X1, UC_ARM64_REG_X2,
                            UC_ARM64_REG_X3, UC_ARM64_REG_X4, UC_ARM64_REG_X5,
                            UC_ARM64_REG_X6, UC_ARM64_REG_X7, UC_ARM64_REG_X8]:
                    uc.reg_write(reg, 0xdeadbeef)
        uc.hook_add(UC_HOOK_CODE, hook)
        uc.emu_start(CODE + int(manifest['helper_' + kind], 16), STOP, count=100)
        expected = [(kind, core - 0x800), (kind, core)] if kind == 'lock' else [(kind, core), (kind, core - 0x800)]
        assert calls == expected, calls
        assert uc.reg_read(UC_ARM64_REG_SP) == sp
        assert uc.reg_read(UC_ARM64_REG_X30) == STOP
        for idx, reg in enumerate(preserved): assert uc.reg_read(reg) == 0x123400 + idx
        checks.append(dict(core=hex(core), helper=kind, ordered_calls=[(k, hex(p)) for k, p in calls], abi='pass'))
# Exhaust every scheduler interleaving for two two-lock acquisitions.
def deadlocks(paths):
    found = []
    def step(pos, owners, trace):
        if all(pos[i] == len(paths[i]) for i in range(2)): return
        progress = False
        for i in range(2):
            if pos[i] == len(paths[i]): continue
            lock = paths[i][pos[i]]
            if lock in owners: continue
            progress = True
            np = list(pos); np[i] += 1
            no = dict(owners); no[lock] = i
            if np[i] == len(paths[i]): no = {k:v for k,v in no.items() if v != i}
            step(np, no, trace + [(i, lock)])
        if not progress: found.append(trace)
    step([0,0], {}, [])
    return found
assert deadlocks([['core','wdev'], ['wdev','core']])
assert not deadlocks([['wdev','core'], ['wdev','core']])
report = dict(arm64_helpers=checks, shared_peer_unlock='preserved',
              original_lock_inversion='reproduced in exhaustive two-thread model',
              patched_lock_inversion='absent in same model',
              limitations='Mocks mutex implementations; not an in-kernel or long-duration WiFi test.')
(BASE / 'offline-tests.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
