#!/usr/bin/env bash
# Current location + weather there.
# Prefers a phone-pushed GPS fix if fresh (~/.private-rice/phone-location.json,
# outside git — see notes below on how the phone side pushes it), otherwise
# falls back to wttr.in's IP-based guess.
PHONE_LOC="$HOME/.private-rice/phone-location.json"
QUERY=""
source="ip"

if [ -f "$PHONE_LOC" ]; then
  ts=$(jq -r '.ts // 0' "$PHONE_LOC" 2>/dev/null)
  now=$(date +%s)
  age=$(( now - ts ))
  # 30分以内の新しい位置情報だけ信用する(古いキャッシュをそのまま使わない)
  if [ "$age" -ge 0 ] && [ "$age" -lt 1800 ]; then
    lat=$(jq -r '.lat // empty' "$PHONE_LOC" 2>/dev/null)
    lon=$(jq -r '.lon // empty' "$PHONE_LOC" 2>/dev/null)
    if [ -n "$lat" ] && [ -n "$lon" ]; then
      QUERY="$lat,$lon"
      source="phone"
    fi
  fi
fi

CACHE="/tmp/eww-location-cache.json"

url="https://wttr.in/${QUERY}?format=j1"
data=$(curl -sf --max-time 8 "$url" 2>/dev/null)
if [ -z "$data" ]; then
  if [ -s "$CACHE" ]; then
    cat "$CACHE"
  else
    printf '{"source":"none","city":"unavailable","temp":"—","desc":"—","feels":"—","icon":"weather-na"}\n'
  fi
  exit 0
fi
city=$(echo "$data" | jq -r '.nearest_area[0].areaName[0].value // "Unknown"' 2>/dev/null)
region=$(echo "$data" | jq -r '.nearest_area[0].region[0].value // ""' 2>/dev/null)
temp=$(echo "$data" | jq -r '.current_condition[0].temp_C // "—"' 2>/dev/null)
feels=$(echo "$data" | jq -r '.current_condition[0].FeelsLikeC // "—"' 2>/dev/null)
desc=$(echo "$data" | jq -r '.current_condition[0].weatherDesc[0].value // "—"' 2>/dev/null)
code=$(echo "$data" | jq -r '.current_condition[0].weatherCode // "113"' 2>/dev/null)

case "$code" in
  113) icon="weather-sun" ;;
  116|119|122) icon="weather-cloud" ;;
  143|248|260) icon="weather-fog" ;;
  176|263|266|293|296|299|302|305|308|311|314|317|320|353|356|359) icon="weather-rain" ;;
  179|182|185|227|230|323|326|329|332|335|338|350|368|371|374|377) icon="weather-rain" ;;
  200|386|389|392|395) icon="weather-thunder" ;;
  *) icon="weather-na" ;;
esac

loc="$city"
[ -n "$region" ] && loc="$city, $region"
printf '{"source":"%s","city":"%s","temp":"%s","desc":"%s","feels":"%s","icon":"%s"}\n' \
  "$source" "$loc" "$temp" "$desc" "$feels" "$icon" | tee "$CACHE"
