#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Capture the current CGS2 scanout without restarting or redrawing its UI."""
import argparse,gzip,struct,subprocess,uuid,zlib
from pathlib import Path
from adb_device import Device
ROOT=Path(__file__).resolve().parents[1]
def png(raw):
 if len(raw)<16:raise ValueError('Incomplete capture')
 w,h,pitch,bpp=struct.unpack('<4I',raw[:16])
 if (w,h,bpp)!=(720,720,32)or not 2880<=pitch<=8192 or len(raw)!=16+pitch*h:raise ValueError('Unsupported scanout')
 rows=bytearray()
 for y in range(h):
  rows.append(0);line=raw[16+y*pitch:16+y*pitch+w*4]
  for x in range(0,len(line),4):rows.extend((line[x+2],line[x+1],line[x],255))
 def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,6))+chunk(b'IEND',b'')
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--serial');p.add_argument('--adb');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 if a.output.exists():p.error('Output already exists; choose a new file')
 stage=ROOT/'.local/capture'/uuid.uuid4().hex;stage.mkdir(parents=True);remote='/tmp/cgs2-capture-'+stage.name
 d=Device(a.serial,a.adb);d.inspect()
 subprocess.run(['clang','-target','aarch64-linux-gnu','-Os','-fno-pic','-fno-pie','-fno-jump-tables','-ffreestanding','-fno-stack-protector','-fno-builtin','-fno-unwind-tables','-fno-asynchronous-unwind-tables','-c',str(ROOT/'device/screen-capture.c'),'-o',str(stage/'capture.o')],check=True)
 subprocess.run(['python3',str(ROOT/'tools/link_proxy.py'),'--input',str(stage/'capture.o'),'--output',str(stage/'capture')],check=True)
 before=d.shell('pidof QingSnow2App')
 try:
  d.shell('test ! -e '+remote+';mkdir -m 700 '+remote);d.push(stage/'capture',remote+'/capture')
  d.shell('chmod 700 '+remote+'/capture;'+remote+'/capture >'+remote+'/raw;gzip -c '+remote+'/raw >'+remote+'/raw.gz')
  d.pull(remote+'/raw.gz',stage/'raw.gz');image=png(gzip.decompress((stage/'raw.gz').read_bytes()))
  if before!=d.shell('pidof QingSnow2App'):raise RuntimeError('UI process changed during capture')
  a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(image);print('Saved actual 720x720 scanout: '+str(a.output.resolve()))
 finally:d.shell('rm -rf '+remote)
if __name__=='__main__':main()
