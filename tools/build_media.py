#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the freestanding AArch64 loopback media relay; never install it."""
import argparse,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=ROOT/'.local/media-proxy');p.add_argument('--clang',default=shutil.which('clang') or 'clang');a=p.parse_args()
if a.output.exists():p.error('Output must not already exist')
a.output.mkdir(parents=True)
subprocess.run([a.clang,'-target','aarch64-linux-gnu','-Os','-fno-pic','-fno-pie','-fno-jump-tables','-ffreestanding','-fno-stack-protector','-fno-builtin','-fno-unwind-tables','-fno-asynchronous-unwind-tables','-c',str(ROOT/'device/media-proxy.c'),'-o',str(a.output/'media-proxy.o')],check=True)
subprocess.run([sys.executable,str(ROOT/'tools/link_proxy.py'),'--input',str(a.output/'media-proxy.o'),'--output',str(a.output/'media-proxy')],check=True)
