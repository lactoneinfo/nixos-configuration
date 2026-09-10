{ pkgs, pkgsUnstable, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "thinkpad";

  # Zotero: 固定nixpkgs(25.05)は7.0.15で、母艦(Windows)のライブラリDB(v10)を
  # 開けない(古い版は「新しいDBだ」と拒否する)。nixpkgs-unstable側の10系を使う。
  # データディレクトリは home NAS の SMB共有 /mnt/zotero/Zotero を指す(母艦と
  # 同時に開かないこと。sqlite over CIFS の破損既往あり)。
  environment.systemPackages = [ pkgsUnstable.zotero ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # サスペンド/ハイバネートがハングした時、電源長押しより安全なMagic SysRq
  # (Alt+SysRq+REISUB)でファイルシステムを傷めずに再起動できるようにする。
  # デフォルトはremount-ro機能しか許可されていない(NixOS標準)。個人単独機なので
  # フル機能を許可しても実害は無い(物理アクセスできる前提のリスクは元々ある)。
  boot.kernel.sysctl."kernel.sysrq" = 1;

  # === 電源管理 (2026-09-10、ハイバネート実装は打ち切り・上流待ち) ===
  # この機種(T14 Gen6 / Ryzen AI 5 PRO 340, Radeon 840M, Krackan Point)は
  # 「蓋を閉じたら省電力」が Linux 側の未成熟で現状どうやっても成立しない:
  #   - /sys/power/mem_sleep が s2idle のみ (ACPIが S0 S4 S5 しか出さない=本物のS3が無い)。
  #     s2idle はカーネルごとハングする既往 (2026-08-22 ×2)。
  #   - ハイバネート(S4)も全パターンでカーネルハング (2026-09-10 に実機フォレンジック、×3):
  #       * デバイス個別の suspend/resume コールバックは全ドライバ正常 (pm_test=devices、
  #         往復3.98秒)。犯人は個別ドライバではない。
  #       * HibernateMode=platform (既定): 最終段の ACPI ファームウェア S4 遷移で
  #         ETIMEDOUT ロールバック or 完全ハング。
  #       * HibernateMode=shutdown: さらに手前、"PM: hibernation entry" 直後・
  #         プロセスfreezeより前 (PM notifier 段、amdgpu のハイバネート準備が最有力) で沈黙。
  #       * kernel 6.12 → 6.18.2 に上げても寸分違わず同じ場所でハング。
  #   - BIOS 1.20 が LVFS 最新 (fwupd 有効化済み、更新なし)。
  #   - これは我々固有ではなく上流の既知問題: 同じ Krackan の Framework 13 AMD で
  #     「Hibernation never works」「AMDGPU refuses to wake after sleep/hibernate」
  #     「MES timeouts (gfx1152)」等のスレッドが多数。2025年 AMD APU 世代の
  #     amdgpu + プラットフォームファームウェアの成熟待ち。
  #     詳細経緯: 90_Protocols/memory/project_new-laptop-plan.md
  #
  # 結論 (2026-09-10): 蓋閉じ = lock のみ (画面はハードウェアでバックライトOFF、
  # 施錠。待機電力は実測 3〜5W = アイドル相当が流れ続ける)。自動でスリープ系を
  # 叩くものは全て無効。バッテリー干上がり防止に下の lid-close-poweroff を併用。
  # 再挑戦は kernel 6.19+ / T14 BIOS 更新が出た時点で (台帳の todo)。
  services.logind.lidSwitch = "lock";
  services.logind.lidSwitchExternalPower = "lock";

  # 蓋を閉じたまま1時間経ったらクリーンシャットダウン (上記の待機電力対策)。
  # /proc/acpi/button/lid/LID/state を60秒間隔でポーリング。蓋を開ければタイマーは
  # リセット。「閉じて数時間の外出」は 11〜18h 持つので影響なし、「一晩〜週末
  # 閉じっぱなし」でバッテリーが死ぬケースだけを潰す (セッションは失う)。
  systemd.services.lid-close-poweroff = {
    description = "Power off after the lid has stayed closed for 1 hour";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils pkgs.gnugrep pkgs.systemd ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
    };
    script = ''
      closed_since=
      while true; do
        if grep -q closed /proc/acpi/button/lid/LID/state 2>/dev/null; then
          now=$(date +%s)
          if [ -z "$closed_since" ]; then closed_since=$now; fi
          if [ $(( now - closed_since )) -ge 3600 ]; then
            exec systemctl poweroff
          fi
        else
          closed_since=
        fi
        sleep 60
      done
    '';
  };

  # ハイバネート用の swapfile と resume 設定。ハイバネートは現状ハングするが、
  # 直った時にすぐ使えるよう温存 (未使用なら無害)。
  # RAM実測27GiB+余裕を見て32GiB。root(ext4)上に作るのでresumeDeviceはrootのUUID。
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 32 * 1024;
  }];
  boot.resumeDevice = "/dev/disk/by-uuid/4cb56131-bd20-4ea5-a246-dafc78edf555";
  # `sudo filefrag -v /var/lib/swapfile`で確認した最初のextentのphysical_offset
  # (4096byteブロック単位)。swapfileを作り直したら値がずれるので要再確認。
  boot.kernelParams = [ "resume_offset=23166976" ];

  # バッテリー最適化(TLP)。AMD Ryzen AI 5 PRO 340 + amd-pstate-epp。
  # power-profiles-daemonとは競合するので有効化しないこと(TLP側で代替)。
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # amd-pstate-epp: EPPがデフォルトperformance固定だと省電力ガバナーの効果が薄れるため明示指定
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # ACPI platform profile(balanced/low-power/performanceから選択可能な機種)
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # USB/PCIe/WiFi省電力
      USB_AUTOSUSPEND = 1;
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # バッテリー劣化防止(ThinkPad標準のcharge threshold、80%止めが定石)。
      # STARTは60: 40フロアだと「50%前後で挿しても充電が始まらず、そのまま
      # 持ち出して低残量スタート」になる。60-80帯に居座らせても平均SoCが
      # 約10pt上がるだけで、リチウムイオンのカレンダー劣化差は6年で数%の誤差。
      # 充電開始の回数(=マイクロ充電)は劣化要因ではない。
      START_CHARGE_THRESH_BAT0 = 60;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # ファームウェア更新 (LVFS/fwupd)。`fwupdmgr get-updates` / `fwupdmgr update`。
  # 2026-09-10 時点: System Firmware 1.20 が最新、更新なし。
  services.fwupd.enable = true;

  users.users.lactoneinfo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "libvirtd" "networkmanager" ];
    # nixos-install時点の仮パスワード。ログイン後 `passwd` で既に変更済み
    # （initialPasswordは初回のみ効き、以降のrebuildで上書きされることはない）。
    initialPassword = "changeme";
  };
}
