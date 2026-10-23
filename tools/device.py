#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only device doctor. Never enables ADB or restarts the UI."""
import argparse,json
from adb_device import Device
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--serial');p.add_argument('--adb');a=p.parse_args()
try:print(json.dumps(Device(a.serial,a.adb).inspect(),indent=2))
except (ValueError,RuntimeError,OSError,TimeoutError) as e:p.exit(2,str(e)+'\n')
