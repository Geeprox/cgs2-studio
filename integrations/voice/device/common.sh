#!/bin/sh
# SPDX-License-Identifier: MIT
# Shared helpers. Callers set ROOT and RUN, and use no persistent audio files.
umask 077
mkdir -p "$RUN"
chmod 700 "$RUN"
now_up(){ cut -d . -f1 /proc/uptime; }
now_millis(){ awk '{printf "%.0f\n",$1*1000}' /proc/uptime; }
valid_id(){ printf '%s' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]{1,80}$'; }
active_matches(){
 [ -f "$RUN/active.json" ] && jq -e --arg s "$SESSION" --arg n "$NONCE" '.session==$s and .nonce==$n' "$RUN/active.json" >/dev/null 2>&1
}
# All decisions about active session and visible state share this lock.
state_locked(){
 jq -n --arg s "$SESSION" --arg st "$1" --arg t "$2" --arg l "$3" --arg e "$4" --arg p "${5:-}" \
  '{session:$s,status:$st,text:($t[-1200:]),partial:($p[-1200:]),level:((try ($l|tonumber) catch 0)|if .<0 then 0 elif .>1 then 1 else . end),error:$e}' > "$RUN/state.next"
 mv "$RUN/state.next" "$RUN/state.json"
}
state_write(){
 (
  flock -x 8
  active_matches || exit 0
  if [ "$1" = error ] && [ "$4" = tail_timeout ];then
   case "$(jq -r '.status//""' "$RUN/state.json" 2>/dev/null)" in done|error) exit 0;;esac
  fi
  state_locked "$1" "$2" "$3" "$4" "${5:-}"
 ) 8>"$RUN/state.lock"
}
# Latest bounded diagnostic snapshot; callers pass only numeric measures and
# fixed error codes, never PCM, recognized text, URLs or credentials.
diagnostic_write(){
 (
  flock -x 8
  active_matches || exit 0
  [ -f "$RUN/diagnostics.json" ] || printf '{}' > "$RUN/diagnostics.json"
  jq --arg s "$SESSION" --argjson d "$1" '(if .session==$s then . else {session:$s} end)+$d' "$RUN/diagnostics.json" > "$RUN/diagnostics.next"
  mv "$RUN/diagnostics.next" "$RUN/diagnostics.json"
 ) 8>"$RUN/state.lock"
}
# End capture now; keep the same session valid only for its bounded final result.
drain_session(){
 [ -n "$SESSION" ] || return 0
 # Release the verified recorder before the several small JSON bookkeeping
 # operations. On the weak device those writes can otherwise delay Stop.
 if active_matches && worker_verified;then kill -USR1 "$W_PID" 2>/dev/null || true;fi
 (
  flock -x 8
  active_matches || exit 0
  if ! jq -e '.draining==true' "$RUN/active.json" >/dev/null;then
   jq --argjson t "$(now_up)" '.draining=true|.drainDeadline=($t+8)' "$RUN/active.json" > "$RUN/active.next"
   mv "$RUN/active.next" "$RUN/active.json"
  fi
  text=$(jq -r '.text//""' "$RUN/state.json");partial=$(jq -r '.partial//""' "$RUN/state.json")
  status=$(jq -r '.status//""' "$RUN/state.json")
  case "$status" in done|error) :;;*) state_locked transcribing "$text" 0 '' "$partial";;esac
 ) 8>"$RUN/state.lock"
}
# Verify both PID reuse fence and the actual setsid process group/session.
worker_verified(){
 [ -r "$RUN/worker.json" ] || return 1
 row=$(jq -r --arg s "$SESSION" --arg n "$NONCE" 'select(.session==$s and .nonce==$n)|[.pid,.start]|@tsv' "$RUN/worker.json" 2>/dev/null)
 W_PID=$(printf '%s' "$row" | cut -f1)
 W_START=$(printf '%s' "$row" | cut -f2)
 case "$W_PID:$W_START" in *[!0-9:]*|:*) return 1;;esac
 [ "$W_PID" -gt 1 ] 2>/dev/null || return 1
 [ -r /proc/$W_PID/stat ] || return 1
 [ "$(awk '{print $5":"$6":"$22}' /proc/$W_PID/stat)" = "$W_PID:$W_PID:$W_START" ] || return 1
 [ "$(tr '\000' '\n' < /proc/$W_PID/cmdline | sed -n '2p')" = "$ROOT/worker.sh" ] || return 1
 [ "$(tr '\000' '\n' < /proc/$W_PID/cmdline | sed -n '3p')" = "$SESSION" ] || return 1
 [ "$(tr '\000' '\n' < /proc/$W_PID/cmdline | sed -n '4p')" = "$NONCE" ] || return 1
}
terminate_worker(){
 if worker_verified;then
  kill -TERM -"$W_PID" 2>/dev/null || true
  i=0
  while [ "$i" -lt 10 ] && worker_verified;do i=$((i+1));sleep 0.1;done
  if worker_verified;then kill -KILL -"$W_PID" 2>/dev/null || true;fi
 fi
}
# Keep recognized text when stopped. Invalidate under the same state lock first,
# so a late network response cannot replace this or a later session's state.
finish_session(){
 [ -n "$SESSION" ] || return 0
 (
  flock -x 8
  active_matches || exit 0
  target_status=$1;target_error=$2
  if [ "$target_status" = error ] && [ "$target_error" = tail_timeout ];then
   latest=$(jq -r '.status//""' "$RUN/state.json" 2>/dev/null)
   case "$latest" in done|error) target_status=$latest;target_error=$(jq -r '.error//""' "$RUN/state.json" 2>/dev/null);;esac
  fi
  text=$(jq -r --arg s "$SESSION" 'if .session==$s then .text//"" else "" end' "$RUN/state.json" 2>/dev/null)
  partial=$(jq -r --arg s "$SESSION" 'if .session==$s then .partial//"" else "" end' "$RUN/state.json" 2>/dev/null)
  level=$(jq -r '.level//0' "$RUN/state.json" 2>/dev/null)
  rm -f "$RUN/active.json"
  state_locked "$target_status" "$text" 0 "$target_error" "$partial"
 ) 8>"$RUN/state.lock"
 terminate_worker
 SESSION=''
 NONCE=''
}
client_verified(){
 [ -r "$RUN/client.json" ] || return 1
 C_PID=$(jq -r '.pid//empty' "$RUN/client.json" 2>/dev/null)
 C_START=$(jq -r '.start//empty' "$RUN/client.json" 2>/dev/null)
 case "$C_PID:$C_START" in *[!0-9:]*|:*) return 1;;esac
 [ "$C_PID" -gt 1 ] 2>/dev/null || return 1
 [ -r /proc/$C_PID/stat ] || return 1
 [ "$(awk '{print $22}' /proc/$C_PID/stat)" = "$C_START" ] || return 1
 [ "$(tr '\000' '\n' < /proc/$C_PID/cmdline | sed -n '2p')" = "$ROOT/client.sh" ]
}
