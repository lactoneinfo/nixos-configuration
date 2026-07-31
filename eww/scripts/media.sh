#!/usr/bin/env bash
# Now-playing media as a JSON stream。1秒ごとにポーリング(シークバーを滑らかに
# 動かすため、メタデータ変化イベント待ちだけでは秒針が進まない)。
ART_CACHE="/tmp/eww-media-art.jpg"
LAST_ART=""

fmt_time() {
  # $1 = 秒数(整数) -> "M:SS"
  local s=${1:-0}
  printf '%d:%02d' "$((s / 60))" "$((s % 60))"
}

emit() {
  status=$(playerctl status 2>/dev/null)
  if [ -z "$status" ]; then
    printf '{"status":"stopped","title":"No media playing","artist":"","player":"","art":"","pct":0,"pos_fmt":"0:00","len_fmt":"0:00"}\n'
    return
  fi
  title=$(playerctl metadata title 2>/dev/null | sed 's/"/\\"/g' | LC_ALL=en_US.UTF-8 cut -c1-60)
  artist=$(playerctl metadata artist 2>/dev/null | sed 's/"/\\"/g' | LC_ALL=en_US.UTF-8 cut -c1-40)
  player=$(playerctl -l 2>/dev/null | head -1)
  [ -z "$title" ] && title="(unknown title)"

  # アートワーク: Spotify等はfile://(ローカルキャッシュ)かhttps://(CDN画像)を返す。
  # httpsの場合はewwのimageウィジェットが直接読めないのでローカルにcurlで落とす。
  arturl=$(playerctl metadata mpris:artUrl 2>/dev/null)
  art=""
  case "$arturl" in
    file://*)
      art="${arturl#file://}"
      ;;
    http*)
      if [ "$arturl" != "$LAST_ART" ]; then
        curl -sf --max-time 4 "$arturl" -o "$ART_CACHE" 2>/dev/null && LAST_ART="$arturl"
      fi
      [ -f "$ART_CACHE" ] && art="$ART_CACHE"
      ;;
  esac

  pos=$(playerctl position 2>/dev/null | cut -d. -f1)
  len_us=$(playerctl metadata mpris:length 2>/dev/null)
  pos=${pos:-0}
  len=0
  pct=0
  if [ -n "$len_us" ] && [ "$len_us" -gt 0 ] 2>/dev/null; then
    len=$((len_us / 1000000))
    [ "$len" -gt 0 ] && pct=$((pos * 100 / len))
  fi

  printf '{"status":"%s","title":"%s","artist":"%s","player":"%s","art":"%s","pct":%s,"pos_fmt":"%s","len_fmt":"%s"}\n' \
    "$status" "$title" "$artist" "$player" "$art" "$pct" "$(fmt_time "$pos")" "$(fmt_time "$len")"
}

if command -v playerctl >/dev/null 2>&1; then
  while true; do emit; sleep 1; done
else
  while true; do emit; sleep 5; done
fi
