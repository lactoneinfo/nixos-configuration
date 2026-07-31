#!/usr/bin/env bash
# 起動時オーケストレーション。Hyprlandのexec-onceから1回だけ呼ぶ。
# 「再起動したら少し待てば全部のステータスが正常に戻る」を保証するため、
# 各デーモンを順序立てて・存在確認しながら・多少のリトライ耐性込みで起動する。
# 冪等(何度実行しても安全)にしてあるので、手動での「治す」実行にも使える。
LOG="$HOME/.cache/cockpit-startup.log"
mkdir -p "$HOME/.cache"
echo "=== startup $(date) ===" >> "$LOG"

wait_for() {
  # $1=説明 $2=チェックコマンド(文字列、evalする) $3=タイムアウト秒
  local desc="$1" check="$2" timeout="${3:-10}" waited=0
  while ! eval "$check" >/dev/null 2>&1; do
    sleep 0.5
    waited=$(awk "BEGIN{print $waited+0.5}")
    if awk "BEGIN{exit !($waited >= $timeout)}"; then
      echo "[timeout] $desc after ${timeout}s" >> "$LOG"
      return 1
    fi
  done
  echo "[ok] $desc (${waited}s)" >> "$LOG"
  return 0
}

running() { pgrep -x "$1" >/dev/null 2>&1 || pgrep -x ".$1-wrapped" >/dev/null 2>&1; }

# 1. Hyprland自体のIPCソケットが上がるまで待つ(exec-once実行時点でほぼ確実に
#    上がっているはずだが、念のため)
wait_for "Hyprland IPC" 'hyprctl monitors >/dev/null' 10

# 2. hyprpaperはhome-managerのsystemd --userサービス側に一本化(重複起動を避ける)。
#    ここでは起動確認だけ行い、動いてなければsystemdサービスを再始動する。
if ! running hyprpaper; then
  systemctl --user restart hyprpaper.service 2>>"$LOG"
  wait_for "hyprpaper" 'running hyprpaper' 10
fi

# 3. fcitx5(日本語入力)。起動時のデフォルト入力はkeyboard-us(英字)に統一——
#    fcitx5は最後にアクティブだった入力を記憶して次回のデフォルトにする挙動があり、
#    英字/日本語トグルを使うたびに勝手にずれていくため、起動の度に明示的に戻す。
if ! running fcitx5; then
  setsid fcitx5 -d >>"$LOG" 2>&1 < /dev/null &
  disown
fi
wait_for "fcitx5" 'fcitx5-remote >/dev/null' 10
fcitx5-remote -s keyboard-us >>"$LOG" 2>&1

# 4. waybar
if ! running waybar; then
  setsid waybar >>"$LOG" 2>&1 < /dev/null &
  disown
fi
wait_for "waybar" 'running waybar' 10

# 4b. mako(通知デーモン)。home-managerのservices.makoはgraphical-session.target
#     頼みで、Hyprlandは素のままではそのtargetに到達しないため自動起動しない。
#     hyprpaperと同じく、ここで明示的に起動確認する。
if ! systemctl --user is-active --quiet mako.service; then
  systemctl --user start mako.service 2>>"$LOG"
fi
wait_for "mako" 'systemctl --user is-active --quiet mako.service' 10

# 4d. swayidle(自動ロック/サスペンド)。同じくgraphical-session.target頼みの
#     ためmako同様に自動起動しないので明示的に確認する。
if ! systemctl --user is-active --quiet swayidle.service; then
  systemctl --user start swayidle.service 2>>"$LOG"
fi
wait_for "swayidle" 'systemctl --user is-active --quiet swayidle.service' 10

# 4c. クリップボード履歴の収集デーモン(テキスト/画像)。exec-onceでも起動するが、
#     $mod+Shift+Rでの手動リペア時にも確実に生きているよう、ここでも存在確認する。
if ! pgrep -f "wl-paste --type text --watch cliphist" >/dev/null 2>&1; then
  setsid wl-paste --type text --watch cliphist store >>"$LOG" 2>&1 < /dev/null &
  disown
fi
if ! pgrep -f "wl-paste --type image --watch cliphist" >/dev/null 2>&1; then
  setsid wl-paste --type image --watch cliphist store >>"$LOG" 2>&1 < /dev/null &
  disown
fi

# 5. eww daemon(コックピット自体はSuper+Dで開くまで表示しない、daemonだけ常駐)
if ! running eww; then
  cd "$HOME/.config/eww"
  setsid eww daemon >>"$LOG" 2>&1 < /dev/null &
  disown
  cd "$HOME"
fi
wait_for "eww daemon" 'eww active-windows >/dev/null' 10

echo "=== startup done $(date) ===" >> "$LOG"
