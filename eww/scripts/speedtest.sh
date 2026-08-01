#!/usr/bin/env bash
# 実測の回線速度(down/up Mbps・ping)。帯域を使う重い処理なので普段は10分間隔。
# FIFOで待ち受けており、コックピットのretryボタンから書き込まれると
# 10分を待たずに即座に再計測する(deflistenで常駐、defpollではないので注意)。
FIFO=/tmp/eww-speedtest-trigger
[ -p "$FIFO" ] || mkfifo "$FIFO"

run_once() {
  out=$(timeout 30 speedtest-cli --simple 2>/dev/null)
  if [ -z "$out" ]; then
    printf '{"ping":"—","down":"—","up":"—","ok":0,"ts":"%s"}\n' "$(date +%H:%M)"
    return
  fi
  ping=$(ping -c1 -W1 8.8.8.8 2>/dev/null | awk -F'time=' '/time=/{print int($2)}')
  [ -z "$ping" ] && ping="—"
  down=$(echo "$out" | awk '/^Download/{printf "%.0f", $2}')
  up=$(echo "$out" | awk '/^Upload/{printf "%.0f", $2}')
  printf '{"ping":"%s","down":"%s","up":"%s","ok":1,"ts":"%s"}\n' "$ping" "$down" "$up" "$(date +%H:%M)"
}

while true; do
  run_once
  # `read -t N < fifo` はfifoのopen自体がブロッキングでタイムアウトが効かない。
  # fd を読み書き両用(<>)で開けば自分自身がwriter側にもなるためopenで詰まらず、
  # read -t のタイムアウトが正しく機能する。
  exec 3<>"$FIFO"
  read -t 600 -r _ <&3
  exec 3<&-
done
