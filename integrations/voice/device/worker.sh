#!/bin/sh
# SPDX-License-Identifier: MIT
set -e
SESSION=$1
NONCE=$2
ROOT=$3
RUN=$4
. "$ROOT/common.sh"
valid_id "$SESSION"
active_matches || exit 0
[ -n "${ARECORD:-}" ] || ARECORD=arecord
[ -n "${SOX:-}" ] || SOX=sox
[ -n "${CURL:-}" ] || CURL=curl
ORIGIN=$(jq -er '.origin|select(type=="string")' "$ROOT/config.json")
printf '%s' "$ORIGIN" | grep -Eq '^https://[A-Za-z0-9.:-]+$' || exit 2
[ -s "$ROOT/ca.pem" ] && [ -s "$ROOT/auth-header" ]
SELF=$$
START=$(awk '{print $22}' /proc/$$/stat)
[ "$(awk '{print $5":"$6}' /proc/$$/stat)" = "$$:$$" ] || exit 3
jq -n --arg s "$SESSION" --arg n "$NONCE" --argjson p "$$" --argjson t "$START" '{session:$s,nonce:$n,pid:$p,start:$t}' > "$RUN/worker.next"
mv "$RUN/worker.next" "$RUN/worker.json"
RAW_FIFO="$RUN/capture-$SESSION.pipe"
FIFO="$RUN/upload-$SESSION.pipe"
HTTP_STATUS="$RUN/http-$SESSION.status"
DONE="$RUN/stream-$SESSION.done"
RECORD_PID=''
RECORD_START=''
STOPPING=0
recording_verified(){
 [ -n "$RECORD_PID" ] && [ -n "$RECORD_START" ] && [ -r "/proc/$RECORD_PID/stat" ] && [ "$(awk '{print $3}' /proc/$RECORD_PID/stat)" != Z ] && [ "$(awk '{print $4":"$22}' /proc/$RECORD_PID/stat)" = "$SELF:$RECORD_START" ]
}
stop_capture(){
 if [ "$STOPPING" = 0 ];then STOPPING=$(now_up);if recording_verified;then kill -TERM "$RECORD_PID" 2>/dev/null || true;fi;fi
}
cleanup(){
 trap - EXIT HUP INT TERM USR1
 stop_capture
 rm -f "$RAW_FIFO" "$FIFO" "$HTTP_STATUS" "$DONE"
 kill -TERM -"$SELF" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM
trap stop_capture USR1
# Both FIFO nodes contain metadata only. Warm-up is discarded once at session
# start, while the same recorder and SoX process span every recognition window.
rm -f "$RAW_FIFO" "$FIFO"
mkfifo -m 600 "$RAW_FIFO" "$FIFO"
diagnostic_write "$(jq -n --argjson t "$(now_millis)" '{beganMs:$t,firstTextMs:null,captureExitCode:null,trimExitCode:null,curlExitCode:null,httpStatus:null,uploadedWireBytes:0,pcmBytesReceived:0,maximumQueuedFrames:0,warmupTrimSeconds:0.5}')"
(exec "$ARECORD" -q -D default -f S16_LE -r 16000 -c 1 -t raw -d 20 > "$RAW_FIFO" 2>/dev/null) &
RECORD_PID=$!
RECORD_START=$(awk '{print $22}' /proc/$RECORD_PID/stat 2>/dev/null || true)
if [ "$STOPPING" != 0 ] && recording_verified;then kill -TERM "$RECORD_PID" 2>/dev/null || true;fi
(exec "$SOX" --buffer 2048 -D -t raw -r 16000 -e signed-integer -b 16 -c 1 - -t raw -r 16000 -e signed-integer -b 16 -c 1 - trim 0.5 < "$RAW_FIFO" > "$FIFO" 2>/dev/null) &
TRIM_PID=$!
(
 if "$CURL" --silent --show-error --fail --no-buffer --http1.1 --request POST --upload-file . \
  --connect-timeout 2 --max-time 31 --max-filesize 65536 \
  --write-out '\n__VOICE_DIAGNOSTIC__ %{http_code} %{size_upload} %{time_starttransfer} %{time_total}\n' \
  --cacert "$ROOT/ca.pem" --header @"$ROOT/auth-header" \
  --header 'Expect:' --header 'Content-Type: application/octet-stream' \
  --header "X-Voice-Session: $SESSION" "$ORIGIN/stream" < "$FIFO" 2>/dev/null;then printf 0 > "$HTTP_STATUS";else code=$?;printf '%s' "$code" > "$HTTP_STATUS";fi
) | "$ROOT/consume.sh" "$SESSION" "$NONCE" "$ROOT" "$RUN" &
UPLOAD_PID=$!
while kill -0 "$UPLOAD_PID" 2>/dev/null;do
 active_matches || exit 0
 now=$(now_up)
 row=$(jq -r '[.heartbeat,.began,.client,.clientStart,(.draining//false),(.drainDeadline//0)]|@tsv' "$RUN/active.json")
 last=$(printf '%s' "$row"|cut -f1);began=$(printf '%s' "$row"|cut -f2)
 owner=$(printf '%s' "$row"|cut -f3);ownerStart=$(printf '%s' "$row"|cut -f4)
 draining=$(printf '%s' "$row"|cut -f5);deadline=$(printf '%s' "$row"|cut -f6)
 owner_alive=true
 [ -r "/proc/$owner/stat" ] && [ "$(awk '{print $22}' /proc/$owner/stat)" = "$ownerStart" ] || owner_alive=false
 if [ "$draining" != true ] && { [ $((now-last)) -ge 6 ] || [ $((now-began)) -ge 20 ] || [ "$owner_alive" = false ]; };then drain_session;draining=true;deadline=$((now+8));fi
 if [ "$draining" = true ];then
  stop_capture
  if [ "$now" -ge "$deadline" ];then old=$(jq -r '.text//""' "$RUN/state.json");part=$(jq -r '.partial//""' "$RUN/state.json");state_write error "$old" 0 tail_timeout "$part";exit 1;fi
 fi
 if [ "$STOPPING" != 0 ] && [ $((now-STOPPING)) -ge 1 ] && recording_verified;then kill -KILL "$RECORD_PID" 2>/dev/null || true;fi
 sleep 0.1
done
wait "$UPLOAD_PID" 2>/dev/null || true
WAS_STOPPING=$STOPPING
RECORD_WAS_ALIVE=false
if recording_verified;then RECORD_WAS_ALIVE=true;fi
stop_capture
RECORD_RESULT=0
wait "$RECORD_PID" 2>/dev/null || RECORD_RESULT=$?
TRIM_RESULT=0
wait "$TRIM_PID" 2>/dev/null || TRIM_RESULT=$?
HTTP_EXIT=$(cat "$HTTP_STATUS" 2>/dev/null || printf 255)
diagnostic_write "$(jq -n --argjson c "$RECORD_RESULT" --argjson x "$TRIM_RESULT" --argjson h "$HTTP_EXIT" '{captureExitCode:$c,trimExitCode:$x,curlExitCode:$h}')"
if [ "$WAS_STOPPING" = 0 ] && [ "$RECORD_WAS_ALIVE" = false ] && [ "$RECORD_RESULT" != 0 ];then
 old=$(jq -r '.text//""' "$RUN/state.json");part=$(jq -r '.partial//""' "$RUN/state.json")
 state_write error "$old" 0 capture_failed "$part"
elif [ "$TRIM_RESULT" != 0 ] && [ -f "$DONE" ];then
 old=$(jq -r '.text//""' "$RUN/state.json");part=$(jq -r '.partial//""' "$RUN/state.json")
 state_write error "$old" 0 audio_prepare_failed "$part"
elif [ ! -f "$DONE" ];then
 old=$(jq -r '.text//""' "$RUN/state.json");part=$(jq -r '.partial//""' "$RUN/state.json")
 http=$(jq -r '.httpStatus//0' "$RUN/diagnostics.json")
 previous=$(jq -r '.error//""' "$RUN/state.json")
 case "$http" in 400) error=invalid_request;;401|403) error=access_denied;;404) error=service_upgrade_required;;413) error=audio_limit;;409) error=busy;;503) error=model_loading;;502) error=recognition_failed;;*) if [ -n "$previous" ];then error=$previous;else error=connection_failed;fi;;esac
 state_write error "$old" 0 "$error" "$part"
fi
