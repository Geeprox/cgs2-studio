#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
ROOT=/userdata/cgs2-wifi-rea
test -s "$ROOT/skw_insmod.original"
[ ! -L "$ROOT" ] && [ ! -L "$ROOT/skw_insmod.original" ] && [ ! -L /qingping/bin/skw_insmod.sh ]
[ "$(sha256sum "$ROOT/skw_insmod.original" | cut -d ' ' -f1)" = 5d9e6d1267b884be1111213eac2d80a876dda4a3fe69c63d78c6acee98f964cb ]
rm -f "$ROOT/enabled" "$ROOT/trial.once" "$ROOT/boot-pending"
cp "$ROOT/skw_insmod.original" /qingping/bin/skw_insmod.sh
chmod 755 /qingping/bin/skw_insmod.sh
sync
echo 'Original loader restored. Reboot to load untouched original driver.'
