{
  description = "NixOS Optimized Flake";

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

    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    concat-manifest = {
      url = "file+https://github.com/jub0t/Concat/releases/latest/download/manifest.json";
      flake = false;
    };

    omnirush-feed = {
      url = "file+https://github.com/omnirush-ai/omnirush-gui/releases/latest/download/latest-linux.yml";
      flake = false;
    };

    freebuff-feed = {
      url = "file+https://freebuff.com/api/desktop/updates/linux-x64-deb/latest-linux.yml";
      flake = false;
    };

    blender-mcp-src = {
      url = "github:ahujasid/mcp-for-blender/febcd90ece59c3416d7c55fd3723cea46bcaa59d";
      flake = false;
    };

    mcp-youtube-transcript-src = {
      url = "git+https://github.com/jkawamoto/mcp-youtube-transcript.git?ref=refs/tags/v0.8.1";
      flake = false;
    };

    hyperframes-src = {
      url = "git+https://github.com/heygen-com/hyperframes.git?rev=25a4829d098f4215f8c82d284c5a15e761a809f9";
      flake = false;
    };

    hyperframes-npm = {
      url = "file+https://registry.npmjs.org/-/package/hyperframes/dist-tags";
      flake = false;
    };

    superpowers-src = {
      url = "github:obra/superpowers";
      flake = false;
    };

    kokoro-pypi = {
      url = "file+https://pypi.org/pypi/kokoro-onnx/json";
      flake = false;
    };

    torch-pypi = {
      url = "file+https://pypi.org/pypi/torch/json";
      flake = false;
    };

    transformers-pypi = {
      url = "file+https://pypi.org/pypi/transformers/json";
      flake = false;
    };

    neurakeep-npm = {
      url = "file+https://registry.npmjs.org/-/package/neurakeep/dist-tags";
      flake = false;
    };

    local-hardware = {
      url = "path:/etc/nixos/hardware-configuration.nix";
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

      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          formatting = pkgs.runCommand "check-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            cd ${self}
            find . -name '*.nix' -not -path './modules/desktop/umbriel/*' -not -name 'umbriel.nix' -not -name 'hardware-configuration.nix' -print0 | xargs -0 nixfmt --check
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
            python3 -c "import tomllib; tomllib.load(open('${self}/modules/home-manager/programs/noctalia/config.toml','rb'))"
            touch $out
          '';
        };

      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          craft-launcher = pkgs.callPackage ./modules/packages/media/craft-launcher/package.nix { };
          helium = pkgs.callPackage ./modules/browsers/helium/package.nix { };
          openchamber = pkgs.callPackage ./modules/packages/agent/openchamber/package.nix { };
          update-user-apps = pkgs.writeShellApplication {
            name = "update-user-apps";
            runtimeInputs = [
              pkgs.nix-update
              pkgs.git
            ];
            text = ''
              root="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
              cd "$root"
              nix-update --flake .#craft-launcher
              nix-update --flake .#helium
              nix-update --flake .#openchamber
            '';
          };
          hyperframes-skills = pkgs.callPackage ./modules/packages/media/hyperframes/skills.nix {
            hyperframesSrc = inputs.hyperframes-src;
          };
          agent-skills = pkgs.callPackage ./modules/packages/agent/skills/package.nix { };
          default = self.packages.x86_64-linux.craft-launcher;
        };

      nixosConfigurations."quietcraft" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/quietcraft
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
