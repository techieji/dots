{
  description = "Configuration";

  inputs = {
    # Nix Community flakes
    nixpkgs = { url = "github:nixOS/nixpkgs/nixos-unstable"; };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    stylix = { url = "github:nix-community/stylix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Self-maintained tools
    pabc = { url = "github:techieji/pabc"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Other flakes
    helium = { url = "github:FKouhai/helium2nix/main"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, home-manager, stylix, ... }@inputs: {
    nixosConfigurations.pradtop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; system = "x86_64-linux"; };
          home-manager.backupFileExtension = "bak";
          home-manager.users.prajasekar = ./home.nix;
        }
        stylix.nixosModules.stylix
      ];
    };
  };
}
