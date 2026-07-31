#!/usr/bin/env bash
# CPU使用率の高い上位プロセスをJSON配列で(重いもの上位)。
# /proc/<pid>/io の read_bytes/write_bytes の差分からディスクI/O速度(KB/s)も取る
# (Windowsのタスクマネージャで見えるディスク列に相当。自分のプロセスなら権限問題なし)。
mapfile -t lines < <(ps -eo pid,comm,pcpu,pmem --sort=-pcpu --no-headers 2>/dev/null | grep -vE '^\s*[0-9]+ ps( |$)' | head -6)

declare -A r1 w1
for line in "${lines[@]}"; do
  pid=$(echo "$line" | awk '{print $1}')
  io=$(cat /proc/"$pid"/io 2>/dev/null)
  r1[$pid]=$(echo "$io" | awk '/^read_bytes/{print $2}')
  w1[$pid]=$(echo "$io" | awk '/^write_bytes/{print $2}')
done
sleep 0.3
out="["
sep=""
for line in "${lines[@]}"; do
  pid=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | awk '{print $2}')
  cpu=$(echo "$line" | awk '{print $3}')
  mem=$(echo "$line" | awk '{print $4}')
  [ ${#name} -gt 15 ] && name="${name:0:14}…"
  name=$(echo "$name" | sed 's/"/\\"/g')

  io=$(cat /proc/"$pid"/io 2>/dev/null)
  r2=$(echo "$io" | awk '/^read_bytes/{print $2}')
  w2=$(echo "$io" | awk '/^write_bytes/{print $2}')
  dr=0; dw=0
  if [ -n "$r2" ] && [ -n "${r1[$pid]}" ]; then
    dr=$(awk "BEGIN{d=($r2-${r1[$pid]})/0.3/1024; printf \"%.0f\", d<0?0:d}")
  fi
  if [ -n "$w2" ] && [ -n "${w1[$pid]}" ]; then
    dw=$(awk "BEGIN{d=($w2-${w1[$pid]})/0.3/1024; printf \"%.0f\", d<0?0:d}")
  fi

  out="$out$sep{\"name\":\"$name\",\"cpu\":$cpu,\"mem\":$mem,\"diskr\":$dr,\"diskw\":$dw}"
  sep=","
done
out="$out]"
echo "$out"
