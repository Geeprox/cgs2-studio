#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Opt-in driver boot selection. Never unloads a live WiFi module or reboots."""
import argparse,hashlib,os,shlex,shutil,subprocess,sys,uuid
from pathlib import Path
from adb_device import Device
ROOT=Path(__file__).resolve().parents[1]
ORIGINAL='ec8916437220d062470f082f09e77c2c7ff0e2b596418aae1448be451f016f9b'
CANDIDATE='d88d8f8e807162a681201d04391b38cac139239b23f035e97d909547f1ee2ffa'
LOADER='5d9e6d1267b884be1111213eac2d80a876dda4a3fe69c63d78c6acee98f964cb'

def main():
 os.umask(0o077)
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['status','install','enable','rollback']);p.add_argument('--serial');p.add_argument('--adb');a=p.parse_args()
 try:
  d=Device(a.serial,a.adb);d.inspect();base='/userdata/cgs2-wifi-rea'
  if a.action=='status':
   print(d.shell('test ! -f '+base+'/load-status || cat '+base+'/load-status'));return 0
  if a.action=='enable':
   d.shell('set -eu;test ! -L '+base+';grep -q "^trial loaded " '+base+'/load-status;test "$(sha256sum '+base+'/skw-lock-order-v1.ko | cut -d \' \' -f1)" = '+CANDIDATE+';rm -f '+base+'/boot-pending;touch '+base+'/enabled;sync')
   print('Enabled for future boots; an unconfirmed boot falls back to original on the next boot.');return 0
  if a.action=='rollback':
   d.shell('set -eu;test ! -L '+base+';test "$(sha256sum '+base+'/skw_insmod.original | cut -d \' \' -f1)" = '+LOADER+';rm -f '+base+'/enabled '+base+'/trial.once '+base+'/boot-pending;cp '+base+'/skw_insmod.original /qingping/bin/skw_insmod.sh.studio-restore;chmod 755 /qingping/bin/skw_insmod.sh.studio-restore;mv /qingping/bin/skw_insmod.sh.studio-restore /qingping/bin/skw_insmod.sh;sync')
   print('Original loader restored. Reboot manually to load the untouched original module.');return 0
  ident=uuid.uuid4().hex;stage=ROOT/'.local/wifi'/ident;stage.mkdir(parents=True)
  d.pull('/system/lib/modules/skw.ko',stage/'skw.original.ko')
  subprocess.run([sys.executable,str(ROOT/'driver/build_patch.py'),'--input',str(stage/'skw.original.ko'),'--output',str(stage/'candidate')],check=True,stdout=subprocess.DEVNULL)
  if hashlib.sha256((stage/'candidate/skw.ko').read_bytes()).hexdigest()!=CANDIDATE:raise ValueError('Unexpected candidate')
  # Only the stock loader can be installed automatically. Existing custom loaders
  # require explicit rollback first; no unknown modifications are overwritten.
  d.shell('test "$(sha256sum /qingping/bin/skw_insmod.sh | cut -d \' \' -f1)" = '+LOADER)
  remote='/userdata/cgs2-wifi-stage-'+ident;d.shell('mkdir '+remote+';chmod 700 '+remote)
  d.push(stage/'candidate/skw.ko',remote+'/skw.ko');d.push(ROOT/'driver/skw_insmod.sh',remote+'/loader.sh')
  loader_sha=hashlib.sha256((ROOT/'driver/skw_insmod.sh').read_bytes()).hexdigest()
  command='''set -eu
exec 9>/tmp/cgs2-studio-install.lock;flock -n 9
B=/userdata/cgs2-wifi-rea
S=REMOTE
[ ! -L "$B" ] && [ ! -L /qingping/bin/skw_insmod.sh ]
[ "$(sha256sum /qingping/bin/skw_insmod.sh | cut -d ' ' -f1)" = ORIGINAL_LOADER ]
[ "$(sha256sum /system/lib/modules/skw.ko | cut -d ' ' -f1)" = ORIGINAL_MODULE ]
[ "$(sha256sum "$S/skw.ko" | cut -d ' ' -f1)" = CANDIDATE_MODULE ]
[ "$(sha256sum "$S/loader.sh" | cut -d ' ' -f1)" = CANDIDATE_LOADER ]
mkdir -p "$B";chmod 700 "$B"
if [ -e "$B/skw_insmod.original" ];then
 [ "$(sha256sum "$B/skw_insmod.original" | cut -d ' ' -f1)" = ORIGINAL_LOADER ]
else cp -p /qingping/bin/skw_insmod.sh "$B/skw_insmod.original";fi
cp "$S/skw.ko" "$B/skw-lock-order-v1.ko.new";chmod 600 "$B/skw-lock-order-v1.ko.new";mv "$B/skw-lock-order-v1.ko.new" "$B/skw-lock-order-v1.ko"
cp "$S/loader.sh" /qingping/bin/skw_insmod.sh.studio-new;chmod 755 /qingping/bin/skw_insmod.sh.studio-new
rm -f "$B/enabled" "$B/boot-pending"
touch "$B/trial.once";sync
mv /qingping/bin/skw_insmod.sh.studio-new /qingping/bin/skw_insmod.sh;sync
'''.replace('REMOTE',remote).replace('ORIGINAL_LOADER',LOADER).replace('ORIGINAL_MODULE',ORIGINAL).replace('CANDIDATE_MODULE',CANDIDATE).replace('CANDIDATE_LOADER',loader_sha)
  d.shell(command)
  print('One-boot trial staged. Reboot manually, reconnect, run status, then enable only after checking WiFi. The next unenabled boot uses the original.')
  return 0
 except (ValueError,RuntimeError,OSError,subprocess.SubprocessError) as e:print('Stopped: '+str(e),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
