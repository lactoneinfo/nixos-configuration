#!/usr/bin/env bash
# プロセスごとのネットワーク使用量(タスクマネージャのネットワーク列相当)。
# Linuxには標準の仕組みが無く、nethogs(パケット監視ベース、root要)を使う。
# 数秒かかる実測なので、呼び出し間隔は net.sh 等より長めにする前提。
iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
[ -z "$iface" ] && iface=$(ls /sys/class/net 2>/dev/null | grep -v lo | head -1)

if ! command -v nethogs >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

raw=$(timeout 6 sudo -n nethogs -t -c 2 "$iface" 2>/dev/null)
last_start=$(echo "$raw" | grep -n "^Refreshing:" | tail -1 | cut -d: -f1)
[ -z "$last_start" ] && { echo "[]"; exit 0; }
block=$(echo "$raw" | tail -n +$((last_start + 1)))

echo "$block" | awk -F'\t' '
  /^unknown TCP/ { next }
  NF >= 3 {
    name = $1
    sub(/\/[0-9]+\/[0-9]+$/, "", name)   # 末尾の /pid/uid を除去
    gsub(/.*\//, "", name)               # フルパスならbasenameだけに
    gsub(/"/, "", name)
    total = $2 + $3
    if (total > 0.01) {
      printf "%s{\"name\":\"%s\",\"down\":%.0f,\"up\":%.0f}", (printed ? "," : ""), name, $3*1024, $2*1024
      printed=1
    }
  }
' | awk 'BEGIN{printf "["} {printf "%s", $0} END{print "]"}'
