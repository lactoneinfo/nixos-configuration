{ pkgs, lib, ... }:

let
  # 夜桜×モダングラデーション配色(eww.scssと同一パレット、必ず同期させる)
  bg = "12141f";
  sakura = "ff9ec7";
  sky = "8fb8e8";
  amber = "e8b56b";
  fg = "f6eef3";
  # GTK CSSは #rrggbbaa(8桁hex)を受け付けないので、透明度付きはrgba()で書く
  amberDim = "rgba(232,181,107,0.2)";   # amber ~20%
  amberMid = "rgba(232,181,107,0.53)";  # amber ~53%
  fgDim = "rgba(246,238,243,0.47)";     # fg ~47%
in
{
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";
  home.stateVersion = "25.05";

  # デフォルトの派手なXカーソルをやめ、洗練された黒矢印ベースのテーマに。
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 22;
    gtk.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      bind = [
        "$mod, Return, exec, foot"
        "$mod, Q, killactive"
        "$mod, M, exit"
        # アプリランチャー(インストール済みアプリの.desktopをwofiのdrunモードで検索起動。
        # 例: ここでfirefoxと打ってEnter)
        "$mod, SPACE, exec, wofi --show drun"
        # コックピットを開く時はHyprlandのsubmap(モード切替)に入る。
        # submap中は下のextraConfigで明示的に許可したキー(D/Escape)以外
        # 全く反応しない——footを含め他のキーバインドは構造的に発火し得ない。
        "$mod, D, exec, eww open cockpit && hyprctl dispatch submap cockpit"
        # 手動リペア: デーモンが何か落ちてる時に押せば起動スクリプトが再チェックして直す
        "$mod SHIFT, R, exec, bash ~/.config/eww/scripts/startup.sh"

        # クリップボード履歴(cliphist)。wofiで選んでEnterで即ペースト可能な状態にコピー。
        "$mod, V, exec, cliphist list | wofi --dmenu --prompt 'clipboard' | cliphist decode | wl-copy"

        # スクリーンショット: Print=範囲+注釈(swappy)、$mod+Print=範囲をそのままクリップボードへ、
        # $mod SHIFT+Print=画面全体を保存。Flameshot等の一般的な使い分けに合わせた。
        ", Print, exec, ~/.local/bin/screenshot-annotate.sh"
        "$mod, Print, exec, ~/.local/bin/screenshot-region.sh"
        "$mod SHIFT, Print, exec, ~/.local/bin/screenshot-full.sh"

        # 画面録画のトグル(開始/終了を同じキーで): $mod ALT+R=画面全体、$mod ALT SHIFT+R=範囲指定
        "$mod ALT, R, exec, ~/.local/bin/record-toggle.sh full"
        "$mod ALT SHIFT, R, exec, ~/.local/bin/record-toggle.sh region"

        # 手動ロック(離席時にすぐ画面を隠す用、自動ロックを待たなくていい)。
        # LIBGL_ALWAYS_SOFTWARE=1はVM専用workaround(下のswayidle設定コメント参照)。
        "$mod, L, exec, env LIBGL_ALWAYS_SOFTWARE=1 hyprlock"

        # ショートカット一覧(このキー自体も他と被っていないことを確認済み: comma単体は
        # 元々どのバインドにも使われていなかった)
        "$mod, comma, exec, eww open cheatsheet && hyprctl dispatch submap cheatsheet"

        # Windows VM(PowerPoint/AviUtl等)への切り替え
        "$mod, W, exec, ~/.local/bin/windows-switch.sh"

        # 勉強/インプット画面(reddit todayilearnedの人気記事+ANKIタイル)
        "$mod, I, exec, ~/.local/bin/study-open.sh"

        # 選択中の単語/フレーズをAnkiに登録(Firefox等どこで選択していても効く)
        "$mod SHIFT, A, exec, ~/.local/bin/anki-capture.sh"

        # AIエージェント作業画面(左Claude Code・右Obsidianグラフビュー)へ切替
        "$mod, A, exec, ~/.local/bin/agent-workspace.sh"
      ]
      # ワークスペース切替(Hyprlandのデフォルト例設定相当だが、この設定は
      # ゼロから組んだためこれまで一切定義されていなかった)。
      ++ (builtins.concatLists (map (n: [
            "$mod, ${toString n}, workspace, ${toString n}"
            "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
          ]) (builtins.genList (i: i + 1) 9)));
      # Super+左ドラッグ=移動、Super+右ドラッグ=リサイズ(Hyprlandのデフォルト
      # 例設定相当。これもゼロから組んだ設定には元々含まれていなかった)。
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      # hyprpaper/waybar/fcitx5/ewwの起動は1本のオーケストレーションスクリプトに
      # 一本化(存在確認・待機・リトライ込み)。「再起動したら少し待てば全部正常に
      # 戻る」を保証するための仕組み。hyprpaper自体はhome-managerのsystemd --user
      # サービス側で管理するので、ここに直接は書かない(二重起動を避ける)。
      exec-once = [
        "bash ~/.config/eww/scripts/startup.sh"
        # クリップボード履歴の収集デーモン(テキスト/画像それぞれ別ウォッチャーが必要)
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        # fcitx5本体のデーモン。i18n.inputMethod.enableだけではHyprland環境では
        # 自動起動しない(XDG autostartを処理する仕組みが無いため)。
        "fcitx5 -d"
      ];
      # VirtualBoxの仮想GPU(vmwgfx)がまともなOpenGLを提供しないため、
      # 実機(ThinkPad)に移った際はこの行ごと削除する想定のVM専用設定。
      env = [
        "WLR_RENDERER,pixman"
        "WLR_NO_HARDWARE_CURSORS,1"
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "XCURSOR_SIZE,22"
      ];
      # VM専用: フレームバッファに一致する解像度・scale1で固定。
      # scaleが不定になるとeww/waybarの描画が拡大バグる。実機では ",preferred,auto,1" に。
      monitor = ",1279x799@60,0x0,1";

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(${sakura}ff) rgba(${sky}ff) 45deg";
        "col.inactive_border" = "rgba(${amber}55)";
      };

      decoration = {
        rounding = 10;
        # VM(pixmanソフトレンダ)ではblurが部分的にしか描画されずパッチ状の
        # 崩れた見た目になるため無効化。実機(GLレンダラ)では true に戻す
        # ——タイルの半透明色だけで「すりガラス感」は既に出ている。
        blur = {
          enabled = false;
          size = 8;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
          xray = false;
        };
      };

      # eww(gtk-layer-shell)とwaybarのレイヤーをblur対象にする。
      # これで半透明タイルの背後にHyprlandのすりガラスblurがかかる(実機=GL時)。
      # VMはpixmanソフトレンダなのでblurは効かず、壁紙が透ける半透明止まり。
      layerrule = [
        "blur, gtk-layer-shell"
        "blur, waybar"
        "ignorezero, gtk-layer-shell"
      ];

      # footはfoot.ini側でalpha=0.55を要求しているが、このVM(pixmanソフト
      # レンダ)ではクライアント自己申告の透過がうまく合成されず不透明に
      # 見えてしまう。Hyprland側のwindowrulev2で強制的に透過をかけて解決。
      windowrulev2 = [
        "opacity 0.82 0.72,class:^(foot)$"
        # ANKIタイル(study画面): 実ウィジェット埋め込みは出来ないため、Ankiの
        # 実ウィンドウをstudy画面のanki-frameと同じ座標・サイズに固定してタイル
        # っぽく見せるworkaround。座標はeww.yuck/eww.scssのstudy画面レイアウトと
        # 手動で合わせているので、study画面のレイアウトを変えたらここも要調整。
        "float,class:^(anki)$"
        "size 540 580,class:^(anki)$"
        "move 680 140,class:^(anki)$"
        "noborder,class:^(anki)$"
        "rounding 10,class:^(anki)$"
      ];

      animations = {
        enabled = true;
      };
    };

    # submap定義は行の順序が意味を持つ(cockpit開始〜resetの間だけ有効)ため、
    # キー順序が保証されないNixの属性集合(settings)ではなく生テキストで書く。
    extraConfig = ''
      submap = cockpit
      bind = , D, exec, eww close cockpit && hyprctl dispatch submap reset
      bind = , escape, exec, eww close cockpit && hyprctl dispatch submap reset
      submap = reset

      submap = cheatsheet
      bind = , comma, exec, eww close cheatsheet && hyprctl dispatch submap reset
      bind = , escape, exec, eww close cheatsheet && hyprctl dispatch submap reset
      submap = reset

      submap = study
      bind = , I, exec, eww close study && hyprctl dispatch submap reset
      bind = , escape, exec, eww close study && hyprctl dispatch submap reset
      submap = reset
    '';
  };

  programs.foot = {
    enable = true;
    settings = {
      main = {
        # ptはpxと違う単位(11pt≈14.7px)——eww/waybarの11pxと見た目を揃えるため8ptに。
        font = "JetBrainsMono Nerd Font:size=8";
        pad = "14x14";
      };
      cursor.color = "${bg} ${amber}";
      colors = {
        # 透過はHyprland側のwindowrulev2 opacityで一元管理するため、
        # foot自身はほぼ不透明にしておく(二重に掛かって暗くなるのを防ぐ)。
        alpha = "1.0";
        background = bg;
        foreground = fg;
        regular0 = "1a1c2c";
        regular1 = sakura;    # red -> sakura
        regular2 = sky;       # green -> sky
        regular3 = amber;     # yellow -> amber
        regular4 = "b57edc";  # blue -> violet
        regular5 = sakura;    # magenta -> sakura
        regular6 = sky;       # cyan -> sky
        regular7 = fg;
        bright1 = sakura;
        bright2 = sky;
        bright3 = amber;
      };
    };
  };

  # シェルプロンプト(starship)。cockpitと同じ夜桜パレットで統一。
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$character";
      character = {
        success_symbol = "[❯](bold #8fb8e8)";
        error_symbol = "[❯](bold #ff9ec7)";
      };
      directory = {
        style = "bold #e8b56b";
        truncation_length = 3;
      };
      git_branch.style = "#ff9ec7";
      git_status.style = "#8fb8e8";
    };
  };

  programs.bash.enable = true;

  # fcitx5のプロファイル: keyboard-us(英字)とmozc(日本語)を同一グループに
  # 登録し、fcitx5-remote -t (Ctrl+Space既定)でこの2つをトグルできるようにする。
  # パッケージを入れただけでは有効化されない(fcitx5-configtoolでのGUI設定が
  # 前提の項目)ため、宣言的にprofileファイル自体を書いて再現性を確保する。
  home.file.".config/fcitx5/profile".text = ''
    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=keyboard-us

    [Groups/0/Items/0]
    Name=keyboard-us
    Layout=

    [Groups/0/Items/1]
    Name=mozc
    Layout=

    [GroupOrder]
    0=Default
  '';

  # コックピット(eww)の設定一式をデプロイ。recursiveで各ファイルを個別リンク。
  home.file.".config/eww" = {
    source = ./eww;
    recursive = true;
  };

  # fcitx5の入力モード(あ/A)をwaybar用にJSON出力する常駐スクリプト。
  # fcitx5-remote -t で状態が変わるたびに1行JSONを吐く。
  home.file.".local/bin/waybar-fcitx5.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # fcitx5-remote: 0=direct/English input, 2=Japanese (kana) input
      emit() {
        s=$(fcitx5-remote 2>/dev/null)
        if [ "$s" = "2" ]; then
          printf '{"text":"JP","class":"jp","tooltip":"Japanese input"}\n'
        else
          printf '{"text":"EN","class":"en","tooltip":"English input"}\n'
        fi
      }
      emit
      # fcitx5のD-Bus変化を購読して即時更新(無ければ2秒ポーリングにフォールバック)
      if command -v dbus-monitor >/dev/null 2>&1; then
        dbus-monitor --session "type='signal',interface='org.fcitx.Fcitx.InputMethod1'" 2>/dev/null |
          while read -r _; do emit; done
      else
        while sleep 2; do emit; done
      fi
    '';
  };

  # 天気(現在の気温+状況アイコン)。wttr.inを叩いて簡潔なJSONを返す。
  home.file.".local/bin/waybar-weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # 以前はここで独自にwttr.inを直接叩いていたため、コックピットの
      # LOCATIONタイル(電話GPS優先、IPフォールバック)と表示温度が食い違っていた。
      # location.shを共通の情報源として再利用し、値を一致させる。アイコンも付けて
      # 「PCの温度ではなく外の気温」だと一目でわかるようにする。
      data=$(bash "$HOME/.config/eww/scripts/location.sh" 2>/dev/null)
      temp=$(echo "$data" | ${pkgs.jq}/bin/jq -r '.temp // "—"' 2>/dev/null)
      if [ -z "$temp" ] || [ "$temp" = "—" ]; then
        printf '{"text":"--","tooltip":"weather fetch failed"}\n'
      else
        printf '{"text":"󰖙 %s°C","tooltip":"outside temperature (same source as cockpit LOCATION tile)"}\n' "$temp"
      fi
    '';
  };

  # 気温の右に簡易的な再生中表示(曲名+音楽アイコン)。何も再生していなければ空表示。
  home.file.".local/bin/waybar-media.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      status=$(${pkgs.playerctl}/bin/playerctl status 2>/dev/null)
      if [ -z "$status" ]; then
        printf '{"text":"","tooltip":""}\n'
        exit 0
      fi
      # waybarはこのスクリプトをUTF-8ロケール未設定の環境で起動することがあり、
      # その場合cut -cが日本語等マルチバイト文字の途中でバイト単位に切って
      # 不正なUTF-8になり、waybar(GTK markup)ごとクラッシュした実例がある。
      # LC_ALLを明示してcutに文字単位で切らせることで回避する。
      title=$(${pkgs.playerctl}/bin/playerctl metadata title 2>/dev/null | LC_ALL=en_US.UTF-8 cut -c1-24)
      artist=$(${pkgs.playerctl}/bin/playerctl metadata artist 2>/dev/null)
      printf '{"text":"♪ %s","tooltip":"%s - %s"}\n' "$title" "$title" "$artist"
    '';
  };

  # --- スクリーンショット・画面録画スクリプト群 ---
  home.file.".local/bin/screenshot-annotate.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # 範囲選択→swappyで注釈(矢印/枠/文字入れ)→保存+クリップボードへコピー
      set -e
      mkdir -p "$HOME/Pictures/Screenshots"
      f="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
      geom=$(slurp) || exit 0
      grim -g "$geom" - | swappy -f - -o "$f"
      if [ -f "$f" ]; then
        wl-copy < "$f"
        notify-send "Screenshot" "注釈つきで保存しました: $f" -i "$f"
      fi
    '';
  };
  home.file.".local/bin/screenshot-region.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # 範囲選択→そのままクリップボードへ(貼り付け前提の素早いコピー用)
      set -e
      mkdir -p "$HOME/Pictures/Screenshots"
      f="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
      geom=$(slurp) || exit 0
      grim -g "$geom" "$f"
      wl-copy < "$f"
      notify-send "Screenshot" "範囲を保存してクリップボードにコピーしました" -i "$f"
    '';
  };
  home.file.".local/bin/screenshot-full.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      set -e
      mkdir -p "$HOME/Pictures/Screenshots"
      f="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
      grim "$f"
      wl-copy < "$f"
      notify-send "Screenshot" "画面全体を保存しました" -i "$f"
    '';
  };
  # Windows VM(PowerPoint/行政書類/AviUtl用)への切り替えショートカット。
  # "windows"という名前のlibvirtドメインが既にあればそこへvirt-viewerで直接飛ぶ、
  # 無ければ(まだWindowsをインストールしていない段階)virt-managerを開いて
  # VM作成から始められるようにする。
  # study画面を開く際、ANKIタイル用に実Ankiアプリも一緒に起動する
  # (既に起動中なら二重起動しない)。ウィンドウ位置合わせはHyprlandの
  # windowrulev2(class:^(anki)$)側で行う。
  home.file.".local/bin/study-open.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      pgrep -x anki >/dev/null 2>&1 || (setsid anki >/tmp/anki.log 2>&1 < /dev/null &)
      eww open study
      hyprctl dispatch submap study
    '';
  };

  # AIエージェントと話すための作業ワークスペース(専用ワークスペース9)。
  # 左=Claude Codeのチャット(foot+claude、あかりのvaultディレクトリで起動)、
  # 右=Obsidianのグラフビュー(同じ実vaultを開く、ノートを編集するとリアルタイムで
  # グラフに反映される)。Hyprlandのデフォルトdwindleレイアウトが2枚を自動で
  # 左右分割するので、Ankiタイルのような座標合わせのworkaroundは不要。
  home.file.".local/bin/agent-workspace.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      VAULT="/mnt/obsidian/AILibrary/AILibrary"
      hyprctl dispatch workspace 9

      if ! pgrep -f "foot.*claude" >/dev/null 2>&1; then
        setsid foot -D "$VAULT" claude >/tmp/agent-foot.log 2>&1 < /dev/null &
        disown
      fi
      sleep 0.5

      # obsidianはElectron製で、Ozoneプラットフォームを明示しないとXWaylandを
      # 要求してこのVMでは"Missing X server or $DISPLAY"で即落ちる。
      if ! pgrep -x obsidian >/dev/null 2>&1; then
        setsid env ELECTRON_OZONE_PLATFORM_HINT=wayland obsidian --ozone-platform=wayland \
          "obsidian://open?path=$(printf '%s' "$VAULT" | sed 's/\//%2F/g')" \
          >/tmp/agent-obsidian.log 2>&1 < /dev/null &
        disown
      fi
    '';
  };

  # アプリケーションマネージャー(ランチャー)からクリックして起動した場合も
  # 上と同じOzone/Waylandフラグが効くよう、.desktopファイル自体を上書きする。
  # XDG的にはユーザーの~/.local/share/applications側が/run/current-system側
  # (パッケージ同梱の素の.desktop、フラグ無し)より優先されるため、これで
  # ランチャー経由の起動でもXWaylandクラッシュを回避できる。
  # 実例: SpotifyはこのフラグなしだとXWayland依存で描画しようとし、
  # このVM(WLR_RENDERER=pixmanのソフトレンダ)ではXWaylandがクラッシュして
  # ウィンドウが一切出ない(プロセスは起動するが無反応に見える、2026-08-01発覚)。
  home.file.".local/share/applications/spotify.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Spotify
    GenericName=Music Player
    Icon=spotify-client
    TryExec=spotify
    Exec=spotify --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-wayland-ime %U
    Terminal=false
    MimeType=x-scheme-handler/spotify;
    Categories=Audio;Music;Player;AudioVideo;
    StartupWMClass=spotify
  '';
  home.file.".local/share/applications/obsidian.desktop".text = ''
    [Desktop Entry]
    Categories=Office
    Comment=Knowledge base
    Exec=env ELECTRON_OZONE_PLATFORM_HINT=wayland obsidian --ozone-platform=wayland %u
    Icon=obsidian
    MimeType=x-scheme-handler/obsidian
    Name=Obsidian
    Type=Application
    Version=1.4
  '';
  # discord/slackもElectron製で同じXWaylandの罠を踏むため、Spotify/Obsidianと
  # 同様にOzone/Waylandフラグ付きで上書きする。zoom-usはQtベースなので対象外。
  home.file.".local/share/applications/discord.desktop".text = ''
    [Desktop Entry]
    Name=Discord
    Comment=All-in-one voice and text chat for gamers
    Exec=env ELECTRON_OZONE_PLATFORM_HINT=wayland discord --ozone-platform=wayland %U
    Icon=discord
    Type=Application
    Categories=Network;InstantMessaging;
  '';
  home.file.".local/share/applications/slack.desktop".text = ''
    [Desktop Entry]
    Name=Slack
    Comment=Slack Desktop
    Exec=env ELECTRON_OZONE_PLATFORM_HINT=wayland slack --ozone-platform=wayland -s %U
    Icon=slack
    Type=Application
    Categories=Network;InstantMessaging;
  '';

  home.file.".local/bin/windows-switch.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      if virsh --connect qemu:///system dominfo windows >/dev/null 2>&1; then
        virsh --connect qemu:///system start windows 2>/dev/null
        exec virt-viewer --connect qemu:///system --reconnect --wait windows
      else
        notify-send "Windows VM" "まだ作成されていません。virt-managerでインストールしてください。"
        exec virt-manager
      fi
    '';
  };

  # AnkiConnectアドオン(単語帳へのHTTP経由登録を可能にする、コミュニティ定番アドオン)を
  # 初回のhome-manager適用時に自動インストールする。手動でAnkiのアドオンマネージャから
  # コード2055492159を入れる手順を省略するための宣言的workaround(固定ハッシュを持てない
  # 配布形態のため、fetchurlではなくactivationスクリプトでのダウンロードにしてある)。
  home.activation.installAnkiConnect = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ADDON_DIR="$HOME/.local/share/Anki2/addons21/2055492159"
    if [ ! -d "$ADDON_DIR" ]; then
      ${pkgs.curl}/bin/curl -sL --max-time 15 "https://ankiweb.net/shared/download/2055492159" -o /tmp/ankiconnect.ankiaddon 2>/dev/null || true
      # ankiweb.net/shared/downloadへの直curlは"Your version of Anki is too old."
      # という32バイトのテキストを返すことがある(バージョン確認パラメータが必要)。
      # 中身が本物のzip(先頭"PK")か確認してから展開する——確認せず展開すると
      # 空のアドオンフォルダが残り、Anki自体が起動時にクラッシュする原因になった。
      if [ -s /tmp/ankiconnect.ankiaddon ] && [ "$(head -c2 /tmp/ankiconnect.ankiaddon)" = "PK" ]; then
        mkdir -p "$ADDON_DIR"
        ${pkgs.unzip}/bin/unzip -oq /tmp/ankiconnect.ankiaddon -d "$ADDON_DIR" 2>/dev/null || true
      fi
    fi
  '';

  # 選択した単語(Firefox等どこでも、プライマリ選択=マウスドラッグ選択)を、
  # 辞書API(dictionaryapi.dev、無料・無認証)で意味を引いてAnkiに登録する。
  # AnkiConnectのHTTP API(localhost:8765)経由、Ankiアプリ自体は起動している前提。
  home.file.".local/bin/anki-capture.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      word=$(wl-paste --primary --no-newline 2>/dev/null | tr -d '\n' | sed 's/^ *//;s/ *$//')
      if [ -z "$word" ]; then
        notify-send "Anki登録" "選択されたテキストがありません"
        exit 0
      fi

      # 辞書API: 単語(1語)の場合のみ定義を引く。複数語(文脈ごと選択)の場合は
      # そのまま例文として保存し、定義欄には「複数語選択」の旨だけ書く。
      firstword=$(echo "$word" | awk '{print $1}')
      wordcount=$(echo "$word" | wc -w)

      if [ "$wordcount" -eq 1 ]; then
        def=$(curl -sf --max-time 6 "https://api.dictionaryapi.dev/api/v2/entries/en/$firstword" \
          | jq -r '.[0].meanings[0] | "(" + .partOfSpeech + ") " + .definitions[0].definition' 2>/dev/null)
        [ -z "$def" ] && def="(辞書に見つかりませんでした)"
      else
        def="(複数語選択のため定義検索はスキップ、例文として保存)"
      fi

      back="$def<br><br><i>$word</i>"

      resp=$(curl -sf --max-time 5 http://127.0.0.1:8765 -X POST -d "$(jq -n \
        --arg front "$firstword" --arg back "$back" \
        '{action:"addNote", version:6, params:{note:{deckName:"Default", modelName:"Basic",
          fields:{Front:$front, Back:$back}, options:{allowDuplicate:false}, tags:["cockpit-input"]}}}')" \
        2>/dev/null)

      if echo "$resp" | jq -e '.error == null and .result != null' >/dev/null 2>&1; then
        notify-send "Anki登録" "「$firstword」を追加しました"
      else
        err=$(echo "$resp" | jq -r '.error // "AnkiConnectに接続できません(Ankiは起動していますか?)"' 2>/dev/null)
        notify-send "Anki登録 失敗" "$err"
      fi
    '';
  };

  home.file.".local/bin/record-toggle.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      # $1 = full|region。同じキーで開始/終了をトグルする(pidfileで状態管理)。
      mode="''${1:-full}"
      pidfile="/tmp/wf-recorder-$mode.pid"
      mkdir -p "$HOME/Videos/Screenrecords"

      if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        kill -INT "$(cat "$pidfile")"
        rm -f "$pidfile"
        notify-send "録画終了" "$HOME/Videos/Screenrecords に保存しました"
        exit 0
      fi

      f="$HOME/Videos/Screenrecords/$(date +%Y-%m-%d_%H-%M-%S).mp4"
      if [ "$mode" = "region" ]; then
        geom=$(slurp) || exit 0
        wf-recorder -g "$geom" -f "$f" --audio >/tmp/wf-recorder-$mode.log 2>&1 &
      else
        wf-recorder -f "$f" --audio >/tmp/wf-recorder-$mode.log 2>&1 &
      fi
      echo $! > "$pidfile"
      notify-send "録画開始" "$f"
    '';
  };

  # クリップボード履歴のピッカーUI(cliphist listの結果をdmenu形式で選ばせる)
  programs.wofi = {
    enable = true;
    settings = {
      width = 500;
      height = 360;
      location = "center";
      show = "dmenu";
      allow_markup = true;
    };
    style = ''
      window {
        background-color: #${bg};
        border: 2px solid #${sakura};
        border-radius: 12px;
      }
      #input {
        background-color: #1a1c2c;
        color: #${fg};
        border-radius: 8px;
        margin: 6px;
      }
      #entry {
        color: #${fg};
        padding: 4px 8px;
      }
      #entry:selected {
        background-color: #${sakura};
        color: #${bg};
        border-radius: 6px;
      }
    '';
  };

  # 通知デーモン(notify-send受け皿)。スクショ/録画の完了通知に使う。
  services.mako = {
    enable = true;
    settings = {
      background-color = "#${bg}f0";
      text-color = "#${fg}";
      border-color = "#${sakura}";
      border-size = 2;
      border-radius = 10;
      padding = "10";
      font = "JetBrainsMono Nerd Font 11";
      default-timeout = 5000;
    };
  };
  # home-managerのservices.makoはsystemd --userサービスとして自動登録されるため、
  # Hyprlandのexec-onceに追記する必要は無い(hyprpaperと同じ扱い)。

  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        /* 不透過でよいが真っ黒だと単調なので、黒系のまま少し明るいトーンに。 */
        background-color: #1a1c28;
        color: #${fg};
      }
      /* 各モジュールを「浮いた島(ピル)」にする共通スタイル */
      #workspaces,
      #clock,
      #custom-ime,
      #cpu,
      #memory,
      #temperature,
      #pulseaudio,
      #network,
      #battery,
      #custom-weather,
      #custom-media {
        background-color: #${bg};
        padding: 2px 12px;
        margin: 4px 3px;
        border-radius: 10px;
        border: 1px solid ${amberDim};
      }
      #clock {
        color: #${amber};
        font-weight: bold;
        border: 1px solid ${amberMid};
      }
      #network, #battery { color: #${sky}; }
      #cpu, #memory, #temperature { color: #${sakura}; }
      #pulseaudio { color: #${amber}; }
      #custom-weather { color: #${sky}; }
      #custom-media { color: #${sakura}; }

      /* 入力モード: 日本語(あ)はピンク発光、英字(A)は控えめ */
      #custom-ime.jp {
        color: #${bg};
        background-color: #${sakura};
        font-weight: bold;
      }
      #custom-ime.en { color: #${fg}; }

      /* 高負荷時の警告色 */
      #cpu.critical, #memory.critical, #temperature.critical {
        color: #${bg};
        background-color: #${sakura};
      }
      #battery.critical { color: #${bg}; background-color: #${sakura}; }

      #workspaces { padding: 2px 6px; }
      #workspaces button {
        color: ${fgDim};
        padding: 0 6px;
        border-radius: 8px;
      }
      #workspaces button.active {
        color: #${bg};
        background-color: #${sakura};
      }
      #workspaces button:hover {
        color: #${sky};
        background-color: transparent;
      }
    '';
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        margin-top = 0;
        modules-left = [ "hyprland/workspaces" "custom/weather" "custom/media" ];
        modules-center = [ "clock" ];
        # backlight/batteryはデバイスが無ければ自動的に表示されない
        # (VMでは出ない、実機ThinkPadで有効になる想定)。
        modules-right = [ "cpu" "memory" "temperature" "pulseaudio" "network" "backlight" "battery" "custom/ime" ];

        clock = {
          format = "{:%Y/%m/%d (%a) %H:%M}";
          tooltip-format = "<tt><big>{:%Y %B}</big></tt>\n<tt>{calendar}</tt>";
        };
        # アイコンだけだと何を指しているか分からない、という指摘を受けて
        # 短いテキストラベルを必ず添える(CPU/MEM/NET等)。
        cpu = {
          format = "CPU {usage}%";
          interval = 2;
          states = { critical = 85; };
        };
        memory = {
          format = "MEM {percentage}%";
          interval = 2;
          states = { critical = 85; };
        };
        temperature = {
          format = "{temperatureC}°C";
          critical-threshold = 80;
          interval = 2;
        };
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "muted";
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
        # 生のインターフェース名(enp0s3等)は一般利用者には意味不明なので出さず、
        # 「オンライン/オフライン」のみ表示。詳細はcockpitのNETWORKタイル側に譲る。
        network = {
          format-wifi = "NET {signalStrength}%";
          format-ethernet = "NET online";
          format-disconnected = "NET offline";
          tooltip-format = "{ifname}: {ipaddr}";
        };
        battery = {
          format = "BAT {capacity}%";
          format-charging = "BAT {capacity}% (charging)";
          states = { critical = 15; };
        };
        # 画面の明るさ(ノートPC実機向け。VMはバックライトデバイスが無いので出ない)
        backlight = {
          format = "BRT {percent}%";
          on-scroll-up = "brightnessctl set 5%+";
          on-scroll-down = "brightnessctl set 5%-";
        };
        # fcitx5のON/OFF(あ/A)を自作スクリプトの常時ストリームで反映
        "custom/ime" = {
          exec = "~/.local/bin/waybar-fcitx5.sh";
          return-type = "json";
        };
        "custom/weather" = {
          exec = "~/.local/bin/waybar-weather.sh";
          return-type = "json";
          interval = 900;
        };
        "custom/media" = {
          exec = "~/.local/bin/waybar-media.sh";
          return-type = "json";
          interval = 3;
          # クリックで再生/一時停止トグル、右クリックで次の曲。
          on-click = "${pkgs.playerctl}/bin/playerctl play-pause";
          on-click-right = "${pkgs.playerctl}/bin/playerctl next";
        };
      };
    };
  };

  # 壁紙: sakura.jpg は出典不明な拾い画像のためgit管理外。/etc/nixos-private/sakura.jpg に
  # 各自好きな画像を同名で置くこと(絶対パス参照、flakeがgitの場合の
  # git-tracked-onlyフィルタを避けるため。詳細はcommon.nixの同種コメント参照)。
  home.file."Pictures/sakura.jpg".source = /etc/nixos-private/sakura.jpg;

  # 画面ロック(実機で人前に置くなら必須。今までは無くて離席時に開きっぱなしだった)。
  # 夜桜壁紙+同じ配色で、cockpit/greetdログイン画面とトーンを合わせている。
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
      };
      background = [{
        path = "~/Pictures/sakura.jpg";
        # VM(pixmanソフトレンダ)ではblurを付けるとバッファ形式が合わずhyprlock
        # ごと落ちるため無効化。実機(GLレンダラ)ではblur_passes/blur_sizeを戻してよい。
        blur_passes = 0;
      }];
      input-field = [{
        size = "300, 60";
        outline_thickness = 2;
        outer_color = "rgb(${sakura})";
        inner_color = "rgb(1a1c2c)";
        font_color = "rgb(${fg})";
        placeholder_text = "Password...";
        shadow_passes = 2;
      }];
      label = [{
        text = "cmd[update:1000] date +'%H:%M'";
        color = "rgb(${amber})";
        font_size = 64;
        position = "0, 180";
        halign = "center";
        valign = "center";
      }];
    };
  };

  # 一定時間放置での自動ロック/サスペンド。5分放置→ロック、15分放置→サスペンド
  # (サスペンド前には必ずロックしてから眠る、が定石)。
  # hyprlockはVM(pixmanソフトレンダ)だとハードウェアGLでの描画を試みて
  # "invalid arguments for wl_surface.attach"で即クラッシュする。
  # LIBGL_ALWAYS_SOFTWARE=1でソフトウェアGLに強制すると回避できる
  # (実機のGLレンダラに移す際はこのenv指定を外してよい)。
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = "${pkgs.util-linux}/bin/setsid env LIBGL_ALWAYS_SOFTWARE=1 ${pkgs.hyprlock}/bin/hyprlock"; }
      { timeout = 900; command = "systemctl suspend"; }
    ];
    events = [
      { event = "before-sleep"; command = "${pkgs.util-linux}/bin/setsid env LIBGL_ALWAYS_SOFTWARE=1 ${pkgs.hyprlock}/bin/hyprlock"; }
    ];
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "~/Pictures/sakura.jpg" ];
      wallpaper = [ ",~/Pictures/sakura.jpg" ];
    };
  };

  programs.home-manager.enable = true;
}
