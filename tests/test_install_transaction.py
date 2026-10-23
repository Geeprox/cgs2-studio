#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Execute deployment shell control flow in a fully redirected fake device.
No ADB, native executable, real process signal or privileged path is used.
"""
import hashlib,os,re,shutil,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FACTORY='1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac'
FINAL='91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7'
ID='a'*32
sha=lambda data:hashlib.sha256(data).hexdigest()
class InstallTransaction(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='cgs2-install-test-');self.base=Path(self.temp.name).resolve();self.bin=self.base/'bin';self.bin.mkdir()
  for d in ['userdata/cgs2-ui/qml','userdata/cgs2-studio-staging/'+ID+'/payload/qml','qingping/bin','etc/init.d','tmp','proc/sys/vm','proc/4240','proc/4242']:(self.base/d).mkdir(parents=True,exist_ok=True)
  self.app=self.base/'qingping/bin/QingSnow2App';self.original=b'original application fixture';self.candidate=b'new application fixture';self.app.write_bytes(self.original)
  (self.base/'userdata/cgs2-ui/qml/old.qml').write_text('old theme')
  (self.base/'userdata/cgs2-ui/preferences.json').write_text('private preferences fixture')
  (self.base/'qingping/bin/watchdog.sh').write_text('original watchdog fixture')
  (self.base/'tmp/running').write_text('4242')
  (self.base/'proc/4240/stat').write_text('4240 (watchdog.sh) S 1 0 0')
  (self.base/'proc/4240/cmdline').write_bytes(b'/bin/sh\0'+str(self.base/'qingping/bin/watchdog.sh').encode()+b'\0')
  (self.base/'proc/4242/status').write_text('State:\tS (sleeping)\n')
  self.stage=self.base/'userdata/cgs2-studio-staging'/ID;self.payload=self.stage/'payload'
  (self.payload/'QingSnow2App').write_bytes(self.candidate);(self.payload/'watchdog.sh').write_text('new watchdog fixture');(self.payload/'qml/new.qml').write_text('new theme')
  for n in ['recovery-agent.sh','history-export.sh','S98cgs2-ui']:(self.payload/n).write_text('#!/bin/sh\nexit 0\n')
  (self.payload/'rollback-ui.sh').write_text(self.translate((ROOT/'device/rollback-ui.sh').read_text()))
  (self.stage/'expected-app').write_text(sha(self.original)+'\n')
  managed=['/qingping/bin/QingSnow2App','/qingping/bin/watchdog.sh','/etc/init.d/S98cgs2-ui','/userdata/cgs2-ui/recovery-agent.sh','/userdata/cgs2-ui/history-export.sh']
  (self.stage/'managed-paths').write_text(''.join(self.translate(x)+'\n'for x in managed))
  self.manifest()
  self.stub('uname',"[ \"$1\" = -m ] && echo aarch64 || echo 4.19.232")
  self.stub('id','echo 0');self.stub('df',"echo 'Filesystem 1024-blocks Used Available Capacity Mounted';echo 'fixture 9999999 0 9999999 0% /'")
  self.stub('pgrep','[ "$1" = -x ] && echo 4240 || exit 1')
  self.stub('pidof','cat "$FIXTURE_ROOT/tmp/running" 2>/dev/null || true')
  self.stub('flock','exit 0')
  # Match the device's BusyBox find: -quit is unavailable.
  self.stub('find',"for arg in \"$@\";do [ \"$arg\" != -quit ] || exit 2;done;exec /usr/bin/find \"$@\"")
  # The production wait gives its background launcher time to initialize. A zero
  # duration stub races on fast Linux runners; wait for the synthetic PID fence.
  self.stub('sleep','''if [ "$1" = 8 ];then
 n=0
 while [ ! -s "$FIXTURE_ROOT/tmp/running" ] && [ "$n" -lt 100 ];do
  n=$((n+1));/bin/sleep .005
 done
fi
exit 0''')
  self.stub('kill','''echo "$*" >> "$FIXTURE_ROOT/tmp/signals"
case "$1:$2" in -TERM:4242|-TERM:4243)
 echo 'State: Z (zombie)' > "$FIXTURE_ROOT/proc/$2/status"
 rm -f "$FIXTURE_ROOT/tmp/running";;esac
exit 0''')
  self.stub('setsid','''case "$1" in */QingSnow2App)
 for key in QT_QPA_EGLFS_WIDTH QT_QPA_EGLFS_HEIGHT QT_QPA_EGLFS_PHYSICAL_WIDTH QT_QPA_EGLFS_PHYSICAL_HEIGHT;do
  eval "value=\${$key:-missing}"
  printf '%s=%s\n' "$key" "$value" >> "$FIXTURE_ROOT/tmp/display-env"
 done
 [ "${FAIL_LAUNCH:-0}" = 0 ] || exit 0
 mkdir -p "$FIXTURE_ROOT/proc/4243"
 echo 'State: S (sleeping)' > "$FIXTURE_ROOT/proc/4243/status"
 ln -sf "$FIXTURE_ROOT/qingping/bin/QingSnow2App" "$FIXTURE_ROOT/proc/4243/exe"
 echo 4243 > "$FIXTURE_ROOT/tmp/running";;esac
exit 0''')
  if not shutil.which('sha256sum'):self.stub('sha256sum','exec shasum -a 256 "$@"')
  self.env=dict(os.environ,PATH=str(self.bin)+':'+os.environ['PATH'],FIXTURE_ROOT=str(self.base))
 def tearDown(self):self.temp.cleanup()
 def stub(self,name,body):
  p=self.bin/name;p.write_text('#!/bin/sh\n'+body+'\n');p.chmod(0o755)
 def translate(self,s):
  s=re.sub(r'/userdata/|/qingping/|/etc/init.d/|/tmp/|/proc/',lambda m:str(self.base)+m.group(),s)
  return s.replace('/usr/bin/setsid',str(self.bin/'setsid')).replace('/dev/console',str(self.base/'tmp/console')).replace(FACTORY,sha(self.original)).replace(FINAL,sha(self.candidate))
 def manifest(self):
  (self.payload/'SHA256SUMS').write_text(''.join(sha(p.read_bytes())+'  '+str(p.relative_to(self.payload))+'\n'for p in sorted(self.payload.rglob('*'))if p.is_file()and p.name!='SHA256SUMS'))
 def run_script(self,name,**env):
  text=self.translate((ROOT/'device'/name).read_text())
  # Shadow the shell's kill builtin as well as external xargs -> kill.
  text=text.replace('set -eu','set -eu\nkill(){ "'+str(self.bin/'kill')+'" "$@"; }',1)
  script=self.base/name;script.write_text(text)
  return subprocess.run(['/bin/sh',str(script),ID],env={**self.env,**env},capture_output=True,text=True,timeout=10)
 def test_success_and_guarded_rollback_preserve_preferences(self):
  result=self.run_script('install-ui.sh');self.assertEqual(result.returncode,0,result.stderr);self.assertIn('CGS2_INSTALL_OK',result.stdout)
  self.assertEqual((self.base/'tmp/display-env').read_text().splitlines(),[key+'=720' for key in ['QT_QPA_EGLFS_WIDTH','QT_QPA_EGLFS_HEIGHT','QT_QPA_EGLFS_PHYSICAL_WIDTH','QT_QPA_EGLFS_PHYSICAL_HEIGHT']])
  self.assertEqual(self.app.read_bytes(),self.candidate);self.assertTrue((self.base/'userdata/cgs2-ui/qml/new.qml').exists())
  self.assertEqual((self.base/'userdata/cgs2-ui/preferences.json').read_text(),'private preferences fixture')
  # A later QML edit must block rollback before any process is stopped.
  q=self.base/'userdata/cgs2-ui/qml/new.qml';q.write_text('later user edit');signals=(self.base/'tmp/signals').read_text()
  blocked=self.run_script('rollback-ui.sh');self.assertNotEqual(blocked.returncode,0);self.assertEqual((self.base/'tmp/signals').read_text(),signals)
  q.write_text('new theme');rollback=self.run_script('rollback-ui.sh');self.assertEqual(rollback.returncode,0,rollback.stderr)
  self.assertEqual(self.app.read_bytes(),self.original);self.assertTrue((self.base/'userdata/cgs2-ui/qml/old.qml').exists())
 def test_failed_launch_restores_old_binary_and_qml(self):
  result=self.run_script('install-ui.sh',FAIL_LAUNCH='1');self.assertNotEqual(result.returncode,0)
  self.assertEqual(self.app.read_bytes(),self.original);self.assertTrue((self.base/'userdata/cgs2-ui/qml/old.qml').exists())
  self.assertIn('-CONT 4240',(self.base/'tmp/signals').read_text())
 def test_symlinks_rejected_with_busybox_find_before_process_signals(self):
  for location in [self.payload/'qml/linked.qml',self.base/'userdata/cgs2-ui/qml/linked.qml']:
   with self.subTest(location=location.parent.name):
    location.symlink_to(self.base/'userdata/cgs2-ui/qml/old.qml');self.manifest()
    result=self.run_script('install-ui.sh');self.assertNotEqual(result.returncode,0)
    self.assertIn('linked_',result.stderr);self.assertFalse((self.base/'tmp/signals').exists());self.assertEqual(self.app.read_bytes(),self.original)
    location.unlink();self.manifest()
 def test_tampered_payload_rejected_before_backup_or_signals(self):
  (self.payload/'qml/new.qml').write_text('tampered')
  result=self.run_script('install-ui.sh');self.assertNotEqual(result.returncode,0)
  self.assertFalse((self.base/'tmp/signals').exists());self.assertFalse((self.base/'userdata/cgs2-studio-backups'/ID).exists());self.assertEqual(self.app.read_bytes(),self.original)
if __name__=='__main__':unittest.main()
