#!/bin/sh
# SPDX-License-Identifier: MIT
# Reads only native air history; no mutation of the vendor database.
set -eu
OUT=/tmp/cgs2-ui/history.json
TMP=/tmp/cgs2-ui/history.new
DB=/userdata/etc/Snow2.db
now=$(date +%s);start=$((now-86400));end=$((now+300))
mkdir -p /tmp/cgs2-ui
printf '{' > "$TMP"
sep=''
for pair in airPM25:pm25 airPM10:pm10 airCO2:co2e airTVOC:tvoc airNoise:noise airTEMP:temp airHUMI:humi;do
 key=${pair%:*};table=${pair#*:}
 printf '%s"%s":[' "$sep" "$key" >> "$TMP"
 timeout -s KILL 3 sqlite3 "$DB" "PRAGMA query_only=ON;PRAGMA busy_timeout=500;SELECT timeStamp,value FROM table_${table}_data WHERE timeStamp >= $start AND timeStamp <= $end ORDER BY timeStamp LIMIT 100;" | awk -F'|' 'NF==2 && $1 ~ /^[0-9]+$/ && $2 ~ /^-?[0-9]+([.][0-9]+)?$/ {printf "%s[%s,%s]",sep,$1,$2;sep=","}' >> "$TMP"
 printf ']' >> "$TMP";sep=','
done
printf '}\n' >> "$TMP"
chmod 600 "$TMP";mv "$TMP" "$OUT"
