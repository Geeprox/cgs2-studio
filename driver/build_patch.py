# SPDX-License-Identifier: GPL-2.0-only
"""Version-pinned ELF patch. Never modifies the original or touches a device."""
from pathlib import Path
import argparse, hashlib, io, json, shutil, struct, subprocess, sys, tempfile
if not __debug__:raise SystemExit('Run without Python -O: validation assertions are required')
BASE = Path(__file__).resolve().parent
if sys.version_info<(3,10):raise SystemExit('Python 3.10 or newer is required')
from elftools.elf.elffile import ELFFile
ORIGINAL_SHA = 'ec8916437220d062470f082f09e77c2c7ff0e2b596418aae1448be451f016f9b'
parser=argparse.ArgumentParser(description='Generate a version-pinned WiFi repair from your own device module; no installation is performed.')
parser.add_argument('--input',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
parser.add_argument('--clang',default=shutil.which('clang') or 'clang')
args=parser.parse_args()
if args.output.exists():parser.error('Output directory must not already exist')
source=args.input.read_bytes()
assert hashlib.sha256(source).hexdigest() == ORIGINAL_SHA
elf = ELFFile(io.BytesIO(source))
assert elf['e_type'] == 'ET_REL' and elf['e_machine'] == 'EM_AARCH64'
textsec = elf.get_section_by_name('.text')
text = bytearray(textsec.data())
rela = elf.get_section_by_name('.rela.text')
symbols = elf.get_section_by_name('.symtab')
strtab = bytearray(elf.get_section_by_name('.strtab').data())
symtab = bytearray(symbols.data())
symids = {s.name: i for i, s in enumerate(symbols.iter_symbols())}
assert elf.get_section_by_name('__versions') is None
assert not source.endswith(b'~Module signature appended~\n')
with tempfile.TemporaryDirectory(prefix='cgs2-patch-') as temp:
    helper_path=Path(temp)/'lock-order.o'
    subprocess.run([args.clang,'-target','aarch64-linux-gnu','-c',str(BASE/'lock-order.S'),'-o',str(helper_path)],check=True)
    helper_data=helper_path.read_bytes()
helper=ELFFile(io.BytesIO(helper_data))
padding = (-len(text)) % 4
text.extend(b'\0' * padding)
helper_start = len(text)
text.extend(helper.get_section_by_name('.text').data())
helper_symbols = helper.get_section_by_name('.symtab')
for s in helper_symbols.iter_symbols():
    if s.name.startswith('cgs2_sta_'):
        name_off = len(strtab)
        strtab.extend(s.name.encode() + b'\0')
        symtab.extend(struct.pack('<IBBHQQ', name_off, 0x12, 0, 2,
                                  helper_start + s['st_value'], s['st_size']))
lock = helper_start
unlock = helper_start + 32
assert len(text) - helper_start == 60
patches = []
removed = {}
def instruction(offset, expected, word, reason):
    old = struct.unpack_from('<I', text, offset)[0]
    assert old == expected, (hex(offset), hex(old), hex(expected))
    struct.pack_into('<I', text, offset, word)
    patches.append(dict(offset=hex(offset), before=hex(old), after=hex(word), reason=reason))
def branch(offset, target, link=False):
    delta = target - offset
    assert delta % 4 == 0 and -(1 << 27) <= delta < (1 << 27)
    return (0x94000000 if link else 0x14000000) | ((delta >> 2) & 0x3ffffff)
for offset, target, oldsym in [(0xfb48, lock, 'mutex_lock'),
                              (0xfbdc, unlock, 'mutex_unlock'),
                              (0x3d24, lock, 'mutex_lock'),
                              (0x3e98, unlock, 'mutex_unlock')]:
    instruction(offset, 0x94000000, branch(offset, target, True), 'ordered lock pair')
    removed[offset] = oldsym
for offset, oldsym in [(0xfc4c, 'mutex_lock'), (0xfe80, 'mutex_lock'),
                       (0xfea4, 'mutex_unlock')]:
    instruction(offset, 0x94000000, 0xd503201f, 'outer pair already owns wdev.mtx')
    removed[offset] = oldsym
# fc68 is ALSO the peer-context error unlock: keep its mutex_unlock relocation.
# Only the successful MLME callback path bypasses its former wdev unlock.
instruction(0xfc60, 0xf9417a60, branch(0xfc60, 0xfbd8), 'bypass inner wdev unlock, preserve shared peer unlock')
relocs = []
seen = set()
for r in rela.iter_relocations():
    off = r['r_offset']
    if off in removed:
        assert r['r_info_type'] == 283 and symbols.get_symbol(r['r_info_sym']).name == removed[off]
        seen.add(off)
    else:
        relocs.append(struct.pack('<QQq', off, r['r_info'], r['r_addend']))
assert seen == set(removed)
for r in helper.get_section_by_name('.rela.text').iter_relocations():
    assert r['r_info_type'] == 283
    name = helper_symbols.get_symbol(r['r_info_sym']).name
    assert name in ['mutex_lock', 'mutex_unlock'] and name in symids
    relocs.append(struct.pack('<QQq', helper_start + r['r_offset'],
                              (symids[name] << 32) | 283, r['r_addend']))
new_relocs = b''.join(relocs)
modinfo = elf.get_section_by_name('.modinfo').data() + b'cgs2_patch=lock-order-v1\0'
note = bytearray(elf.get_section_by_name('.note.gnu.build-id').data())
assert len(note) == 36
note[-20:] = hashlib.sha1(text).digest()
updates = {'.text': bytes(text), '.rela.text': new_relocs, '.symtab': bytes(symtab),
           '.strtab': bytes(strtab), '.modinfo': modinfo, '.note.gnu.build-id': bytes(note)}
result = bytearray(source)
for idx, sec in enumerate(elf.iter_sections()):
    if sec.name not in updates:
        continue
    result.extend(b'\0' * ((-len(result)) % max(1, sec['sh_addralign'])))
    new_offset = len(result)
    result.extend(updates[sec.name])
    h = elf['e_shoff'] + idx * elf['e_shentsize']
    struct.pack_into('<QQ', result, h + 24, new_offset, len(updates[sec.name]))
out = args.output
out.mkdir(exist_ok=True)
(out / 'skw.ko').write_bytes(result)
# Every unrelated section must be byte-for-byte identical, including driver data,
# module structure, dependency versions, hardware calibration and firmware protocol.
patched = ELFFile(io.BytesIO(result))
assert patched.num_sections() == elf.num_sections()
for sec in elf.iter_sections():
    if sec.name not in updates:
        assert patched.get_section_by_name(sec.name).data() == sec.data(), sec.name
assert hashlib.sha256(args.input.read_bytes()).hexdigest() == ORIGINAL_SHA
report = dict(original_sha256=ORIGINAL_SHA, candidate_sha256=hashlib.sha256(result).hexdigest(),
              original_text_size=textsec['sh_size'], candidate_text_size=len(text),
              helper_lock=hex(lock), helper_unlock=hex(unlock), patches=patches,
              changed_sections=list(updates), new_imports=[], firmware_files_changed=[])
(out / 'patch-manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
