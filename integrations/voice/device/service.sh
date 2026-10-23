#!/bin/sh
# SPDX-License-Identifier: MIT
set -e
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUN=/tmp/cgs2-voice
[ -z "$VOICE_RUN" ] || RUN=$VOICE_RUN
. "$ROOT/common.sh"
if [ "$1" = restart ];then "$0" stop;exec "$0" start;fi
exec 7>"$RUN/service.lock"
flock -x 7
case "$1" in
 start)
  client_verified && exit 0
  /usr/bin/setsid "$ROOT/client.sh" "$ROOT" "$RUN" </dev/null >/dev/null 2>&1 7>&- &
  i=0
  while [ "$i" -lt 20 ];do sleep 0.1;i=$((i+1));client_verified && exit 0;done
  exit 1;;
 stop)
  if client_verified;then
   kill -TERM "$C_PID"
   i=0
   while [ "$i" -lt 100 ] && client_verified;do sleep 0.1;i=$((i+1));done
  fi
  if [ -f "$RUN/active.json" ];then
   SESSION=$(jq -r '.session//empty' "$RUN/active.json")
   NONCE=$(jq -r '.nonce//empty' "$RUN/active.json")
   finish_session done ''
  fi
  if client_verified;then kill -KILL "$C_PID";fi;;
 status) client_verified && echo running || echo stopped;;
 *) echo 'usage: service.sh start|stop|restart|status' >&2;exit 2;;
esac
