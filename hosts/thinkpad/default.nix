{ pkgsUnstable, ... }:

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

  # === 電源管理 (2026-09-10 実機フォレンジック、現状) ===
  # この機種(T14 Gen6 / Ryzen AI 5 PRO 340, Radeon 840M, kernel 6.12.63)の症状:
  #   - /sys/power/mem_sleep が s2idle のみ (ACPIが S0 S4 S5 しか出さない=本物のS3が無い)。
  #     s2idle はカーネルごとハングする既往 (2026-08-22)。封印中。
  #   - ハイバネートも全パターンでハング (2026-08-22 ×2, 2026-09-10 ×3):
  #       * HibernateMode=platform (既定): デバイス退避は全ドライバ正常完了 (pm_test=devices で
  #         往復3.98秒)、最終段の ACPI ファームウェア S4 遷移で ETIMEDOUT ロールバック or 完全ハング。
  #       * HibernateMode=shutdown (下記設定): さらに手前、"PM: hibernation entry" の直後・
  #         プロセスfreezeより前で沈黙。console prep か PM notifier 段。
  #     → 犯人は個別デバイスドライバではなく、amdgpu のハイバネート対応 or カーネルの
  #        ハイバネート入口処理。BIOS は 1.20 が LVFS 最新 (更新なし)。次の一手は
  #        kernel 6.12 → 最新 (6.18+) で amdgpu の Krackan Point 対応を新しくすること。
  #        詳細経緯: 90_Protocols/memory/project_new-laptop-plan.md
  #
  # 現状の安全策: 蓋を閉じても suspend/hibernate せず lock のみ (画面OFF+施錠、待機電力は
  # アイドル相当で流れる)。自動でスリープ系を叩くものは全て無効。
  # HibernateMode=shutdown は「いずれ直った時にこの機種の正しい選択 (S3が無いので
  # platform経路は使わない)」なので設定は残すが、現時点で解決策ではない。
  systemd.sleep.extraConfig = ''
    HibernateMode=shutdown
  '';
  services.logind.lidSwitch = "lock";
  services.logind.lidSwitchExternalPower = "lock";

  # ハイバネート(ディスクへの退避)用のswapfile。この機種は/sys/power/mem_sleepが
  # s2idleのみ(本当のS3が無い)でサスペンド中のバッテリー消費が大きめなので、
  # 蓋を閉じて長時間放置した時の保険として用意する。
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

      # バッテリー劣化防止(ThinkPad標準のcharge threshold、80%止めが定石)
      START_CHARGE_THRESH_BAT0 = 40;
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
