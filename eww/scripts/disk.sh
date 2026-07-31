#!/usr/bin/env bash
# 各パーティションの使用状況をJSON配列で。物理FSのみ(tmpfs等は除外)。
df -B1 --output=target,fstype,size,used,pcent 2>/dev/null | tail -n +2 | \
awk '
  $2 ~ /^(ext4|btrfs|xfs|vfat|zfs|ext3|ext2|f2fs)$/ {
    gsub(/%/,"",$5);
    printf "%s{\"mount\":\"%s\",\"fs\":\"%s\",\"size\":%s,\"used\":%s,\"pct\":%s}", sep, $1, $2, $3, $4, $5;
    sep=",";
  }
  END { }
' | awk 'BEGIN{printf "["} {printf "%s", $0} END{print "]"}'
