{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "thinkpad";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.lactoneinfo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "libvirtd" "networkmanager" ];
    # nixos-install時点の仮パスワード。ログイン後 `passwd` で既に変更済み
    # （initialPasswordは初回のみ効き、以降のrebuildで上書きされることはない）。
    initialPassword = "changeme";
  };
}
