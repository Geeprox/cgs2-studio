#!/bin/sh
# SPDX-License-Identifier: MIT
# Parse each event once; publish text before bounded numeric bookkeeping.
set -e
SESSION=$1
NONCE=$2
ROOT=$3
RUN=$4
. "$ROOT/common.sh"
SEQUENCE=0
TERMINAL=0
TAB=$(printf '\t')
while IFS= read -r row;do
 case "$row" in
  '') continue;;
  '__VOICE_DIAGNOSTIC__ '*)
   numbers=${row#'__VOICE_DIAGNOSTIC__ '}
   if printf '%s' "$numbers" | LC_ALL=C grep -Eq '^[0-9]+ [0-9.]+ [0-9.]+ [0-9.]+$';then
    metrics=$(jq -n --arg n "$numbers" '$n|split(" ")|map(tonumber)|{httpStatus:.[0],uploadedWireBytes:.[1],timeToHeadersMs:(.[2]*1000+0.5|floor),networkTotalMs:(.[3]*1000+0.5|floor)}')
    diagnostic_write "$metrics"
   fi
   continue;;
 esac
 [ "$TERMINAL" = 0 ] || exit 1
 if ! parsed=$(printf '%s' "$row" | jq -er --arg s "$SESSION" --argjson q "$SEQUENCE" '
  select(.session==$s and (.sequence|type=="number") and (.sequence|floor)==.sequence and .sequence>$q and .sequence<1000 and (.text|type=="string") and (.partial|type=="string") and (.level|type=="number") and ((.metrics//{})|type=="object") and (.status=="listening" or .status=="partial" or .status=="final" or .status=="done" or .status=="error"))
  | ([.sequence,.status,((.text|length)+(.partial|length)>0)]|@tsv),
    ({session:.session,status:.status,text:(.text[-1200:]),partial:(.partial[-1200:]),level:(if .status=="done" or .status=="error" then 0 else (.level|if .<0 then 0 elif .>1 then 1 else . end) end),error:(if (.error|type)=="string" then .error[:80] else "" end)}|tojson),
    ((.metrics//{}|{pcmBytesReceived,queuedFrames,maximumQueuedFrames,recognitionWindows,serverElapsedMs,lastInferenceMs,maximumInferenceMs,maximumFrameRms}|with_entries(select(.value|type=="number")))|tojson)
 ' 2>/dev/null);then
  old=$(jq -r '.text//""' "$RUN/state.json");part=$(jq -r '.partial//""' "$RUN/state.json");state_write error "$old" 0 invalid_response "$part";exit 1
 fi
 {
  IFS= read -r header
  IFS= read -r state_json
  IFS= read -r metrics_json
 } <<EOF
$parsed
EOF
 IFS="$TAB" read -r SEQUENCE STATUS HAS_TEXT <<EOF
$header
EOF
 if (
  flock -x 8
  decision=$(jq -nr --arg s "$SESSION" --arg n "$NONCE" --argjson next "$state_json" --slurpfile a "$RUN/active.json" --slurpfile old "$RUN/state.json" '
   if $a[0].session!=$s or $a[0].nonce!=$n then "stale"
   elif $old[0].session==$s and ($old[0].status=="done" or $old[0].status=="error") then "terminal"
   else $next | if .status=="done" or .status=="error" then . else .status=(if $a[0].draining==true then "transcribing" else "listening" end) end | tojson end
  ' 2>/dev/null) || exit 9
  case "$decision" in
   stale) exit 9;;
   terminal) printf 1 > "$RUN/stream-$SESSION.done";exit 0;;
  esac
  # Compact JSON safely retains tabs/newlines as escaped content, never fields.
  printf '%s\n' "$decision" > "$RUN/state.next"
  mv "$RUN/state.next" "$RUN/state.json"
  now=0
  [ "$HAS_TEXT" != true ] || now=$(now_millis)
  [ -f "$RUN/diagnostics.json" ] || printf '{}' > "$RUN/diagnostics.json"
  jq --arg s "$SESSION" --argjson d "$metrics_json" --argjson has "$HAS_TEXT" --argjson t "$now" '
   (if .session==$s then . else {session:$s} end)+$d
   | if $has and .firstTextMs==null then .firstTextMs=($t-(.beganMs//$t)) else . end
  ' "$RUN/diagnostics.json" > "$RUN/diagnostics.next"
  mv "$RUN/diagnostics.next" "$RUN/diagnostics.json"
 ) 8>"$RUN/state.lock";then :;else exit 0;fi
 case "$STATUS" in done|error) printf 1 > "$RUN/stream-$SESSION.done";TERMINAL=1;;esac
done
