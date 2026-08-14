{
  description = "NixOS Optimized Flake for Ryzen 5600G";

  nixConfig = {
    extra-substituters = [ 
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [ 
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

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

  outputs = { self, nixpkgs, nixpkgs-stable, ... } @ inputs:
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
        ];
      };
    };
}
