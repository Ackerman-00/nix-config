{
  description = "NixOS Optimized Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    # Home Manager follows nixpkgs to avoid duplicate evaluation
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MangoWM
    # mangowm = {
    #   url = "github:mangowm/mango";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Custom packages
    nix-packages = {
      url = "github:Ackerman-00/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia locked to the cachix branch without overrides for instant downloads
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    # Noctalia Greeter
    noctalia-greeter = {
      url = "git+https://github.com/noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Umbriel Wm
    umbriel = {
      url = "git+https://github.com/noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # xdg-desktop-portal backend for Umbriel
    xdg-desktop-portal-umbriel = {
      url = "git+https://github.com/noctalia-dev/xdg-desktop-portal-umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };

   # Quickshell - git version
   #quickshell = {
   #  url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
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
          # inputs.mangowm.nixosModules.mango # Mangowm
          inputs.noctalia-greeter.nixosModules.default
          inputs.umbriel.nixosModules.default
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
