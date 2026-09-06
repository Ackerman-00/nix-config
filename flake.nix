{
  description = "NixOS Optimized Flake";

  # --- Inputs ---
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-packages = {
      url = "github:Ackerman-00/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    umbriel = {
      url = "git+https://github.com/noctalia-dev/umbriel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # --- Outputs ---
  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
    nixosConfigurations."quietcraft" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
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
