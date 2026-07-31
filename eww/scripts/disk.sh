#!/usr/bin/env bash
# 各パーティションの使用状況をJSON配列で。物理FSのみ(tmpfs等は除外)。
# /mnt/obsidian・/mnt/zoteroはsystemd automount(60秒アイドルで自動アンマウント)。
# dfは現在の実マウント一覧を見るだけでアクセスを発生させないため、アイドル
# アンマウント後は何もしないと再マウントされずタイル上から消えたままになる。
# statで軽く触れて自動マウントを起こしてからdfする。
for p in /mnt/obsidian /mnt/zotero; do
  [ -d "$p" ] && timeout 3 stat "$p" >/dev/null 2>&1
done

df -B1 --output=target,fstype,size,used,pcent 2>/dev/null | tail -n +2 | \
while read -r target fstype size used pcent; do
  case "$fstype" in
    ext4|btrfs|xfs|vfat|zfs|ext3|ext2|f2fs|cifs|smb3|smbfs) ;;
    *) continue ;;
  esac
  pct="${pcent%\%}"
  used_h=$(numfmt --to=iec --suffix=B --format="%.0f" "$used" 2>/dev/null)
  size_h=$(numfmt --to=iec --suffix=B --format="%.0f" "$size" 2>/dev/null)
  printf '%s{"mount":"%s","fs":"%s","size":%s,"used":%s,"pct":%s,"used_h":"%s","size_h":"%s"}' \
    "$sep" "$target" "$fstype" "$size" "$used" "$pct" "$used_h" "$size_h"
  sep=","
done | awk 'BEGIN{printf "["} {printf "%s", $0} END{print "]"}'
