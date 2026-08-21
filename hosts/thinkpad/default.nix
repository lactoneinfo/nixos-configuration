{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "thinkpad";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
