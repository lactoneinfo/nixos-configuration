#!/usr/bin/env bash
# 既定スピーカー/マイクのデバイス名と音量・ミュート状態をJSON化。
# wpctl(WirePlumber)優先、無ければpactl。VMでデバイス無しなら "no device"。
sink="no device"; source="no device"; svol="—"; mvol="—"
if command -v wpctl >/dev/null 2>&1; then
  sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node.description/{print $2; exit}')
  source=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk -F'"' '/node.description/{print $2; exit}')
  svol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%d", $2*100}')
  mvol=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{printf "%d", $2*100}')
fi
[ -z "$sink" ] && sink="no device"
[ -z "$source" ] && source="no device"
[ -z "$svol" ] && svol="—"
[ -z "$mvol" ] && mvol="—"
# 長すぎるデバイス名は切る
sink=$(echo "$sink" | cut -c1-24)
source=$(echo "$source" | cut -c1-24)
printf '{"sink":"%s","source":"%s","svol":"%s","mvol":"%s"}\n' "$sink" "$source" "$svol" "$mvol"
