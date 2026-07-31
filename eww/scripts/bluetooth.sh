#!/usr/bin/env bash
# Bluetooth: 電源ON/OFF + 接続中デバイス一覧。
powered="false"
devices="[]"

if command -v bluetoothctl >/dev/null 2>&1; then
  show=$(timeout -k 1 2 bluetoothctl show 2>/dev/null)
  if echo "$show" | grep -q "Powered: yes"; then
    powered="true"
    connected=$(timeout -k 1 2 bluetoothctl devices Connected 2>/dev/null)
    if [ -n "$connected" ]; then
      list="["
      sep=""
      while IFS= read -r line; do
        name=$(echo "$line" | cut -d' ' -f3- | sed 's/"/\\"/g')
        [ -z "$name" ] && continue
        list="$list$sep{\"name\":\"$name\"}"
        sep=","
      done <<< "$connected"
      list="$list]"
      devices="$list"
    fi
  fi
fi

count=$(echo "$devices" | jq 'length' 2>/dev/null)
[ -z "$count" ] && count=0
printf '{"powered":%s,"devices":%s,"count":%s}\n' "$powered" "$devices" "$count"
