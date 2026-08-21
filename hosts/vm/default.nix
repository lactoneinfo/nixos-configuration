{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos-vm";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "input" "libvirtd" ];
    initialPassword = "nixos";
  };

  # 検証用の使い捨てVMなので利便性優先でsudoパスワードを省略
  security.sudo.wheelNeedsPassword = false;
}
