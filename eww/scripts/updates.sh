#!/usr/bin/env bash
# NixOSにはapt/pacmanの「N個アップデートあり」に相当する概念が無い
# (ローリング的にflake.lockのnixpkgsコミットを更新→rebuildする方式)ので、
# 代わりに「今ピン留めしているnixpkgsがどれだけ古いか」を出す。
lock="/etc/nixos/flake.lock"
if [ ! -f "$lock" ]; then
  printf '{"pinned_date":"—","age_days":0,"rev":"—"}\n'
  exit 0
fi
ts=$(jq -r '.nodes.nixpkgs.locked.lastModified // 0' "$lock" 2>/dev/null)
rev=$(jq -r '.nodes.nixpkgs.locked.rev // "—"' "$lock" 2>/dev/null | cut -c1-7)
if [ -z "$ts" ] || [ "$ts" = "0" ]; then
  printf '{"pinned_date":"—","age_days":0,"rev":"—"}\n'
  exit 0
fi
pinned_date=$(date -d "@$ts" +%Y-%m-%d 2>/dev/null)
now=$(date +%s)
age_days=$(( (now-ts)/86400 ))
printf '{"pinned_date":"%s","age_days":%s,"rev":"%s"}\n' "$pinned_date" "$age_days" "$rev"
