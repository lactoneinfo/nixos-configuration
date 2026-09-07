{
  description = "Owner's NixOS configs (VM practice host + real ThinkPad T14 Gen6 AMD)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # 一部パッケージだけ新しい版が要るとき用(Zotero等: 固定の25.05側は古すぎて
    # 母艦のライブラリDBを開けない)。全体は25.05のまま、cherry-pickでのみ使う。
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
  let
    mkHost = { hostModule, username, isVM }: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit isVM;
        pkgsUnstable = import nixpkgs-unstable { system = "x86_64-linux"; };
      };
      modules = [
        ./common.nix
        hostModule
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${username} = import ./home.nix;
          home-manager.extraSpecialArgs = { inherit username isVM; };
          # fcitx5は起動のたびに~/.config/fcitx5/profileを自分で書き換えるため、
          # home-managerが管理するシンボリックリンクと毎回衝突してrebuildが
          # 失敗していた。衝突時は手動対応を待たず自動でバックアップして進める。
          home-manager.backupFileExtension = "hm-backup";
        }
      ];
    };
  in {
    nixosConfigurations = {
      vm = mkHost {
        hostModule = ./hosts/vm/default.nix;
        username = "nixos";
        isVM = true;
      };
      thinkpad = mkHost {
        hostModule = ./hosts/thinkpad/default.nix;
        username = "lactoneinfo";
        isVM = false;
      };
    };
  };
}
