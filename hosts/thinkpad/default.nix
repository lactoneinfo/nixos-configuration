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

  # 緊急停止: サスペンド/ハイバネート共にカーネルレベルでハングすることを実機確認
  # (2026-08-22、SysRqにも無反応の完全ハング×2回)。原因(amdgpu/オーディオ周りの
  # サスペンドドライバのバグを疑い中)が特定できるまで、蓋を閉じても自動サスペンド
  # させない。lidSwitchのデフォルトはsystemd標準の"suspend"であり、ここで明示的に
  # 上書きしないとまた同じハングを踏む。
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

  users.users.lactoneinfo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "libvirtd" "networkmanager" ];
    # nixos-install時点の仮パスワード。ログイン後 `passwd` で既に変更済み
    # （initialPasswordは初回のみ効き、以降のrebuildで上書きされることはない）。
    initialPassword = "changeme";
  };
}
