#!/bin/sh
# SPDX-License-Identifier: MIT
# Foreground-only, bounded album cache. No URL/credential/body logging.
set -u
umask 077
RUN=/tmp/cgs2-media
CONF=/userdata/cgs2-media
# Backward-compatible read of an existing shared gateway pairing.
[ -f "$CONF/origin" ] || CONF=/userdata/cgs2-micro
VIDEO_DIR=/userdata/cgs2-ui/cache/media
mkdir -p "$RUN/cache" "$VIDEO_DIR"
chmod 700 "$RUN" "$RUN/cache" "$VIDEO_DIR"
exec 9>"$RUN/client.lock"
flock -n 9 || exit 0
origin=$(cat "$CONF/origin")
if ! printf '%s' "$origin" | jq -R -e '
 split("://") as $u | $u[0]=="https" and ($u|length)==2 and
 ($u[1]|split(":")) as $h | ($h|length)==2 and
 ($h[0]|split(".")) as $oct | ($oct|length)==4 and
 ([$oct[], $h[1]]|all(.[];length>0 and length<=5 and (explode|all(.[];.>=48 and .<=57)))) and
 ($oct|map(tonumber)) as $ip | ($h[1]|tonumber) as $port |
 all($ip[];.>=0 and .<=255) and (($ip|map(tostring)|join("."))==$h[0]) and ($port>=1 and $port<=65535) and
 ($ip[0]==10 or ($ip[0]==192 and $ip[1]==168) or ($ip[0]==172 and $ip[1]>=16 and $ip[1]<=31))
 ' >/dev/null 2>&1;then exit 1;fi
up(){ cut -d . -f1 /proc/uptime; }
present(){
 row=$(jq -r 'select(.active!=false)|.uptime//0' "$RUN/presence.json" 2>/dev/null || true)
 case "$row" in ''|*[!0-9]*) return 1;;esac
 now=$(up)
 [ "$row" -le "$now" ] && [ $((now-row)) -le 7 ]
}
valid_id(){ printf '%s' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]{1,80}$'; }
last_request=$(jq -r '.id//empty' "$RUN/request.json" 2>/dev/null || true)
last_poll=-60
offset=0
source_page=-1
media_kind=all
seen='[]'
shuffle_left='[]'
next_index=-1
next_page=0
next_id=''
has_previous=true
selected=0
revision=''
error=''
busy=false
ready_video=''
was_present=false
get(){
 route=$1;dest=$2;limit=$3;seconds=$4
 curl --silent --fail --proto '=https' --tlsv1.2 --cacert "$CONF/ca.pem" --header "@$CONF/auth-header" --connect-timeout 3 --max-time "$seconds" --max-filesize "$limit" --output "$dest.new" "$origin$route" </dev/null 2>/dev/null 9>&- &
 child=$!
 canceled=false
 while kill -0 "$child" 2>/dev/null;do
  sleep 0.25
  newest=$(jq -r '.id//empty' "$RUN/request.json" 2>/dev/null || true)
  if ! present || [ "$newest" != "$last_request" ];then
   kill -TERM "$child" 2>/dev/null || true
   canceled=true
   break
  fi
 done
 result=0
 wait "$child" || result=$?
 if [ "$canceled" = true ];then rm -f "$dest.new";return 2;fi
 if [ "$result" -ne 0 ];then rm -f "$dest.new";return 1;fi
 mv "$dest.new" "$dest"
}
clear_videos(){
 for old in "$VIDEO_DIR/"*.mp4 "$VIDEO_DIR/"*.mp4.new;do
  [ -f "$old" ] || continue
  name=${old##*/}
  if printf '%s' "$name" | LC_ALL=C grep -Eq '^[a-f0-9]{24}-[0-9]{1,12}\.mp4(\.new)?$';then rm -f "$old";fi
 done
}
clear_videos
status(){
 cached=''
 if [ -n "$revision" ];then
  for file in "$RUN/cache/$revision"-*.jpg;do
   [ -s "$file" ] || continue
   name=${file##*/};id=${name#"$revision"-};id=${id%.jpg}
   case "$id" in ''|*[!0-9]*) continue;;esac
   cached="$cached$id\n"
  done
 fi
 ids=$(printf '%b' "$cached" | jq -Rsc 'split("\n")|map(select(length>0))')
 video_ids=$(for file in "$VIDEO_DIR/$revision"-*.mp4;do [ -s "$file" ] || continue;name=${file##*/};name=${name#"$revision"-};name=${name%.mp4};printf '%s\n' "$name";done | jq -Rsc 'split("\n")|map(select(length>0 and length<=12 and (explode|all(.[];.>=48 and .<=57))))')
 stamp=$(awk '{printf "%.0f",$1*1000}' /proc/uptime)
 if [ -s "$RUN/remote.json" ];then
  jq --arg run "file://$RUN/cache/" --arg videoRun "file://$VIDEO_DIR/" --arg proxy 'http://127.0.0.1:6097/media/' --arg rev "$revision" --arg err "$error" --arg ack "$last_request" --argjson busy "$busy" --argjson current "$selected" --arg ready "$ready_video" --argjson videoIds "$video_ids" --argjson cached "$ids" --argjson stamp "$stamp" --arg kind "$media_kind" --arg nextId "$next_id" --argjson hasPrevious "$has_previous" --argjson nextIndex "$next_index" --argjson nextPage "$next_page" '
   .+{hasPrevious:$hasPrevious,nextPreview:(if ($cached|index($nextId)!=null) then $run+$rev+"-"+$nextId+".jpg" else "" end),mediaKind:$kind,nextIndex:$nextIndex,nextPage:$nextPage,protocol:2,stateUptimeMs:$stamp,requestId:$ack,error:$err,busy:$busy,current:$current,readyVideoId:$ready}|
   .items=(.items//[]|map(.id as $id|.+{previewReady:($cached|index($id)!=null),preview:(if ($cached|index($id)!=null) then $run+$rev+"-"+$id+".jpg" else "" end),liveReady:(.live==true and ($videoIds|index($id)!=null)),playback:(if .live==true and ($videoIds|index($id)!=null) then $videoRun+$rev+"-"+$id+".mp4" elif (.kind=="video" or .kind=="audio") and .id==$ready then (if .streamable==true then $proxy+$id+"?revision="+$rev else $videoRun+$rev+"-"+$id+".mp4" end) else "" end)}))
  ' "$RUN/remote.json" > "$RUN/manifest.next"
 else
  jq -n --arg kind "$media_kind" --arg err "$error" --arg ack "$last_request" --argjson stamp "$stamp" '{mediaKind:$kind,protocol:2,stateUptimeMs:$stamp,requestId:$ack,enabled:false,items:[],current:0,busy:false,error:$err}' > "$RUN/manifest.next"
 fi
 if [ ! -s "$RUN/manifest.next" ] || ! jq -e 'type=="object" and (.items|type)=="array"' "$RUN/manifest.next" >/dev/null 2>&1;then rm -f "$RUN/manifest.next";return 1;fi
 mv "$RUN/manifest.next" "$RUN/manifest.json"
}
load(){
 result=0
 get "/api/media/manifest?offset=$offset&kind=$media_kind" "$RUN/remote.next" 65536 15 || result=$?
 if [ "$result" -eq 2 ];then return 2;fi
 if [ "$result" -ne 0 ] || ! jq -e 'type=="object" and (.items|type)=="array"' "$RUN/remote.next" >/dev/null 2>&1;then
  error='相册暂不可用，请检查 NAS 与网页配置';last_poll=$(up);status;return 1
 fi
 if ! jq --arg kind "$media_kind" '{total:(if .mediaKind==$kind and (.total|type)=="number" and .total>=0 and .total<=10000 then .total else null end),enabled:(.enabled==true),revision:(.revision//""),albumName:(.albumName//"相册与视频"),intervalMs:((.intervalMs//10000)|if .<3000 then 3000 elif .>60000 then 60000 else . end),offset:(.offset//0),hasMore:(.hasMore==true),items:(.items|map(select((.id|type)=="string" and (.id|length)>0 and (.id|length)<=12 and (.id|explode|all(.[];.>=48 and .<=57)) and (.kind=="photo" or .kind=="video" or .kind=="audio") and ($kind=="all" or .kind==$kind)))|.[0:24])}' "$RUN/remote.next" > "$RUN/remote.clean";then
  error='相册数据暂不可用';status;return 1
 fi
 source_page=$offset
 next=$(jq -r '.revision' "$RUN/remote.clean")
 case "$next" in *[!a-f0-9]*|'') next='';;esac
 enabled=$(jq -r '.enabled' "$RUN/remote.clean")
 if [ "$enabled" = true ] && [ "${#next}" -ne 24 ];then error='相册版本暂不可用';status;return 1;fi
 if [ "$revision" != "$next" ];then rm -f "$RUN/cache/"*.jpg;clear_videos;ready_video='';fi
 if [ "$revision" != "$next" ];then seen='[]';shuffle_left='[]';fi
 revision=$next
 mv "$RUN/remote.clean" "$RUN/remote.json"
 rm -f "$RUN/remote.next"
 error='';last_poll=$(up)
}
image(){
 index=$1
 id=$(jq -r --argjson n "$index" '.items[$n].id//empty' "$RUN/remote.json" 2>/dev/null || true)
 case "$id" in ''|*[!0-9]*) return 0;;esac
 file="$RUN/cache/$revision-$id.jpg"
 if [ ! -s "$file" ];then
  result=0
  get "/api/media/item/$id/preview?revision=$revision" "$file" 4194304 15 || result=$?
  [ "$result" -eq 0 ] || return "$result"
 fi
 touch "$file"
}
prune(){
 ls -t "$RUN/cache/"*.jpg 2>/dev/null | tail -n +5 | while IFS= read -r old;do rm -f "$old";done
}
prepare_live(){
 live_id=$1
 file="$VIDEO_DIR/$revision-$live_id.mp4"
 if [ ! -s "$file" ];then get "/api/media/item/$live_id/video?revision=$revision" "$file" 33554432 55 || return;fi
 touch "$file"
 ls -t "$VIDEO_DIR/$revision"-*.mp4 2>/dev/null | tail -n +3 | while IFS= read -r old;do rm -f "$old";done
}
fetch_selected(){
 # Photos authorizes only the last listed page. A sparse backward search may
 # restore the previous view; re-authorize it before an evicted preview is read.
 if [ "$source_page" -ne "$offset" ];then
  get "/api/media/manifest?offset=$offset&kind=$media_kind" "$RUN/authorize.json" 65536 15 || return
  if [ "$(jq -r '.revision' "$RUN/authorize.json")" != "$revision" ];then error='媒体选择已更新，请重试';status;return 1;fi
  source_page=$offset
 fi
 count=$(jq '.items|length' "$RUN/remote.json")
 if [ "$selected" -ge "$count" ];then selected=$((count>0?count-1:0));fi
 [ -n "$revision" ] || return 0
 # Cached navigation is ready immediately; do not publish a spurious busy state.
 id=$(jq -r --argjson n "$selected" '.items[$n].id//empty' "$RUN/remote.json")
 busy=false
 if [ ! -s "$RUN/cache/$revision-$id.jpg" ] || [ "${1:-false}" = true ];then busy=true;fi
 error='';status
 result=0
 image "$selected" || result=$?
 if [ "$result" -eq 2 ];then busy=false;return 2;fi
 if [ "$result" -ne 0 ];then busy=false;error='照片预览暂不可用，请重试';status;return 1;fi
 if [ "${1:-false}" = true ];then
  id=$(jq -r --argjson n "$selected" '.items[$n]|if .kind=="video" or .kind=="audio" or .live==true then .id else "" end' "$RUN/remote.json")
  case "$id" in ''|*[!0-9]*) busy=false;error='当前项目不是视频';status;return 1;;esac
  live=$(jq -r --argjson n "$selected" '.items[$n].live==true' "$RUN/remote.json")
  if [ "$live" = true ];then
   result=0;prepare_live "$id" || result=$?
   if [ "$result" -eq 2 ];then busy=false;return 2;fi
   if [ "$result" -ne 0 ];then busy=false;error='动态预览暂不可用，将保留照片';status;return 1;fi
   ready_video=$id;busy=false;error='';status;return 0
  fi
  streamable=$(jq -r --argjson n "$selected" '.items[$n].streamable==true' "$RUN/remote.json")
  if [ "$streamable" = true ];then ready_video=$id;busy=false;error='';status;return 0;fi
  file="$VIDEO_DIR/$revision-$id.mp4"
  if [ ! -s "$file" ];then
   ready_video='';clear_videos
   available=$(df -Pk "$VIDEO_DIR" | awk 'NR==2{print $4}')
   if [ "${available:-0}" -lt 73728 ];then busy=false;error='设备临时空间不足，暂时无法准备视频';status;return 1;fi
   result=0
   get "/api/media/item/$id/video?revision=$revision" "$file" 67108864 65 || result=$?
   if [ "$result" -eq 2 ];then busy=false;return 2;fi
   if [ "$result" -ne 0 ];then busy=false;error='视频预览不可用；请使用 NAS 的 H.264 兼容预览（64 MB以内）';status;return 1;fi
  fi
  ready_video=$id
 fi
 busy=false;error='';prune;status
}
choose_next(){
 next_index=-1;next_id='';next_page=$offset
 [ "$media_kind" = photo ] || return 0
 total=$(jq -r '.total//0' "$RUN/remote.json")
 if [ "$total" -gt 1 ];then
  absolute=$((offset+selected))
  shuffle_left=$(printf '%s' "$shuffle_left" | jq -c --argjson i "$absolute" 'map(select(.!=$i))')
  count=$(printf '%s' "$shuffle_left" | jq length)
  if [ "$count" -eq 0 ];then shuffle_left=$(jq -cn --argjson total "$total" --argjson i "$absolute" '[range(0;$total)|select(.!=$i)]');count=$((total-1));fi
  random=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
  absolute=$(printf '%s' "$shuffle_left" | jq -r --argjson n "$((random%count))" '.[$n]')
  next_page=$((absolute/24*24));next_index=$((absolute%24));return 0
 fi
 # Keep a shuffled bag for this page; never immediately repeat a photo.
 id=$(jq -r --argjson n "$selected" '.items[$n].id//empty' "$RUN/remote.json")
 seen=$(printf '%s' "$seen" | jq -c --arg id "$id" '.+[$id]|unique')
 choices=$(jq -c --argjson seen "$seen" '[.items|to_entries[]|select(.value.kind=="photo" and (.value.id as $id|$seen|index($id)|not))|.key]' "$RUN/remote.json")
 count=$(printf '%s' "$choices" | jq length)
 if [ "$count" -eq 0 ];then
  if [ "$(jq -r '.hasMore' "$RUN/remote.json")" = true ];then next_page=$((offset+24));return 0;fi
  if [ "$offset" -gt 0 ];then next_page=0;return 0;fi
  seen=$(jq -cn --arg id "$id" '[$id]')
  choices=$(jq -c --arg id "$id" '[.items|to_entries[]|select(.value.id!=$id and .value.kind=="photo")|.key]' "$RUN/remote.json")
  count=$(printf '%s' "$choices" | jq length)
 fi
 [ "$count" -gt 0 ] || return 0
 random=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
 next_index=$(printf '%s' "$choices" | jq -r --argjson n "$((random%count))" '.[$n]')
}
warm_page(){
 # Prepare a randomized item on the following page without changing the view.
 warm=$next_page;planned_index=$next_index;steps=0
 while [ "$steps" -lt 208 ];do
  get "/api/media/manifest?offset=$warm&kind=$media_kind" "$RUN/warm.json" 65536 15 || return
  source_page=$warm
  [ "$(jq -r '.revision' "$RUN/warm.json")" = "$revision" ] || return
  jq '.items=[.items[]|select(.kind=="photo" and (.id|type)=="string" and (.id|length>0 and length<=12 and (explode|all(.[];.>=48 and .<=57))))]' "$RUN/warm.json" > "$RUN/warm.clean"
  count=$(jq '.items|length' "$RUN/warm.clean")
  if [ "$count" -gt 0 ];then
   random=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
   candidate=$((random%count));if [ "$planned_index" -ge 0 ] && [ "$planned_index" -lt "$count" ];then candidate=$planned_index;fi
   id=$(jq -r --argjson n "$candidate" '.items[$n].id' "$RUN/warm.clean")
   file="$RUN/cache/$revision-$id.jpg"
   if [ ! -s "$file" ];then get "/api/media/item/$id/preview?revision=$revision" "$file" 4194304 15 || return;fi
   next_page=$warm;next_index=$candidate;next_id=$id
   return
  fi
  [ "$(jq -r '.hasMore' "$RUN/warm.clean")" = true ] || return
  warm=$((warm+24));steps=$((steps+1))
 done
}
prefetch(){
 count=$(jq '.items|length' "$RUN/remote.json" 2>/dev/null || echo 0)
 if [ "$media_kind" = photo ];then
  choose_next
  if [ "$next_page" -ne "$offset" ];then warm_page || true;fi
  if [ "$next_page" = "$offset" ] && [ "$next_index" -ge 0 ];then next_id=$(jq -r --argjson n "$next_index" '.items[$n].id' "$RUN/remote.json");fi
  if [ "$next_page" = "$offset" ];then candidates="$next_index";else candidates="";fi
 else candidates="$((selected+1)) $((selected+2))";fi
 # A one-page album also warms its first image before the last dwell ends.
 if [ "$media_kind" != photo ] && [ "$offset" -eq 0 ] && [ "$selected" -ge $((count-2)) ] && [ "$(jq -r '.hasMore' "$RUN/remote.json")" = false ];then candidates="$candidates 0";fi
 count=$(jq '.items|length' "$RUN/remote.json")
 for candidate in $candidates;do
  [ "$candidate" -ge 0 ] && [ "$candidate" -lt "$count" ] || continue
  result=0;image "$candidate" || result=$?
  [ "$result" -eq 2 ] && return 2
  # Publish the next photo as soon as it is ready, before fetching another.
  # Keep the displayed photo newest so the four-file cache cannot evict it.
  current_id=$(jq -r --argjson n "$selected" '.items[$n].id//empty' "$RUN/remote.json")
  [ -z "$current_id" ] || touch "$RUN/cache/$revision-$current_id.jpg"
  prune;status
 done
 if [ "$media_kind" = photo ] && [ -n "$next_id" ] && [ "$next_index" -ge 0 ];then
  next_file="$RUN/remote.json";[ "$next_page" = "$offset" ] || next_file="$RUN/warm.clean"
  if jq -e --argjson n "$next_index" '.items[$n].live==true' "$next_file" >/dev/null;then prepare_live "$next_id" || true;fi
 fi
 # Touch the displayed image last so bounded eviction cannot remove it.
 id=$(jq -r --argjson n "$selected" '.items[$n].id//empty' "$RUN/remote.json" 2>/dev/null || true)
 [ -z "$id" ] || touch "$RUN/cache/$revision-$id.jpg"
 prune;status
}
status
while :;do
 if present;then
  was_present=true
  cp "$RUN/request.json" "$RUN/request.snapshot" 2>/dev/null || true
  row=$(jq -r 'select(.protocol==2 and (.id|type)=="string" and (.uptime|type)=="number" and .uptime>=0 and .uptime<=2147483647 and .uptime==(.uptime|floor) and (.page|type)=="number" and .page>=0 and .page<=100000 and .page==(.page|floor) and (.index|type)=="number" and .index>=0 and .index<24 and .index==(.index|floor) and (.video|type)=="boolean")|[.id,.uptime,.page,.index,.video,(.force==true)]|@tsv' "$RUN/request.snapshot" 2>/dev/null || true)
  id=$(printf '%s' "$row" | cut -f1)
  if [ -n "$id" ] && [ "$id" != "$last_request" ] && valid_id "$id";then
   last_request=$id
   requested_kind=$(jq -r '.kind//"all"|select(.=="all" or .=="photo" or .=="video" or .=="audio")' "$RUN/request.snapshot")
   [ -n "$requested_kind" ] || continue
   kind_changed=false
   if [ "$media_kind" != "$requested_kind" ];then media_kind=$requested_kind;kind_changed=true;has_previous=true;seen='[]';shuffle_left='[]';next_index=-1;fi
   stamp=$(printf '%s' "$row" | cut -f2);page=$(printf '%s' "$row" | cut -f3);index=$(printf '%s' "$row" | cut -f4);video=$(printf '%s' "$row" | cut -f5);force=$(printf '%s' "$row" | cut -f6)
   now=$(up);age=$((now-stamp))
   if [ "$age" -ge 0 ] && [ "$age" -le 7 ] && [ "$page" -ge 0 ] && [ "$page" -le 100000 ] && [ $((page%24)) -eq 0 ] && [ "$index" -ge 0 ] && [ "$index" -lt 24 ];then
    old_selected=$selected
    selected=$index;error='';next_index=-1;next_id=''
    old_offset=$offset
    cp "$RUN/remote.json" "$RUN/previous.json" 2>/dev/null || true
    if [ "$kind_changed" = true ] || [ "$source_page" -ne "$page" ] || [ "$offset" -ne "$page" ] || [ ! -s "$RUN/remote.json" ] || [ $((now-last_poll)) -ge 30 ];then
     offset=$page
     if [ "$old_offset" -ne "$offset" ];then seen='[]';fi
     load || { sleep 0.25;continue; }
     # Walk sparse type-specific pages in the requested direction.
     steps=0
     while [ "$(jq '.items|length' "$RUN/remote.json")" -eq 0 ] && [ "$steps" -lt 208 ];do
      if [ "$kind_changed" = false ] && [ "$page" -lt "$old_offset" ] && [ "$offset" -gt 0 ];then offset=$((offset-24))
      elif { [ "$kind_changed" = true ] || [ "$page" -ge "$old_offset" ]; } && [ "$(jq -r '.hasMore' "$RUN/remote.json")" = true ];then offset=$((offset+24))
      else break;fi
      steps=$((steps+1));load || break
     done
     if [ "$(jq '.items|length' "$RUN/remote.json")" -eq 0 ] && [ "$kind_changed" = false ] && [ -s "$RUN/previous.json" ];then
      cp "$RUN/previous.json" "$RUN/remote.json";offset=$old_offset;selected=$old_selected
      if [ "$page" -lt "$old_offset" ];then has_previous=false
      else jq '.hasMore=false' "$RUN/remote.json" > "$RUN/remote.clean";mv "$RUN/remote.clean" "$RUN/remote.json";fi
     fi
    fi
    if [ "$offset" -gt "$old_offset" ] && [ "$(jq '.items|length' "$RUN/remote.json")" -gt 0 ];then has_previous=true;fi
    if [ "$force" = true ];then
     item=$(jq -r --argjson n "$selected" '.items[$n].id//empty' "$RUN/remote.json")
     case "$item" in ''|*[!0-9]*) ;;*) rm -f "$RUN/cache/$revision-$item.jpg";;esac
    fi
    fetch_selected "$video" && prefetch || true
   fi
  elif [ $(( $(up)-last_poll )) -ge 30 ];then
   if load;then fetch_selected false && prefetch || true;fi
  fi
  sleep 0.25
 else
  if [ "$was_present" = true ];then ready_video='';busy=false;clear_videos;status;was_present=false;fi
  sleep 1
 fi
done
