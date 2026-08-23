{
  description = "NixOS Optimized Flake for Ryzen 5600G";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # Home Manager follows our nixpkgs to avoid duplicate evaluation
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MangoWM locked to its own nixpkgs to prevent source compilation
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom packages share your system's appimageTools
    nix-packages = {
      url = "github:Ackerman-00/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia locked to the cachix branch without overrides for instant downloads
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

   # Quickshell - git version needed for caelestia-shell-mango
   #quickshell = {
   #  url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
   #  inputs.nixpkgs.follows = "nixpkgs";
   # };

   # Caelestia CLI - main control script for caelestia dotfiles
   #caelestia-cli = {
   #   url = "github:caelestia-dots/cli";
   #  inputs.nixpkgs.follows = "nixpkgs";
   # };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations."quietcraft" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-stable; }; 
        modules = [
          ./configuration.nix
          inputs.mangowm.nixosModules.mango
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit inputs; };
              users.ackerman = ./home.nix;
            };
          }
        ];
      };
    };
}
