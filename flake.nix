{
  description = "Owner's NixOS configs (VM practice host now, ThinkPad later)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations = {
      vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./common.nix
          ./hosts/vm/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nixos = import ./home.nix;
            # fcitx5は起動のたびに~/.config/fcitx5/profileを自分で書き換えるため、
            # home-managerが管理するシンボリックリンクと毎回衝突してrebuildが
            # 失敗していた。衝突時は手動対応を待たず自動でバックアップして進める。
            home-manager.backupFileExtension = "hm-backup";
          }
        ];
      };
    };
  };
}
