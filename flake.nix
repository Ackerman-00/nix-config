{
  description = "NixOS Optimized Flake";

  # Eval-time caches, mirrored in modules/system/nix-settings.nix.
  nixConfig = {
    extra-substituters = [ "https://umbriel.cachix.org" ];
    extra-trusted-public-keys = [
      "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Umbriel compositor: official nix modules, tracked on the `cachix` branch.
    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    # OpenCode feed pin; `nix flake update` bumps it.
    opencode-feed = {
      url = "file+https://opencode.ai/update/api/latest/desktop/opencode/latest-linux.yml";
      flake = false;
    };

    # Helium versions.json pin; `nix flake update` bumps it.
    helium-pin = {
      url = "github:amaanq/helium-flake";
      flake = false;
    };

    # Concat release manifest; `nix flake update` bumps it.
    concat-manifest = {
      url = "file+https://github.com/jub0t/Concat/releases/latest/download/manifest.json";
      flake = false;
    };

    # Blender MCP source, commit-pinned (no upstream tags).
    # Bump the rev, then `nix flake update blender-mcp-src`.
    blender-mcp-src = {
      url = "github:ahujasid/mcp-for-blender/60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4";
      flake = false;
    };

    # YouTube transcript MCP source, tag-pinned (v0.7.0 fits mcp 1.x).
    mcp-youtube-transcript-src = {
      url = "git+https://github.com/jkawamoto/mcp-youtube-transcript.git?ref=refs/tags/v0.7.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      # Repo gates (toplevel eval is automatic).
      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          formatting = pkgs.runCommand "check-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            cd ${self}
            find . -name '*.nix' -not -path './home-manager/desktop/umbriel/*' -not -name 'umbriel.nix' -not -name 'hardware-configuration.nix' -print0 | xargs -0 nixfmt --check
            touch $out
          '';
          statix = pkgs.runCommand "check-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
            cd ${self}
            statix check -i 'hardware-configuration.nix' -i '*/umbriel/*' -i '*/umbriel.nix' .
            touch $out
          '';
          deadnix = pkgs.runCommand "check-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            cd ${self}
            deadnix --no-lambda-arg --no-lambda-pattern-names --fail --exclude hardware-configuration.nix .
            touch $out
          '';
          noctalia-toml = pkgs.runCommand "check-noctalia-toml" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            python3 -c "import tomllib; tomllib.load(open('${self}/home-manager/programs/noctalia/config.toml','rb'))"
            touch $out
          '';
        };

      # Standalone build: nix build .#opencode-desktop
      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          opencode-desktop = pkgs.callPackage ./modules/packages/opencode/package.nix {
            opencodeFeed = inputs.opencode-feed;
          };
          default = self.packages.x86_64-linux.opencode-desktop;
        };

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
