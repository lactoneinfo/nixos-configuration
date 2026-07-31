#!/usr/bin/env bash
# Daemon health at a glance. Nix wraps binaries (real exe often ".name-wrapped"
# or comm truncated to 15 chars), so match on the resolved /proc/<pid>/exe
# basename instead of process name/comm, which is unreliable under Nix.
running=$(for p in /proc/[0-9]*; do
  exe=$(readlink -f "$p/exe" 2>/dev/null) || continue
  b=$(basename "$exe")
  b=${b#.}
  b=${b%-wrapped}
  echo "$b"
done | sort -u)

has() { echo "$running" | grep -qx "$1" && echo 1 || echo 0; }

# tailscaled runs as root: /proc/<pid>/exe isn't readable as a normal user,
# so check for the tailscale0 interface instead (reliable, no privilege needed).
ts=0; ip link show tailscale0 >/dev/null 2>&1 && ts=1

# Claude Codeはnode経由で動くのでexeは"node"に解決され上のhas()では拾えない。
# コマンドライン文字列でマッチ(自己マッチ防止のブラケットトリック)。
claude=0; pgrep -f "[c]laude" >/dev/null 2>&1 && claude=1

printf '{"hyprpaper":%s,"waybar":%s,"eww":%s,"pipewire":%s,"tailscaled":%s,"fcitx5":%s,"claude":%s}\n' \
  "$(has hyprpaper)" "$(has waybar)" "$(has eww)" "$(has pipewire)" "$ts" "$(has fcitx5)" "$claude"
