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

# 表示欄が1行分しか無く、複数出すと折り返してレイアウトが崩れるため、
# 帯域が最も大きい1プロセスだけに絞る。
echo "$block" | awk -F'\t' '
  /^unknown TCP/ { next }
  NF >= 3 {
    name = $1
    sub(/\/[0-9]+\/[0-9]+$/, "", name)   # 末尾の /pid/uid を除去
    gsub(/.*\//, "", name)               # フルパスならbasenameだけに
    gsub(/"/, "", name)
    down = $3*1024
    up = $2*1024
    total = down + up
    if (total > 0.01) printf "%.0f\t%s\t%.0f\t%.0f\n", total, name, down, up
  }
' | sort -rn -k1,1 | head -1 | awk -F'\t' '
  { printf "[{\"name\":\"%s\",\"down\":%s,\"up\":%s}]", $2, $3, $4; found=1 }
  END { if (!found) print "[]" }
'
