#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
umask 077
ROOT=/userdata/cgs2-ui
STATE=/tmp/cgs2-media-proxy.json
EXE=$ROOT/media-proxy
exec 8>/tmp/cgs2-media-proxy.lock
flock -x 8
owned(){
 [ -f "$STATE" ] && [ ! -L "$STATE" ] || return 1
 PID=$(jq -r '.pid' "$STATE");BORN=$(jq -r '.start' "$STATE")
 case "$PID:$BORN" in *[!0-9:]*|:*) return 1;;esac
 [ "$PID" -gt 1 ] && [ -r /proc/$PID/stat ] || return 1
 [ "$(readlink /proc/$PID/exe)" = "$EXE" ] || return 1
 row=$(cat /proc/$PID/stat);rest=${row##*) }
 [ "$(printf '%s' "$rest" | awk '{print $20}')" = "$BORN" ] && [ "$(printf '%s' "$rest" | awk '{print $3}')" = "$PID" ]
}
case "${1:-}" in
 start)
  owned && exit 0
  [ -f "$EXE" ] && [ ! -L "$EXE" ] || exit 1
  chmod 755 "$EXE"
  /usr/bin/setsid "$EXE" </dev/null >/tmp/cgs2-media-proxy.log 2>&1 8>&- &
  PID=$!;sleep .2
  [ "$(readlink /proc/$PID/exe)" = "$EXE" ] || exit 1
  row=$(cat /proc/$PID/stat);rest=${row##*) };BORN=$(printf '%s' "$rest" | awk '{print $20}')
  [ "$(printf '%s' "$rest" | awk '{print $3}')" = "$PID" ] || exit 1
  printf '{"pid":%s,"start":%s}\n' "$PID" "$BORN" > "$STATE.new";mv "$STATE.new" "$STATE"
  ;;
 stop)
  if owned;then /bin/kill -TERM -"$PID" 2>/dev/null || true;fi
  rm -f "$STATE"
  ;;
 *) exit 2;;
esac
