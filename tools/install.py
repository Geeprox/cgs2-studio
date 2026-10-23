#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Prepare from the owner's firmware, then stage and install with a device backup."""
import argparse,hashlib,json,os,shutil,subprocess,sys,uuid
from pathlib import Path
from adb_device import Device,ORIGINAL
from prepare_firmware import build
ROOT=Path(__file__).resolve().parents[1]
WATCHDOG={'f2753d6de46d9ae8b1f8b119ae7afab3f60e944a6f723baee3224b237eb606ec','3efa6207a6fde64b3ba92c248aea07523e588b4050e8845121646e71affd9b82'}
MANAGED=['/qingping/bin/QingSnow2App','/qingping/bin/watchdog.sh','/etc/init.d/S98cgs2-ui','/userdata/cgs2-ui/recovery-agent.sh','/userdata/cgs2-ui/history-export.sh']

def transform_watchdog(data):
 if hashlib.sha256(data).hexdigest()not in WATCHDOG:raise ValueError('Unknown vendor watchdog; no install performed')
 s=data.decode().replace('appCount=`ps | grep "$SNOW_OS" | grep -v grep | wc -l`','appCount=$(pidof "$SNOW_OS" | wc -w)')
 s=s.replace('/qingping/bin/QingSnow2App -platform eglfs  &','QT_GSTREAMER_PLAYBIN=playbin QT_GSTREAMER_WIDGET_VIDEOSINK= QT_GSTREAMER_WINDOW_VIDEOSINK= /qingping/bin/QingSnow2App -platform eglfs &')
 return s.encode()

def main():
 os.umask(0o077)
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--serial');p.add_argument('--adb');p.add_argument('--firmware',type=Path,help='Own exact factory application; required if device is already customized');p.add_argument('--prepare-only',action='store_true');a=p.parse_args()
 try:
  d=Device(a.serial,a.adb);report=d.inspect();ident=uuid.uuid4().hex
  stage=ROOT/'.local/install'/ident;stage.mkdir(parents=True,mode=0o700)
  source=a.firmware
  if source is None:
   if d.sha!=ORIGINAL:raise ValueError('Already customized: supply your own factory backup with --firmware')
   source=stage/'QingSnow2App.original';d.pull('/qingping/bin/QingSnow2App',source)
  build(source,stage/'firmware');payload=stage/'payload';payload.mkdir()
  shutil.copytree(ROOT/'qml',payload/'qml')
  for name in ['NativeAirDatasView.qml','NativeScreenSaver.qml']:shutil.copy2(stage/'firmware'/name,payload/'qml'/name)
  shutil.copy2(stage/'firmware/QingSnow2App',payload/'QingSnow2App')
  for name in ['recovery-agent.sh','history-export.sh','S98cgs2-ui','rollback-ui.sh']:shutil.copy2(ROOT/'device'/name,payload/name)
  d.pull('/qingping/bin/watchdog.sh',stage/'watchdog.original.sh');(payload/'watchdog.sh').write_bytes(transform_watchdog((stage/'watchdog.original.sh').read_bytes()))
  files=sorted(p for p in payload.rglob('*')if p.is_file())
  (payload/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f.relative_to(payload))+'\n'for f in files))
  (stage/'managed-paths').write_text('\n'.join(MANAGED)+'\n');(stage/'expected-app').write_text(d.sha+'\n');shutil.copy2(ROOT/'device/install-ui.sh',stage/'install-ui.sh')
  (stage/'preflight.json').write_text(json.dumps(report,indent=2)+'\n')
  if a.prepare_only:print('Prepared locally; no device writes. Package ID: '+ident);return 0
  remote='/userdata/cgs2-studio-staging/'+ident
  d.shell('test ! -e '+remote+' && mkdir -p '+remote+' && chmod 700 '+remote)
  d.push(stage,remote.rsplit('/',1)[0])
  output=d.shell('/bin/sh '+remote+'/install-ui.sh '+ident,180)
  if 'CGS2_INSTALL_OK' not in output:raise RuntimeError('Installation did not return a verified receipt')
  (stage/'receipt.json').write_text(json.dumps({'installed':True,'backupId':ident,'candidateSha256':d.sha if report['application']!='factory' else __import__('adb_device').FINAL},indent=2)+'\n')
  print('Installed; stable native process verified. Backup ID: '+ident)
  print('Rollback: python3 tools/rollback.py --backup '+ident)
  return 0
 except (ValueError,RuntimeError,OSError,subprocess.SubprocessError) as e:print('Stopped: '+str(e),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
