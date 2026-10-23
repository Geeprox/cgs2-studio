# CGS2 skw lock-order repair

SPDX-License-Identifier: GPL-2.0-only

This directory contains the authored repair builder, AArch64 assembly and trial
loader. It does not contain a vendor module or radio firmware. The Linux kernel
uses [GPL-2.0-only licensing rules](https://docs.kernel.org/process/license-rules.html);
this directory carries its own full [license](LICENSE), separate from user-space MIT files.

## Supported input

- CGS2, Linux `4.19.232`, AArch64, module `skw6160_mp2.0.240112.fcefe00`.
- Original SHA-256: `ec8916437220d062470f082f09e77c2c7ff0e2b596418aae1448be451f016f9b`.
- Generated candidate SHA-256: `d88d8f8e807162a681201d04391b38cac139239b23f035e97d909547f1ee2ffa`.

The observed lock inversion is between `wdev.mtx` (`iface + 0xb0`) and the station
core mutex (`iface + 0x8b0`). Association holds `wdev` and then requests `core`;
station management RX/timeout paths could hold `core` and request `wdev`.
The helper acquires `wdev` before `core`, releases in reverse order, removes the
now-redundant inner lock operations, and preserves the shared peer error-path unlock.

The builder pins the entire original hash, validates ELF sections/relocations,
appends 60 bytes of helper code, updates only documented sections, introduces no
new imports, and verifies unrelated sections and the input remain unchanged.
It refuses signed/versioned or otherwise unexpected modules and Python `-O`.
Do not reuse offsets or structure assumptions for another module build.

## Build only

```sh
python3 -m venv .local/driver-venv
.local/driver-venv/bin/pip install -r driver/requirements-build.txt
.local/driver-venv/bin/python driver/build_patch.py \
  --input /path/to/your/original/skw.ko --output .local/build-driver
```

The resulting module and patch manifest are local-only outputs. Do not publish
them. Installation and one-boot trial are described in [INSTALL](../docs/INSTALL.md).
The original system module remains untouched; loading a candidate requires a
manual reboot. Keep USB recovery available.

## Evidence boundary

Offline tests execute the emitted lock helpers, check ABI preservation and compare
the old/patched order in an exhaustive two-thread model. Trial-loader fixtures
cover original, trial, enabled, unconfirmed boot, bad hash and failed-load fallback.
The development device completed cold-boot/reconnect checks, but multi-day
stability and unrelated ARP, router, power-save or radio problems remain unproven.
