#!/usr/bin/env bash
# 入力/表示/USBデバイスの接続状況を一目で。Hyprlandは接続中の
# キーボード/マウスを`hyprctl devices`で直接把握できるので、それを使う。
kb=0; mouse=0; disp=0

if command -v hyprctl >/dev/null 2>&1; then
  dj=$(timeout 3 hyprctl devices -j 2>/dev/null)
  if [ -n "$dj" ]; then
    kb=$(echo "$dj" | jq '.keyboards | length' 2>/dev/null)
    mouse=$(echo "$dj" | jq '.mice | length' 2>/dev/null)
  fi
  mj=$(timeout 3 hyprctl monitors -j 2>/dev/null)
  [ -n "$mj" ] && disp=$(echo "$mj" | jq 'length' 2>/dev/null)
fi
[ -z "$kb" ] && kb=0
[ -z "$mouse" ] && mouse=0
[ -z "$disp" ] && disp=0

usb=0
if command -v lsusb >/dev/null 2>&1; then
  usb=$(lsusb 2>/dev/null | grep -civ "root hub")
fi

printf '{"keyboards":%s,"mice":%s,"displays":%s,"usb":%s}\n' "$kb" "$mouse" "$disp" "$usb"
