#!/bin/sh
# SPDX-License-Identifier: MIT
# Guarded rollback: refuse when managed files have changed since installation.
set -eu
umask 077
ID=${1:-};case "$ID" in ''|*[!a-f0-9]*) exit 2;;esac
[ ${#ID} -eq 32 ] || exit 2
B=/userdata/cgs2-studio-backups/$ID
UI=/userdata/cgs2-ui
[ -d "$B" ] && [ ! -L "$B" ] && [ ! -L "$UI" ] || exit 2
exec 9>/tmp/cgs2-studio-install.lock;flock -n 9 || exit 3
sha256sum -c "$B/installed.sha256" >/dev/null
(cd "$UI/qml";find . -type f -exec sha256sum {} \; | sort) > "$B/check-qml.sha256"
cmp "$B/check-qml.sha256" "$B/installed-qml.sha256"
WD=''
for p in $(pgrep -x watchdog.sh);do
 [ "$(awk '{print $4}' /proc/$p/stat)" = 1 ] && [ "$(tr '\000' ' ' < /proc/$p/cmdline)" = '/bin/sh /qingping/bin/watchdog.sh ' ] || continue
 [ -z "$WD" ] || exit 2;WD=$p
done
[ -n "$WD" ] || exit 2
trap 'kill -CONT "$WD" 2>/dev/null || true' EXIT
trap 'exit 1' HUP INT TERM
kill -STOP "$WD"
/etc/init.d/S98cgs2-ui stop >/dev/null 2>&1 || true
pidof QingSnow2App | xargs -r kill -TERM
sleep 3
for p in $(pidof QingSnow2App);do grep -q '^State:.*Z' /proc/$p/status || exit 2;done
while IFS= read -r file;do
 case "$file" in /qingping/bin/QingSnow2App|/qingping/bin/watchdog.sh|/etc/init.d/S98cgs2-ui|/userdata/cgs2-ui/recovery-agent.sh|/userdata/cgs2-ui/history-export.sh) :;;*) exit 2;;esac
 [ ! -L "$file" ] || exit 2
 if [ -f "$B/files$file" ];then cp -p "$B/files$file" "$file.studio-restore";mv "$file.studio-restore" "$file";else rm -f "$file";fi
done < "$B/managed-paths"
[ ! -e "$UI/qml.studio-removed" ] || exit 2
mv "$UI/qml" "$UI/qml.studio-removed"
if [ -d "$B/qml" ];then cp -a "$B/qml" "$UI/qml";fi
sync;echo 3 > /proc/sys/vm/drop_caches
[ ! -f /etc/init.d/S98cgs2-ui ] || /etc/init.d/S98cgs2-ui start
kill -CONT "$WD"
printf 'CGS2_ROLLBACK_OK; preferences and original driver retained\n'
