#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Install an explicitly selected optional provider. Credentials are never printed."""
import argparse,hashlib,ipaddress,json,os,re,shutil,subprocess,sys,uuid
from pathlib import Path
from urllib.parse import urlsplit
from adb_device import Device
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('provider',choices=['media','voice']);p.add_argument('--private',required=True,type=Path,help='Own service directory produced by initialize_service.py');p.add_argument('--serial');p.add_argument('--adb');p.add_argument('--replace',action='store_true',help='Explicitly replace an existing provider configuration after backing it up');a=p.parse_args()
try:
 os.umask(0o077)
 origin=(a.private/'origin').read_text().strip();u=urlsplit(origin);address=ipaddress.ip_address(u.hostname or '')
 if u.scheme!='https' or u.netloc!=u.hostname+':'+str(u.port) or u.path or u.query or u.fragment or address.version!=4 or not any(address in ipaddress.ip_network(v)for v in ['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']):raise ValueError('Invalid canonical LAN HTTPS origin')
 header=(a.private/'auth-header').read_text()
 if not re.fullmatch(r'Authorization: Bearer [a-f0-9]{64}\n',header):raise ValueError('Use the independent generated device credential')
 cert=(a.private/'server.pem').read_bytes()
 if b'PRIVATE KEY' in cert or not cert.startswith(b'-----BEGIN CERTIFICATE-----'):raise ValueError('Provide the public service certificate only')
 d=Device(a.serial,a.adb);report=d.inspect()
 if report['application']=='factory':raise ValueError('Install the base UI before configuring an optional provider')
 ident=uuid.uuid4().hex;stage=ROOT/'.local/configure'/ident;stage.mkdir(parents=True)
 target='/userdata/cgs2-media' if a.provider=='media' else '/userdata/cgs2-voice'
 # Reject active optional sessions before any writes.
 d.shell("test ! -f /tmp/cgs2-ui/screen-state.json || jq -e '.microActive!=true and .mediaActive!=true' /tmp/cgs2-ui/screen-state.json >/dev/null")
 d.shell("test ! -f /tmp/cgs2-voice/state.json || jq -e '.status!=\"recording\" and .status!=\"starting\" and .status!=\"transcribing\"' /tmp/cgs2-voice/state.json >/dev/null")
 if not a.replace:d.shell('test ! -e '+target+'/auth-header')
 (stage/'ca.pem').write_bytes(cert);(stage/'auth-header').write_text(header)
 if a.provider=='media':
  (stage/'origin').write_text(origin+'\n')
  media=ROOT/'.local/media-build'/ident;subprocess.run([sys.executable,str(ROOT/'tools/build_media.py'),'--output',str(media)],check=True,stdout=subprocess.DEVNULL)
  shutil.copy2(media/'media-proxy',stage/'media-proxy')
  for n in ['media-client.sh','media-proxy-service.sh','S99cgs2-media']:shutil.copy2(ROOT/'device'/n,stage/n)
  paths={'ca.pem':target+'/ca.pem','auth-header':target+'/auth-header','origin':target+'/origin',**{n:'/userdata/cgs2-ui/'+n for n in ['media-client.sh','media-proxy-service.sh','media-proxy']},'S99cgs2-media':'/etc/init.d/S99cgs2-media'}
  hook='/etc/init.d/S99cgs2-media'
 else:
  (stage/'config.json').write_text(json.dumps({'origin':origin})+'\n')
  for n in ['common.sh','client.sh','worker.sh','consume.sh','service.sh','S99cgs2-voice']:shutil.copy2(ROOT/'integrations/voice/device'/n,stage/n)
  paths={n:target+'/'+n for n in ['ca.pem','auth-header','config.json','common.sh','client.sh','worker.sh','consume.sh','service.sh']};paths['S99cgs2-voice']='/etc/init.d/S99cgs2-voice';hook='/etc/init.d/S99cgs2-voice'
 remote='/userdata/cgs2-provider-staging/'+ident;d.shell('mkdir -p '+remote+';chmod 700 '+remote);d.push(stage,remote.rsplit('/',1)[0])
 actual=remote
 backup='/userdata/cgs2-provider-backups/'+ident
 command='set -eu\nexec 9>/tmp/cgs2-studio-install.lock;flock -n 9\nB='+backup+'\nS='+actual+'\n[ ! -L '+target+' ]\nmkdir -p "$B" '+target+'\nchmod 700 "$B" '+target+'\n'
 for source,dest in paths.items():
  sha=hashlib.sha256((stage/source).read_bytes()).hexdigest()
  command+='[ ! -L '+dest+' ]\n[ "$(sha256sum "$S/'+source+'" | cut -d \' \' -f1)" = '+sha+' ]\n'
  command+='if [ -f '+dest+' ];then mkdir -p "$B'+str(Path(dest).parent)+'";cp -p '+dest+' "$B'+dest+'";fi\n'
 command+="""done=0
had_hook=0
[ ! -f HOOK ] || had_hook=1
cleanup(){
 trap - EXIT HUP INT TERM
 [ "$done" -eq 1 ] && return 0
 [ ! -f HOOK ] || HOOK stop >/dev/null 2>&1 || true
RESTORE
 [ "$had_hook" -ne 1 ] || HOOK start >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
[ ! -f HOOK ] || HOOK stop
""".replace('HOOK',hook).replace('RESTORE','\n'.join('if [ -f "$B'+dest+'" ];then cp -p "$B'+dest+'" '+dest+'.studio-restore;mv '+dest+'.studio-restore '+dest+';else rm -f '+dest+';fi' for dest in paths.values()))
 for source,dest in paths.items():
  mode='755' if source.endswith('.sh') or source.startswith('S99') or source=='media-proxy' else '600'
  command+='cp "$S/'+source+'" '+dest+'.studio-new;chmod '+mode+' '+dest+'.studio-new;mv '+dest+'.studio-new '+dest+'\n'
 command+='sync\n'+hook+' start\ndone=1\n'
 d.shell(command,60)
 print('Optional provider configured. Original provider files, when present, are backed up on the device. Core preferences were preserved.')
except (ValueError,RuntimeError,OSError,subprocess.SubprocessError) as e:p.exit(2,'Stopped: '+str(e)+'\n')
