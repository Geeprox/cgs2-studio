#!/bin/sh
# SPDX-License-Identifier: MIT
# Independent local WiFi recovery; never deletes or rewrites credentials.
set -u
DIR=/tmp/cgs2-ui
mkdir -p "$DIR"; chmod 700 "$DIR"
[ -e "$DIR/weather-demo.json" ] || printf '{"enabled":false}\n' > "$DIR/weather-demo.json"
exec 9>"$DIR/recovery.lock"
tries=0
until flock -n 9;do tries=$((tries+1));[ "$tries" -lt 8 ] || exit 0;sleep 1;done
LOG=/userdata/cgs2-ui/recovery.log
last_request=$(jq -r '.id // empty' "$DIR/recovery-request.json" 2>/dev/null || true); last_recovery=-1000; failures=0; last_check=0; phase=starting; message='正在检查连接'; last_history=-60; last_time=0; clock_nonce=''; clock_count=0
up(){ cut -d . -f 1 /proc/uptime; }
log(){ [ ! -f "$LOG" ] || [ "$(wc -c < "$LOG")" -lt 65536 ] || mv "$LOG" "$LOG.1"; printf '%s %s\n' "$(date -Iseconds)" "$1" >> "$LOG"; }
status(){ printf '{"phase":"%s","message":"%s","lastRequest":"%s","uptime":%s}\n' "$phase" "$message" "$last_request" "$(up)" > "$DIR/recovery-status.new"; mv "$DIR/recovery-status.new" "$DIR/recovery-status.json"; }
disabled(){ grep -q '^wifi_disabled=true' /data/etc/setting.ini; }
healthy(){ timeout -s KILL 3 wpa_cli -i wlan0 status 9>&- 2>/dev/null | awk -F= '$1=="wpa_state" && $2=="COMPLETED"{a=1}$1=="ip_address" && $2!="0.0.0.0" && $2!=""{b=1}END{exit !(a&&b)}'; }
kernel_blocked(){
 for pid in $(pgrep -x wpa_supplicant || true);do
  if grep -q '^State:.*D' "/proc/$pid/status" 2>/dev/null && grep -q 'skw_cfg80211_assoc' "/proc/$pid/wchan" 2>/dev/null;then return 0;fi
 done
 return 1
}
blocked_status(){ phase=kernel-blocked;message='Wi-Fi 驱动阻塞，需重启设备恢复';status; }
recover(){
 if disabled; then phase=disabled;message='Wi-Fi 已关闭';status;return;fi
 if kernel_blocked;then blocked_status;return;fi
 now=$(up)
 if [ $((now-last_recovery)) -lt 60 ];then phase=cooldown;message='请稍后再试';status;return;fi
 last_recovery=$now;phase=recovering;message='正在恢复连接，保留已存网络';status;log 'recovery requested'
 if timeout -s KILL 3 wpa_cli -i wlan0 ping 9>&- 2>/dev/null | grep -q PONG;then
  timeout -s KILL 3 wpa_cli -i wlan0 reassociate 9>&- >/dev/null 2>&1 || true
  sleep 3
  if healthy;then phase=connected;message='Wi-Fi 已连接';failures=0;status;log 'reassociated';return;fi
 fi
 wd=$(for p in $(pgrep -x watchdog.sh 2>/dev/null);do [ "$(awk '{print $4}' /proc/$p/stat)" = 1 ] && [ "$(tr '\000' ' ' < /proc/$p/cmdline)" = '/bin/sh /qingping/bin/watchdog.sh ' ] && echo "$p";done)
 [ -z "$wd" ] || kill -STOP "$wd" 2>/dev/null || true
 for p in $(pgrep -x wpa_supplicant || true);do kill -CONT "$p" 2>/dev/null || true;kill -TERM "$p" 2>/dev/null || true;done
 for p in $(pgrep -x dhcpcd || true);do kill -TERM "$p" 2>/dev/null || true;done
 sleep 2
 live=0; for p in $(pgrep -x wpa_supplicant || true);do if [ -f /proc/$p/status ] && ! grep -q '^State:.*Z' /proc/$p/status;then live=1;fi;done
 if [ "$live" -eq 1 ];then
  [ -z "$wd" ] || kill -CONT "$wd" 2>/dev/null || true
  phase=error;message='连接进程未退出，可稍后重试';status;log 'station process did not exit';return
 fi
 # Reuse the exact vendor config; do not touch saved network blocks.
 if [ -s /data/cfg/wpa_supplicant.conf ] && ! disabled;then
  timeout -s KILL 6 wpa_supplicant -B -Dnl80211 -iwlan0 -c/data/cfg/wpa_supplicant.conf 9>&- >/dev/null 2>&1 || true
  timeout -s KILL 6 /etc/init.d/S41dhcpcd start 9>&- >/dev/null 2>&1 || true
 fi
 [ -z "$wd" ] || kill -CONT "$wd" 2>/dev/null || true
 for n in 1 2 3 4 5 6 7 8 9 10;do
  if healthy;then phase=connected;message='Wi-Fi 已恢复';failures=0;status;log 'station recovered';timeout -s KILL 6 /etc/init.d/S49ntp restart 9>&- >/dev/null 2>&1 || true;return;fi
  sleep 1
 done
 phase=error;message='尚未连上，请检查路由器或重试';status;log 'recovery timed out'
}
trap '[ -z "${wd:-}" ] || kill -CONT "$wd" 2>/dev/null || true; exit 0' INT TERM HUP
while :;do
 now=$(up)
 if [ $((now-last_history)) -ge 60 ];then last_history=$now;/bin/sh /userdata/cgs2-ui/history-export.sh 9>&- >/dev/null 2>&1 || true;fi
 req=$(jq -r '.id // empty' "$DIR/recovery-request.json" 2>/dev/null || true)
 case "$req" in *[!A-Za-z0-9_-]*|'') req='';; esac
 if [ -n "$req" ] && [ "$req" != "$last_request" ];then
  last_request=$req
  action=$(jq -r '.action // "recover"' "$DIR/recovery-request.json" 2>/dev/null || true)
  if [ "$action" = reboot ] && kernel_blocked;then log 'user requested reboot for blocked Wi-Fi driver';sync;/sbin/reboot -f
  else recover;fi
 fi
 if [ $((now-last_check)) -ge 30 ];then
  last_check=$now
  if disabled;then phase=disabled;message='Wi-Fi 已关闭';failures=0
  elif kernel_blocked;then phase=kernel-blocked;message='Wi-Fi 驱动阻塞，需重启设备恢复';failures=0
  elif healthy;then phase=connected;message='Wi-Fi 已连接';failures=0
  else failures=$((failures+1));phase=disconnected;message='连接中断，可点此恢复'
   if [ "$failures" -ge 3 ] && [ "$now" -gt 120 ] && grep -q 'network={' /data/cfg/wpa_supplicant.conf;then recover;fi
  fi
  status
 fi
 # Strictly authenticated NAS HTTPS Date is an optional LAN reference.
 if [ $((now-last_time)) -ge 5 ];then
  last_time=$now
  packet=$(jq -r 'select(.connected==true)|[.deviceUptime,.serverEpochMs,.lastOkUptime]|@tsv' /tmp/cgs2-micro-lan/status.json 2>/dev/null || true)
  token=$(printf '%s' "$packet" | cut -f1)
  if [ -n "$token" ] && [ "$token" != "$clock_nonce" ];then
   clock_nonce=$token
   desired=$(printf '%s' "$packet" | awk -v u="$now" '{age=u-$3;if(age>=0 && age<5 && $2>1577836800000 && $2<4102444800000)printf "%.0f",$2/1000+age}')
   if [ -n "$desired" ];then
    actual=$(date +%s);offset=$((desired-actual));abs=$offset;[ "$abs" -ge 0 ] || abs=$((-abs))
    if [ "$abs" -gt 5 ] && [ "$abs" -lt 86400 ];then
     clock_count=$((clock_count+1))
     if [ "$clock_count" -ge 3 ];then date -s "@$desired" >/dev/null 2>&1 && hwclock -w -u >/dev/null 2>&1;log "LAN clock corrected offset=${offset}s";clock_count=0;fi
    else clock_count=0;fi
   else clock_count=0;fi
  fi
 fi
 sleep 1
done
