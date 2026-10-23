#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Render synthetic face previews in isolated Qt offscreen processes on a CGS2."""
import argparse,hashlib,json,os,shutil,subprocess,uuid
from pathlib import Path
from adb_device import Device
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--serial');p.add_argument('--adb');p.add_argument('--panels',default='',help='Comma-separated synthetic panels: micro,menu,display,photos,video,music');p.add_argument('--skins',default=','.join(map(str,range(14))));a=p.parse_args()
try:
 skins=[int(x)for x in a.skins.split(',') if x]
 panels=[x for x in a.panels.split(',') if x]
 if any(x not in ['micro','menu','display','photos','video','music'] for x in panels):raise ValueError('Unknown panel')
 if not (skins or panels) or any(n not in range(14)for n in skins):raise ValueError('Choose face numbers 0..13')
 d=Device(a.serial,a.adb);d.inspect();ident=uuid.uuid4().hex
 stage=ROOT/'.local/preview'/ident;stage.mkdir(parents=True);remote='/userdata/cgs2-preview/'+ident
 shutil.copytree(ROOT/'qml',stage/'qml');shutil.copytree(ROOT/'preview/imports',stage/'qml/imports')
 for name in ['user/cache/media','ui','voice','micro','media/cache','screens']:(stage/name).mkdir(parents=True)
 replacements=[('/userdata/cgs2-ui/',remote+'/user/'),('/tmp/cgs2-ui/',remote+'/ui/'),('/tmp/cgs2-voice/',remote+'/voice/'),('/tmp/cgs2-media/',remote+'/media/'),('/tmp/cgs2-micro-lan/',remote+'/micro/')]
 for f in (stage/'qml').rglob('*'):
  if f.is_file()and f.suffix in ['.qml','.js']:
   text=f.read_text()
   for before,after in replacements:text=text.replace(before,after)
   f.write_text(text)
 fixtures={'user/preferences.json':{'version':4,'skin':0,'faceMotion':False,'edgeWeather':False},'user/layouts.json':{'version':1,'themes':{}},'ui/weather-demo.json':{'enabled':False},'ui/history.json':{},'ui/recovery-status.json':{},'micro/status.json':{'connected':False},'media/manifest.json':{'protocol':2,'enabled':False,'items':[],'stateUptimeMs':0},'voice/state.json':{'status':'idle','session':'','text':'','partial':''}}
 if any(x in panels for x in ['photos','video','music']):shutil.copy2(ROOT/'docs/previews/face-0.png',stage/'media/cache/sample.jpg')
 for name,value in fixtures.items():(stage/name).write_text(json.dumps(value))
 template=(ROOT/'preview/Scene.qml.in').read_text()
 for n in skins:(stage/'qml'/('Render'+str(n)+'.qml')).write_text(template.replace('@REMOTE@',remote).replace('@SKIN@',str(n)))
 for name in panels:
  text=(ROOT/'preview/Micro.qml.in').read_text() if name=='micro' else template.replace('state.chooseSkin(root.previewSkin);capture.start()',"state.chooseSkin(root.previewSkin);dash.panel='"+('menu' if name=='menu' else 'night-screen')+"';capture.start()").replace('var creative=', 'var creative=').replace('face-@SKIN@.png',name+'.png')
  if name in ['photos','video','music']:text=(ROOT/'preview/Media.qml.in').read_text().replace('@KIND@',{'photos':'photo','video':'video','music':'audio'}[name]).replace('@NAME@',name)
  (stage/'qml'/('Render'+name+'.qml')).write_text(text.replace('@REMOTE@',remote).replace('@SKIN@','0'))
 before=d.shell("pidof QingSnow2App; sha256sum /qingping/bin/QingSnow2App; test ! -f /userdata/cgs2-ui/preferences.json || sha256sum /userdata/cgs2-ui/preferences.json")
 d.shell('test ! -e '+remote+';mkdir -p '+remote+';chmod 700 '+remote);d.push(stage,remote.rsplit('/',1)[0])
 script='''set -eu
R=REMOTE
mkdir -p "$R/screens"
WD=''
for p in $(pgrep -x watchdog.sh);do
 [ "$(awk '{print $4}' /proc/$p/stat)" = 1 ] && [ "$(tr '\\000' ' ' < /proc/$p/cmdline)" = '/bin/sh /qingping/bin/watchdog.sh ' ] || continue
 [ -z "$WD" ] || exit 2;WD=$p
done
[ -n "$WD" ]
child='';guard=''
cleanup(){ trap - EXIT HUP INT TERM;[ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true;kill -CONT "$WD";[ -z "$guard" ] || kill -TERM "$guard" 2>/dev/null || true;echo 3 > /proc/sys/vm/drop_caches; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
kill -STOP "$WD"
(sleep 125;kill -CONT "$WD") </dev/null >/dev/null 2>&1 &
guard=$!
for n in SKINS;do
 echo 3 > /proc/sys/vm/drop_caches
 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML2_IMPORT_PATH="$R/qml/imports" QML_XHR_ALLOW_FILE_READ=1 QML_XHR_ALLOW_FILE_WRITE=1 /usr/bin/qmlscene "$R/qml/Render$n.qml" >"$R/render-$n.log" 2>&1 &
 child=$!;ticks=0
 while kill -0 "$child" 2>/dev/null;do
  if [ "$ticks" -ge 8 ];then kill -TERM "$child";wait "$child" || true;child='';exit 2;fi
  ticks=$((ticks+1));sleep 1
 done
 wait "$child";child=''
 grep -q 'CGS2_PREVIEW_SAVED true' "$R/render-$n.log"
 echo CGS2_PREVIEW_OK_$n
done
'''.replace('REMOTE',remote).replace('SKINS',' '.join(list(map(str,skins))+panels))
 (stage/'render.sh').write_text(script);d.push(stage/'render.sh',remote+'/render.sh')
 print(d.shell('timeout -s TERM 120 /bin/sh '+remote+'/render.sh',135),flush=True)
 after=d.shell("pidof QingSnow2App; sha256sum /qingping/bin/QingSnow2App; test ! -f /userdata/cgs2-ui/preferences.json || sha256sum /userdata/cgs2-ui/preferences.json")
 if before!=after:raise RuntimeError('Formal UI process or preference guard changed')
 d.pull(remote+'/screens',stage)
 for n in skins:
  if not (stage/'screens'/('face-'+str(n)+'.png')).is_file():raise RuntimeError('Missing preview')
 for name in panels:
  if not (stage/'screens'/(name+'.png')).is_file():raise RuntimeError('Missing panel preview')
 d.shell('rm -rf '+remote)
 (stage/'receipt.json').write_text(json.dumps({'syntheticSensors':True,'isolatedIPC':True,'formalUiAndPreferencesUnchanged':True,'skins':skins,'panels':panels},indent=2)+'\n')
 print('Synthetic previews saved: '+str(stage/'screens'))
except (ValueError,RuntimeError,OSError,subprocess.SubprocessError)as e:
 if 'd' in locals() and 'remote' in locals():
  try:d.pull(remote,stage/'remote-debug')
  except Exception:pass
 p.exit(2,'Preview stopped: '+str(e)+'\n')
