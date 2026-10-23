#!/bin/sh
# SPDX-License-Identifier: MIT
# A complete staged transaction. No configuration, credentials or history DB writes.
set -eu
umask 077
ID=${1:-}
case "$ID" in ''|*[!a-f0-9]*) exit 2;;esac
[ ${#ID} -eq 32 ] || exit 2
STAGE=/userdata/cgs2-studio-staging/$ID
PAYLOAD=$STAGE/payload
BACKUP=/userdata/cgs2-studio-backups/$ID
UI=/userdata/cgs2-ui
APP=/qingping/bin/QingSnow2App
exec 9>/tmp/cgs2-studio-install.lock
flock -n 9 || exit 3
sha(){ sha256sum "$1" | cut -d ' ' -f1; }
fail(){ echo "$1" >&2;exit 1; }
[ "$(uname -m):$(uname -r):$(id -u)" = aarch64:4.19.232:0 ] || fail unsupported_device
[ -d "$STAGE" ] && [ ! -L "$STAGE" ] && [ ! -L "$PAYLOAD" ] || fail invalid_stage
[ ! -e "$BACKUP" ] && [ ! -L "$UI" ] && [ ! -L "$APP" ] || fail unsafe_destination
[ "$(sha "$APP")" = "$(cat "$STAGE/expected-app")" ] || fail application_changed
case "$(cat "$STAGE/expected-app")" in 1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac|91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7) :;;*) fail unknown_application;;esac
(cd "$PAYLOAD";sha256sum -c SHA256SUMS >/dev/null) || fail payload_changed
[ "$(sha "$PAYLOAD/QingSnow2App")" = 91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7 ] || fail unsupported_candidate
if [ -f /tmp/cgs2-voice/state.json ];then
 case "$(jq -r '.status' /tmp/cgs2-voice/state.json)" in starting|recording|listening|transcribing) fail voice_session_active;;esac
fi
if [ -f /tmp/cgs2-ui/screen-state.json ];then
 jq -e '.microActive!=true and .mediaActive!=true' /tmp/cgs2-ui/screen-state.json >/dev/null || fail media_or_remote_session_active
fi
[ -z "$(find "$PAYLOAD" -type l -print -quit)" ] || fail linked_payload
[ ! -d "$UI/qml" ] || [ -z "$(find "$UI/qml" -type l -print -quit)" ] || fail linked_existing_qml
free=$(df -Pk /userdata | awk 'END{print $4}')
need=$(du -sk "$PAYLOAD" | awk '{print $1}')
[ "$free" -gt $((need*2+32768)) ] || fail insufficient_backup_space
WD=''
for p in $(pgrep -x watchdog.sh);do
 [ "$(awk '{print $4}' /proc/$p/stat)" = 1 ] || continue
 [ "$(tr '\000' ' ' < /proc/$p/cmdline)" = '/bin/sh /qingping/bin/watchdog.sh ' ] || continue
 [ -z "$WD" ] || fail ambiguous_watchdog
 WD=$p
done
[ -n "$WD" ] || fail watchdog_not_identified
mkdir -p "$BACKUP/files" "$UI"
chmod 700 "$BACKUP" "$BACKUP/files" "$UI"
cp "$STAGE/managed-paths" "$BACKUP/managed-paths"
cp "$STAGE/expected-app" "$BACKUP/expected-app"
cp "$PAYLOAD/rollback-ui.sh" "$BACKUP/rollback-ui.sh"
# Every managed destination is fixed by the host package, and fenced here too.
while IFS= read -r file;do
 case "$file" in /qingping/bin/QingSnow2App|/qingping/bin/watchdog.sh|/etc/init.d/S98cgs2-ui|/userdata/cgs2-ui/recovery-agent.sh|/userdata/cgs2-ui/history-export.sh) :;;*) fail invalid_managed_path;;esac
 [ ! -L "$file" ] || fail linked_managed_file
 if [ -e "$file" ];then mkdir -p "$BACKUP/files$(dirname "$file")";cp -p "$file" "$BACKUP/files$file";sha256sum "$file" >> "$BACKUP/before.sha256";else echo "$file" >> "$BACKUP/absent";fi
done < "$BACKUP/managed-paths"
if [ -d "$UI/qml" ];then cp -a "$UI/qml" "$BACKUP/qml";fi
committed=0;mutated=0;paused=0;agent_stopped=0
cleanup(){
 trap - EXIT HUP INT TERM
 if [ "$committed" -ne 1 ] && [ "$mutated" -eq 1 ];then
  pidof QingSnow2App | xargs -r kill -TERM 2>/dev/null || true
  while IFS= read -r file;do
   if [ -f "$BACKUP/files$file" ];then cp -p "$BACKUP/files$file" "$file.studio-restore";mv "$file.studio-restore" "$file";else rm -f "$file";fi
  done < "$BACKUP/managed-paths"
  rm -rf "$UI/qml.studio-new"
  [ ! -d "$UI/qml" ] || mv "$UI/qml" "$STAGE/failed-qml"
  if [ -d "$BACKUP/qml" ];then cp -a "$BACKUP/qml" "$UI/qml";fi
 fi
 if [ "$committed" -ne 1 ] && [ "$agent_stopped" -eq 1 ] && [ -f /etc/init.d/S98cgs2-ui ];then /etc/init.d/S98cgs2-ui start >/dev/null 2>&1 || true;fi
 [ "$paused" -ne 1 ] || kill -CONT "$WD" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
[ ! -e "$UI/qml.studio-new" ] || fail stale_stage
cp -a "$PAYLOAD/qml" "$UI/qml.studio-new"
kill -STOP "$WD";paused=1
/etc/init.d/S98cgs2-ui stop >/dev/null 2>&1 || true
agent_stopped=1
OLD=$(pidof QingSnow2App)
[ "$(printf '%s\n' "$OLD" | wc -w)" -eq 1 ] || fail ambiguous_ui
kill -TERM "$OLD"
for i in 1 2 3 4 5 6 7 8 9 10;do
 [ ! -r /proc/$OLD/status ] && break
 grep -q '^State:.*Z' /proc/$OLD/status && break
 sleep 1
done
[ ! -r /proc/$OLD/status ] || grep -q '^State:.*Z' /proc/$OLD/status || fail ui_not_stopped
mutated=1
[ ! -d "$UI/qml" ] || mv "$UI/qml" "$STAGE/previous-qml"
mv "$UI/qml.studio-new" "$UI/qml"
cp "$PAYLOAD/QingSnow2App" "$APP.studio-new";chmod 755 "$APP.studio-new";mv "$APP.studio-new" "$APP"
cp "$PAYLOAD/watchdog.sh" /qingping/bin/watchdog.sh.studio-new;chmod 755 /qingping/bin/watchdog.sh.studio-new;mv /qingping/bin/watchdog.sh.studio-new /qingping/bin/watchdog.sh
for name in recovery-agent.sh history-export.sh;do cp "$PAYLOAD/$name" "$UI/$name.studio-new";chmod 755 "$UI/$name.studio-new";mv "$UI/$name.studio-new" "$UI/$name";done
cp "$PAYLOAD/S98cgs2-ui" /etc/init.d/S98cgs2-ui.studio-new;chmod 755 /etc/init.d/S98cgs2-ui.studio-new;mv /etc/init.d/S98cgs2-ui.studio-new /etc/init.d/S98cgs2-ui
# Start exactly one EGLFS application with the vendor platform/font settings.
sync;echo 3 > /proc/sys/vm/drop_caches
(cd /qingping/bin;QT_QPA_PLATFORM=eglfs QT_QPA_FONTDIR=/usr/share/fonts QT_QPA_EGLFS_ALWAYS_SET_MODE=1 QT_QPA_EGLFS_KMS_ATOMIC=1 QT_QPA_EGLFS_WIDTH=720 QT_QPA_EGLFS_HEIGHT=720 QT_QPA_EGLFS_PHYSICAL_WIDTH=720 QT_QPA_EGLFS_PHYSICAL_HEIGHT=720 QT_GSTREAMER_PLAYBIN=playbin QT_GSTREAMER_WIDGET_VIDEOSINK= QT_GSTREAMER_WINDOW_VIDEOSINK= /usr/bin/setsid "$APP" -platform eglfs </dev/null >/dev/console 2>&1 9>&- &)
/etc/init.d/S98cgs2-ui start
sleep 8
NEW=$(pidof QingSnow2App)
[ "$(printf '%s\n' "$NEW" | wc -w)" -eq 1 ] || fail new_ui_failed
[ "$(sha /proc/$NEW/exe)" = "$(sha "$APP")" ] || fail wrong_process
sleep 6
[ "$(pidof QingSnow2App)" = "$NEW" ] || fail ui_not_stable
while IFS= read -r file;do sha256sum "$file" >> "$BACKUP/installed.sha256";done < "$BACKUP/managed-paths"
(cd "$UI/qml";find . -type f -exec sha256sum {} \; | sort) > "$BACKUP/installed-qml.sha256"
sync;committed=1
kill -CONT "$WD";paused=0
printf 'CGS2_INSTALL_OK backup=%s\n' "$ID"
