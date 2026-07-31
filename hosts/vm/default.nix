{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos-vm";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
