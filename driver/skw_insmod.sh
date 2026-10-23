#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# CGS2 driver trial loader: original system modules are never overwritten.
ROOT=/userdata/cgs2-wifi-rea
chmod 700 "$ROOT"
chmod 600 "$ROOT"/* 2>/dev/null || true
ORIGINAL=/system/lib/modules/skw.ko
PATCHED="$ROOT/skw-lock-order-v1.ko"
EXPECTED=d88d8f8e807162a681201d04391b38cac139239b23f035e97d909547f1ee2ffa
insmod /system/lib/modules/skw_sdio.ko
insmod /system/lib/modules/skw_bootcoms.ko
chosen="$ORIGINAL"
mode=original
if [ -f "$ROOT/trial.once" ];then
 rm -f "$ROOT/trial.once"
 chosen="$PATCHED";mode=trial
elif [ -f "$ROOT/enabled" ];then
 if [ -f "$ROOT/boot-pending" ];then
  rm -f "$ROOT/enabled" "$ROOT/boot-pending"
  mode=previous-boot-unconfirmed-original
 else
  chosen="$PATCHED";mode=enabled
  : > "$ROOT/boot-pending"
 fi
fi
if [ "$chosen" = "$PATCHED" ];then
 actual=$(sha256sum "$PATCHED" 2>/dev/null | cut -d ' ' -f 1)
 if [ "$actual" != "$EXPECTED" ];then
  chosen="$ORIGINAL";mode=checksum-fallback
  rm -f "$ROOT/enabled" "$ROOT/boot-pending"
 fi
fi
if insmod "$chosen";then
 printf '%s loaded uptime=%s\n' "$mode" "$(cut -d . -f 1 /proc/uptime)" > "$ROOT/load-status"
else
 if [ "$chosen" != "$ORIGINAL" ];then
  rm -f "$ROOT/enabled" "$ROOT/boot-pending"
  insmod "$ORIGINAL"
  printf 'candidate-load-failed original-loaded\n' > "$ROOT/load-status"
 else
  printf 'original-load-failed\n' > "$ROOT/load-status"
 fi
fi
if [ "$mode" = enabled ];then
 (
  sleep 90
  if pidof QingSnow2App >/dev/null 2>&1 &&
     timeout -s KILL 3 wpa_cli -i wlan0 status 2>/dev/null | grep -q '^wpa_state=COMPLETED$';then
   rm -f "$ROOT/boot-pending"
  fi
 ) </dev/null >/dev/null 2>&1 &
fi
