{ pkgs, lib, ... }:

{
  # 自宅サーバーのIP/共有名など個人情報を含む設定は、このgit管理下のファイルには
  # 一切書かず /etc/nixos/private-hosts.nix (このVM/実機にだけ手動で置く、
  # publicリポジトリには絶対に含めないファイル)に分離する。存在すれば取り込む。
  imports = lib.optional (builtins.pathExists ./private-hosts.nix) ./private-hosts.nix;

  # flakeを使うための必須設定(デフォルトでは無効な実験的機能)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # claude-code/obsidianがunfreeライセンスのため個別に許可(全体はallowUnfree=trueにしない)
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" "obsidian" "spotify" ];

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "jp106";

  # 日本語入力(fcitx5 + mozc)。waybar側で「あ/A」の状態を読んで表示する。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    # fcitx5-mozc-ut: 通常のmozcにmozcdic-ut(継続更新されているUT拡張辞書、
    # ネット語彙・固有名詞に強い)を同梱したバリアント。予測変換の質が上がる。
    fcitx5.addons = with pkgs; [ fcitx5-mozc-ut fcitx5-gtk ];
    fcitx5.waylandFrontend = true;
  };

  programs.hyprland.enable = true;
  # regreetのセッション選択欄にHyprlandを表示させるための.desktopエントリ登録。
  # displayManager経由ではなくgreetdを直接使っているため自動では入らない。
  environment.pathsToLink = [ "/share/wayland-sessions" ];
  services.displayManager.sessionPackages = [ pkgs.hyprland ];

  # ログイン画面(regreet, greetd用のGTK4グリーター)を夜桜×モダングラデの
  # テーマで統一。TTY手動ログイン運用から、ここで初めてグラフィカルな
  # ログイン画面に切り替える。configはgit管理下(個人情報なし、壁紙のみ)。
  # regreet自体はGTK4アプリでありWaylandサーバーを持たないため、
  # 軽量kiosk compositorのcageで包んで起動する(regreet単体では
  # "Failed to initialize GTK"で即クラッシュする)。
  services.seatd.enable = true;  # cage/wlrootsがlogind ACL無しでも/dev/inputを読めるように(2026-07-31、regreetキー入力不通の修正)
  users.users.greeter.extraGroups = [ "seat" "input" "video" ];  # seatd/inputデバイスへのアクセス権(2026-07-31)

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # WLR_RENDERER=pixman はVirtualBoxのソフトウェアGPU(vmwgfx)でwlroots系
        # コンポジタが正常動作しない問題への対策(Hyprland側と同じworkaround)。
        # 実機ノートPCに移す際はこのenv行を削除してよい。
        command = "${pkgs.util-linux}/bin/setsid env WLR_RENDERER=pixman WLR_NO_HARDWARE_CURSORS=1 ${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.regreet}/bin/regreet -c /etc/greetd/regreet.toml -s /etc/greetd/regreet.css";
        user = "greeter";
      };
    };
  };
  # regreetが起動時に書こうとするログファイル用(greeterユーザーの書き込み権限が必要)
  systemd.tmpfiles.rules = [
    "d /var/log/regreet 0755 greeter greeter -"
  ];
  environment.etc."greetd/sakura.jpg".source = ./sakura.jpg;
  environment.etc."greetd/regreet.toml".text = ''
    [background]
    path = "/etc/greetd/sakura.jpg"
    fit = "Cover"

    [GTK]
    application_prefer_dark_theme = true
    cursor_theme = "Bibata-Modern-Classic"
    font_name = "JetBrainsMono Nerd Font 11"
  '';
  environment.etc."greetd/regreet.css".source = ./greetd-theme.css;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "libvirtd" ];
    initialPassword = "nixos";
  };

  services.openssh.enable = true;

  # hyprlockの認証に使うPAMサービス定義。これが無いと"/etc/pam.d/hyprlock does
  # not exist"警告と共にsuのPAMスタックにフォールバックし、認証周りが不安定になる。
  security.pam.services.hyprlock = {};

  # 検証用の使い捨てVMなので利便性優先でsudoパスワードを省略
  security.sudo.wheelNeedsPassword = false;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono   # アイコン内蔵の等幅フォント(waybarのアイコン用)
    noto-fonts-cjk-sans         # 日本語表示
    noto-fonts-color-emoji     # 絵文字(無いと通知やブラウザで絵文字が□(tofu)になる)
  ];
  fonts.fontconfig.defaultFonts.emoji = [ "Noto Color Emoji" ];

  # Nixストアの自動清掃。使い続けると/nix/storeが際限なく肥大化するため、
  # 週1で世代を刈り込み+重複排除(自動optimise)する。
  nix.gc = {
    automatic = true;
    dates = "weekly";   # singleLineStrなので単一文字列(systemd calendar形式)
    options = "--delete-older-than 14d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];  # こちらはlistOf str
  };

  # PowerPoint/行政書類/AviUtl等Windows専用ソフト用のWindows VM基盤(libvirt/QEMU)。
  # 罠: このVM自体がVirtualBox上のネストされたゲストで、ホストWindowsでHyper-Vが
  # 有効(検出済み)なため、VirtualBoxのネストHW仮想化(nested-hw-virt=on にはした)
  # を経由してもさらにその中でKVMを使う「三重ネスト」は実質サポート外——/dev/kvmが
  # 生成されずTCG(ソフトウェアエミュレーション)頼みで極めて低速になる。実機の
  # ThinkPad(ベアメタル、Hyper-V越しでない直接KVM)に移せばこの制約は無くなる想定。
  # そのため今はインフラ(libvirtd/qemu/virt-manager)の宣言のみ済ませておき、
  # 実際のWindows ISOインストール・稼働確認は実機移行後に行う。
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;   # UEFIファームウェア(Windows 11はUEFI必須)
      swtpm.enable = true;  # TPM 2.0エミュレーション(Windows 11のインストール要件)
    };
  };
  programs.virt-manager.enable = true;

  # Bluetooth(実機で意味を持つ。VMでは物理アダプタ無しなのでコックピットは
  # 「なし」表示になるだけ。configは実機に移して初めて効く)
  hardware.bluetooth.enable = true;

  # Tailscale(コックピットで接続状況を出す。VMでは未ログイン=Stopped表示)
  services.tailscale.enable = true;

  # waybarのbattery/backlightモジュールが電源情報を取るのに使う
  services.upower.enable = true;

  # home NAS上のObsidian vault / Zoteroライブラリのマウント設定自体は
  # private-hosts.nix側(git管理外)に書く。ここではcifs-utilsの導入のみ。

  environment.systemPackages = with pkgs; [
    git
    vim
    foot        # ソフトレンダで動くterminal emulator(VM向け)
    waybar
    eww         # コックピット(ダッシュボード)本体
    curl        # 天気スクリプトでwttr.inを叩く
    jq
    fastfetch   # OS/PC情報タイル(neofetch後継)
    starship    # おしゃれなシェルプロンプト
    playerctl   # 再生中メディアの取得(MPRIS)
    pamixer     # 音量取得
    cava        # オーディオ波形ビジュアライザ
    tailscale   # tailscale statusをコックピットで読む
    bluez       # bluetoothctl(BT接続状況)
    procps      # ps/top(重いプロセス一覧)
    util-linux  # lsblk/df(ディスク使用状況)
    speedtest-cli  # 実測の回線速度(down/up Mbps・ping)
    nethogs        # プロセス別ネットワーク使用量
    brightnessctl  # 画面の明るさ調整(実機ノートPC向け)
    usbutils       # lsusb(DEVICESタイルのUSB検出)
    cifs-utils     # home NASのSMB共有マウント(Obsidian vault/Zotero)
    iw             # WiFi SSID取得(INTERNETタイル)

    # クリップボード履歴
    wl-clipboard   # wl-copy/wl-paste(Wayland版クリップボード操作)
    cliphist       # 履歴の保存・検索本体

    # スクリーンショット・画面録画
    grim           # スクリーンショット撮影本体(Wayland)
    slurp          # 範囲選択(矩形をマウスドラッグで指定)
    swappy         # スクショへの注釈(矢印・枠・文字入れ)
    wf-recorder    # 画面録画(mp4出力)
    libnotify      # notify-send(スクショ/録画の完了通知)

    firefox        # ブラウザ(Discord画面共有等の動作確認にも使用)

    virt-viewer    # windows-switch.shがVMドメインに接続する際に使う

    anki           # 単語帳(AnkiConnectアドオン経由でスクリプトから登録)
    unzip          # AnkiConnectアドオンの.ankiaddon(zip形式)展開に使用

    # AIエージェント作業画面: 左Claude Codeチャット・右Obsidianグラフビュー
    claude-code    # 左画面のチャット本体(初回はログインが要る、認証は代行できない)
    obsidian       # 右画面。home NAS上の実vault(/mnt/obsidian)を直接開く
    spotify        # 音楽再生(cockpitのNOW PLAYING+audio waveform動作確認用)
  ];

  system.stateVersion = "25.05";
}
