#!/usr/bin/env bash
# Emits a single numeric audio level (0-100) per tick, fed into an eww
# `graph` widget for a real scrolling waveform/oscilloscope look
# (rather than the vertical spectrum-bar look of raw cava output).
# 引数: speaker(既定=出力モニタ) / mic(入力ソース)。
mode="${1:-speaker}"

if ! command -v cava >/dev/null 2>&1; then
  while sleep 1; do printf '0\n'; done
  exit 0
fi

cfg=$(mktemp)
if [ "$mode" = "mic" ]; then
  src=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk -F'"' '/node.name/{print $2; exit}')
  cat > "$cfg" <<EOF
[general]
bars = 12
framerate = 30
[input]
method = pipewire
source = ${src:-auto}
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
EOF
else
  cat > "$cfg" <<EOF
[general]
bars = 12
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
EOF
fi

cava -p "$cfg" 2>/dev/null | while IFS=';' read -r -a arr; do
  sum=0; n=0
  for v in "${arr[@]}"; do
    [ -z "$v" ] && continue
    sum=$((sum+v)); n=$((n+1))
  done
  if [ "$n" -gt 0 ]; then
    printf '%d\n' $((sum/n))
  else
    printf '0\n'
  fi
done
