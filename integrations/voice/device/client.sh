#!/bin/sh
# SPDX-License-Identifier: MIT
set -e
ROOT=$1
RUN=$2
. "$ROOT/common.sh"
exec 9>"$RUN/client.lock"
flock -n 9 || exit 0
SESSION=''
NONCE=''
# Never replay the request that was present when the service started.
LAST_ID=$(jq -r '.id//empty' "$RUN/request.json" 2>/dev/null || true)
if [ -f "$RUN/active.json" ];then
 SESSION=$(jq -r '.session//empty' "$RUN/active.json")
 NONCE=$(jq -r '.nonce//empty' "$RUN/active.json")
 finish_session done ''
fi
jq -n --argjson p "$$" --argjson t "$(awk '{print $22}' /proc/$$/stat)" '{pid:$p,start:$t}' > "$RUN/client.next"
mv "$RUN/client.next" "$RUN/client.json"
if [ ! -f "$RUN/state.json" ];then SESSION='';state_locked idle '' 0 '';fi
cleanup(){ trap - EXIT HUP INT TERM;drain_session;i=0;while [ "$i" -lt 80 ] && worker_verified;do i=$((i+1));sleep 0.1;done;status=$(jq -r '.status//"done"' "$RUN/state.json" 2>/dev/null);error=$(jq -r '.error//""' "$RUN/state.json" 2>/dev/null);[ "$status" = error ] || status=done;finish_session "$status" "$error";rm -f "$RUN/client.json"; }
trap cleanup EXIT
trap 'exit 0' HUP INT TERM
begin_session(){
 if [ -n "$SESSION" ] && worker_verified;then return 0;fi
 finish_session done ''
 SESSION=$1
 NONCE=$(cat /proc/sys/kernel/random/uuid)
 now=$(now_up)
 (
  flock -x 8
  jq -n --arg s "$SESSION" --arg n "$NONCE" --argjson t "$now" --argjson p "$$" --argjson ps "$(awk '{print $22}' /proc/$$/stat)" \
    '{session:$s,nonce:$n,began:$t,heartbeat:$t,client:$p,clientStart:$ps}' > "$RUN/active.next"
  mv "$RUN/active.next" "$RUN/active.json"
  state_locked starting '' 0 ''
 ) 8>"$RUN/state.lock"
 # BusyBox setsid may fork. The worker records its actual SID/PID itself.
 /usr/bin/setsid "$ROOT/worker.sh" "$SESSION" "$NONCE" "$ROOT" "$RUN" </dev/null >/dev/null 2>&1 9>&- &
 i=0
 while [ "$i" -lt 10 ] && ! worker_verified;do i=$((i+1));sleep 0.1;done
 if ! worker_verified;then finish_session error capture_start_failed;fi
}
while :;do
 now=$(now_up)
 row=$(jq -r 'select((.id|type=="string") and (.action=="start" or .action=="keepalive" or .action=="stop") and (.uptime|type=="number") and (.uptime|floor)==.uptime and .uptime>=0 and .uptime<=2147483647)|[.id,.action,.uptime,(.session//"")]|@tsv' "$RUN/request.json" 2>/dev/null || true)
 id=$(printf '%s' "$row" | cut -f1)
 action=$(printf '%s' "$row" | cut -f2)
 stamp=$(printf '%s' "$row" | cut -f3)
 target=$(printf '%s' "$row" | cut -f4)
 if valid_id "$id" && [ "$id" != "$LAST_ID" ];then
  LAST_ID=$id
  age=$((now-stamp))
  if [ "$age" -ge 0 ] && [ "$age" -le 5 ];then
   case "$action" in
    start) begin_session "$id";;
    stop) [ "$target" != "$SESSION" ] || drain_session;;
    keepalive)
     if [ -n "$SESSION" ] && [ "$target" = "$SESSION" ];then
      (flock -x 8;active_matches || exit 0;jq --argjson t "$now" '.heartbeat=$t' "$RUN/active.json" > "$RUN/active.next";mv "$RUN/active.next" "$RUN/active.json") 8>"$RUN/state.lock"
     fi;;
   esac
  fi
 fi
 if [ -n "$SESSION" ];then
  now=$(now_up)
  last=$(jq -r '.heartbeat' "$RUN/active.json" 2>/dev/null || echo 0)
  began=$(jq -r '.began' "$RUN/active.json" 2>/dev/null || echo 0)
  draining=$(jq -r '.draining//false' "$RUN/active.json" 2>/dev/null)
  deadline=$(jq -r '.drainDeadline//0' "$RUN/active.json" 2>/dev/null)
  if [ "$draining" = true ] && [ "$now" -ge "$deadline" ];then finish_session error tail_timeout
  elif ! worker_verified;then
   status=$(jq -r '.status//"error"' "$RUN/state.json" 2>/dev/null)
   error=$(jq -r '.error//"capture_stopped"' "$RUN/state.json" 2>/dev/null)
   [ "$status" = error ] || status=done
   finish_session "$status" "$error"
  elif [ "$draining" != true ] && { [ $((now-last)) -ge 6 ] || [ $((now-began)) -ge 20 ]; };then drain_session
  fi
 fi
 sleep 0.2
done
