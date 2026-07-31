#!/usr/bin/env bash
# Now-playing media as a JSON stream (deflisten). playerctl -F fires on change.
emit() {
  status=$(playerctl status 2>/dev/null)
  if [ -z "$status" ]; then
    printf '{"status":"stopped","title":"No media playing","artist":"","player":""}\n'
    return
  fi
  title=$(playerctl metadata title 2>/dev/null | sed 's/"/\\"/g' | cut -c1-60)
  artist=$(playerctl metadata artist 2>/dev/null | sed 's/"/\\"/g' | cut -c1-40)
  player=$(playerctl -l 2>/dev/null | head -1)
  [ -z "$title" ] && title="(unknown title)"
  printf '{"status":"%s","title":"%s","artist":"%s","player":"%s"}\n' \
    "$status" "$title" "$artist" "$player"
}
emit
if command -v playerctl >/dev/null 2>&1; then
  playerctl -F metadata 2>/dev/null | while read -r _; do emit; done
else
  while sleep 5; do emit; done
fi
