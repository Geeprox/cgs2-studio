#!/bin/sh
# SPDX-License-Identifier: MIT
# Native CGS2 LAN client. No USB dependency, no inbound listener, no command retry.
set -u
umask 077
CONF=${CGS2_MICRO_CONF:-/userdata/cgs2-micro}
RUN=${CGS2_MICRO_RUN:-/tmp/cgs2-micro-lan}
# Vendor start.sh recursively resets /data modes to 666 on every boot.
# Restore the pairing store's intended private permissions before reading it.
chmod 700 "$CONF"
chmod 600 "$CONF/origin" "$CONF/ca.pem" "$CONF/auth-header"
mkdir -p "$RUN";chmod 700 "$RUN"
exec 9>"$RUN/client.lock";flock -n 9 || exit 0
printf "%s\n" "$$" > "$RUN/client.pid"
mkdir -p "$RUN/app-icons"
printf '{}\n' > "$RUN/app-icons.json"
origin=$(cat "$CONF/origin")
if ! printf '%s' "$origin" | jq -R -e '
 split("://") as $u | $u[0]=="https" and ($u|length)==2 and
 ($u[1]|split(":")) as $h | ($h|length)==2 and
 ($h[0]|split(".")) as $oct | ($oct|length)==4 and
 ([$oct[], $h[1]]|all(.[];length>0 and length<=5 and (explode|all(.[];.>=48 and .<=57)))) and
 ($oct|map(tonumber)) as $ip | ($h[1]|tonumber) as $port |
 all($ip[];.>=0 and .<=255) and (($ip|map(tostring)|join("."))==$h[0]) and ($port>=1 and $port<=65535) and
 ($ip[0]==10 or ($ip[0]==192 and $ip[1]==168) or ($ip[0]==172 and $ip[1]>=16 and $ip[1]<=31))
 ' >/dev/null 2>&1;then echo 'Only a configured HTTPS LAN IPv4 origin is supported' >&2;exit 1;fi
# Installed config is created by the pairing command, never copied from Mac admin credentials.
[ -s "$CONF/ca.pem" ] && [ -s "$CONF/auth-header" ] || exit 1
last_request=$(jq -r '.id // empty' "$RUN/request.json" 2>/dev/null || true)
lease='';nonce='';last_renew=0;last_poll=0;last_action='null';online=false;last_ok=0;server_epoch_ms=null
up(){ cut -d . -f 1 /proc/uptime; }
http(){
 method=$1;route=$2;body=${3:-}
 rm -f "$RUN/response.new"
 if [ "$method" = GET ];then
  code=$(curl --silent --show-error --proto '=https' --tlsv1.2 --cacert "$CONF/ca.pem" --header "@$CONF/auth-header" --connect-timeout 3 --max-time 5 --max-filesize 65536 --dump-header "$RUN/response.headers" --output "$RUN/response.new" --write-out '%{http_code}' "$origin$route" 2>"$RUN/network-error") || return 1
 else
  printf '%s' "$body" > "$RUN/body"
  code=$(curl --silent --show-error --proto '=https' --tlsv1.2 --cacert "$CONF/ca.pem" --header "@$CONF/auth-header" --connect-timeout 3 --max-time 5 --max-filesize 65536 --dump-header "$RUN/response.headers" --output "$RUN/response.new" --write-out '%{http_code}' -H "Origin: $origin" -H 'Content-Type: application/json' --request POST --data-binary "@$RUN/body" "$origin$route" 2>"$RUN/network-error") || return 1
 fi
 [ "$code" = 200 ] || return 1
 jq -e 'type=="object"' "$RUN/response.new" >/dev/null 2>&1
}
clear_lease(){ lease='';nonce='';last_renew=0; }
read_lease(){ lease=$(jq -r '.lease // empty' "$RUN/response.new");nonce=$(jq -r '.nonce // empty' "$RUN/response.new");last_renew=$(up);[ -n "$lease" ] && [ -n "$nonce" ]; }
release(){ if [ -n "$lease" ];then body=$(jq -cn --arg l "$lease" '{type:"release",lease:$l}');http POST /api/mac/micro/lease "$body" >/dev/null 2>&1 || true;fi;clear_lease; }
trap 'release;rm -f "$RUN/client.pid";exit 0' INT TERM HUP
sync_icon(){
 # One missing Dock icon per poll; reuse the same canonical app IDs and icon endpoint.
 ids=$(jq -r '.layout // {}|to_entries[]|.value|select(.action=="app")|.appId' "$RUN/shared-state.json" 2>/dev/null || true)
 for appid in $ids;do
  case "$appid" in ''|*[!A-Za-z0-9._-]*) continue;;esac
  [ "${#appid}" -le 128 ] || continue
  file="$RUN/app-icons/$appid.png"
  if [ ! -s "$file" ];then
   if curl --silent --show-error --fail --proto '=https' --tlsv1.2 --cacert "$CONF/ca.pem" --header "@$CONF/auth-header" --connect-timeout 2 --max-time 3 --max-filesize 524288 --output "$file.new" "$origin/api/mac/apps/icon/$appid" 2>/dev/null;then
    signature=$(od -An -tx1 -N8 "$file.new" | tr -d ' \n')
    if [ "$signature" = 89504e470d0a1a0a ] && [ "$(wc -c < "$file.new")" -le 524288 ];then mv "$file.new" "$file";fi
   fi
   rm -f "$file.new"
   break
  fi
 done
 jq -cn --arg dir "$RUN/app-icons/" --slurpfile state "$RUN/shared-state.json" '$state[0].layout // {}|to_entries|map(.value)|map(select(.action=="app"))|map({key:.appId,value:("file://"+$dir+.appId+".png")})|from_entries' > "$RUN/app-icons.json"
}
write_status(){
 now=$(up)
 if [ -f "$RUN/shared-state.json" ];then
  jq --argjson connected "$online" --argjson at "$now" --argjson lastOk "$last_ok" --argjson lastAction "$last_action" --argjson serverEpochMs "$server_epoch_ms" --slurpfile icons "$RUN/app-icons.json" '.+{appIcons:$icons[0],transport:"lan-https",connected:$connected,deviceUptime:$at,lastOkUptime:$lastOk,lastAction:$lastAction,serverEpochMs:$serverEpochMs}' "$RUN/shared-state.json" > "$RUN/status.new"
 else jq -cn --argjson at "$now" --argjson lastAction "$last_action" '{transport:"lan-https",connected:false,deviceUptime:$at,lastAction:$lastAction}' > "$RUN/status.new";fi
 mv "$RUN/status.new" "$RUN/status.json"
}
while :;do
 now=$(up)
 if [ $((now-last_poll)) -ge 2 ];then
  last_poll=$now
  if http GET /api/mac/micro;then mv "$RUN/response.new" "$RUN/shared-state.json";online=true;last_ok=$(up)
   remote_date=$(awk 'tolower($1)=="date:"{sub(/^[^:]+: */,"");gsub(/\r/,"");print;exit}' "$RUN/response.headers")
   remote_epoch=$(date -d "$remote_date" +%s 2>/dev/null || true)
   case "$remote_epoch" in ''|*[!0-9]*) server_epoch_ms=null;;*) server_epoch_ms=$((remote_epoch*1000));;esac
   sync_icon
  else online=false;clear_lease;fi
  write_status
 fi
 now=$(up)
 # Local presence is a heartbeat from the approved UI; monitor-only polling owns no control lease.
 present=$(jq -r '.uptime // 0' "$RUN/presence.json" 2>/dev/null || echo 0)
 case "$present" in ''|*[!0-9]*) present=0;;esac
 if [ -n "$lease" ];then
  if [ $((now-present)) -gt 5 ] || [ "$present" -gt "$now" ];then release
  elif [ $((now-last_renew)) -ge 5 ];then
   body=$(jq -cn --arg l "$lease" '{type:"renew",lease:$l}')
   if http POST /api/mac/micro/lease "$body";then read_lease || clear_lease;else clear_lease;fi
  fi
 fi
 cp "$RUN/request.json" "$RUN/request.snapshot" 2>/dev/null || rm -f "$RUN/request.snapshot"
 now=$(up)
 id=$(jq -r '.id // empty' "$RUN/request.snapshot" 2>/dev/null || true)
 case "$id" in ''|*[!A-Za-z0-9_-]*) id='';;esac
 if [ -n "$id" ] && [ "$id" != "$last_request" ];then
  last_request=$id;ok=false;message='操作未执行：连接已失效或控制权被占用'
  # Consume first; stale/local/reconnected requests are never queued or replayed.
  request_at=$(jq -r '.uptime // 0' "$RUN/request.snapshot" 2>/dev/null || echo 0)
  case "$request_at" in ''|*[!0-9]*) request_at=0;;esac
  if [ "$online" = true ] && [ "$request_at" -le "$now" ] && [ $((now-request_at)) -le 3 ] && [ $((now-present)) -le 5 ] && [ "$present" -le "$now" ];then
   if [ -z "$lease" ];then if http POST /api/mac/micro/lease '{"type":"acquire"}';then read_lease || clear_lease;fi;fi
   now=$(up)
   if [ -n "$lease" ] && [ $((now-request_at)) -le 3 ] && [ $((now-present)) -le 5 ];then
    body=$(jq -c --arg lease "$lease" --arg nonce "$nonce" '{id:.id,lease:$lease,nonce:$nonce,action:.action}' "$RUN/request.snapshot")
    if http POST /api/mac/micro/command "$body";then ok=true;message='Mac 已确认'
    else message='未收到执行确认；操作不会自动重试';clear_lease;fi
   fi
  fi
  last_action=$(jq -cn --arg id "$id" --argjson ok "$ok" --arg message "$message" '{id:$id,ok:$ok,message:$message}')
  write_status
 fi
 sleep 0.25
done
