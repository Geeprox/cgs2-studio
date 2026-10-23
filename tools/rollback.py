#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Restore an installation receipt without overwriting later managed edits."""
import argparse,re,uuid
from pathlib import Path
from adb_device import Device
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--serial');p.add_argument('--adb');p.add_argument('--backup',required=True);a=p.parse_args()
if not re.fullmatch('[a-f0-9]{32}',a.backup):p.error('Invalid backup ID')
try:
 d=Device(a.serial,a.adb);d.inspect();remote='/tmp/cgs2-studio-rollback-'+uuid.uuid4().hex+'.sh';d.push(Path(__file__).resolve().parents[1]/'device/rollback-ui.sh',remote)
 print(d.shell('/bin/sh '+remote+' '+a.backup,90))
 d.shell('rm -f '+remote)
except (ValueError,RuntimeError,OSError) as e:p.exit(2,str(e)+'\n')
