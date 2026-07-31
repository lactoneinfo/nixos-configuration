#!/usr/bin/env bash
# 実測の回線速度(down/up Mbps・ping)。帯域を消費する重い処理なので、
# eww側は長いinterval(10分)でしか叩かない設計。
out=$(timeout 30 speedtest-cli --simple 2>/dev/null)
if [ -z "$out" ]; then
  printf '{"ping":"—","down":"—","up":"—","ok":0,"ts":"%s"}\n' "$(date +%H:%M)"
  exit 0
fi
ping=$(echo "$out" | awk '/^Ping/{printf "%.0f", $2}')
down=$(echo "$out" | awk '/^Download/{printf "%.0f", $2}')
up=$(echo "$out" | awk '/^Upload/{printf "%.0f", $2}')
printf '{"ping":"%s","down":"%s","up":"%s","ok":1,"ts":"%s"}\n' "$ping" "$down" "$up" "$(date +%H:%M)"
