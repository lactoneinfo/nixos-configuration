#!/usr/bin/env bash
# eww ウィンドウを「今フォーカスしているモニタ」で開く。
#   使い方: open-here.sh <window-name>
# cockpit/cheatsheet/study はモニタ実寸に追従する設計(width/height 100%)なので、
# あとは表示先モニタさえ正しく選べば、内蔵/外部/解像度に関係なく収まる。
set -u
win="${1:?window name required}"

# hyprctl の focused モニタ。eww --screen は数値インデックスも
# コネクタ名も受け付けるが、GDK 側の並びとズレることがあるのでまず名前で試す。
mon_name=$(hyprctl monitors -j 2>/dev/null | jq -r 'map(select(.focused))|.[0].name // empty' 2>/dev/null)

# --toggle: 既に開いていれば閉じる(別モニタで開いていても閉じる)。
if [ -n "$mon_name" ]; then
  eww open "$win" --toggle --screen "$mon_name" && exit 0
fi
# フォールバック: defwindow 側の :monitor 0
eww open "$win" --toggle
