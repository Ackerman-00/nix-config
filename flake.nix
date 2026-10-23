{
  description = "NixOS Optimized Flake";

  # Eval-time caches
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

    # Umbriel compositor, official nix modules
    umbriel.url = "github:noctalia-dev/umbriel/cachix";

    # Craft launcher release feed
    craft-launcher-feed = {
      url = "file+https://api.github.com/repos/storytold/craft-launcher/releases/latest";
      flake = false;
    };

    # Helium versions.json pin
    helium-pin = {
      url = "github:amaanq/helium-flake";
      flake = false;
    };

    # Concat release manifest
    concat-manifest = {
      url = "file+https://github.com/jub0t/Concat/releases/latest/download/manifest.json";
      flake = false;
    };

    # Blender MCP source, commit pinned
    # nix flake update blender-mcp-src
    blender-mcp-src = {
      url = "github:ahujasid/mcp-for-blender/60d2a31b4632a7bc178f3dd636f7e68dfb5c8ae4";
      flake = false;
    };

    # YouTube transcript MCP source, tag pinned
    mcp-youtube-transcript-src = {
      url = "git+https://github.com/jkawamoto/mcp-youtube-transcript.git?ref=refs/tags/v0.7.0";
      flake = false;
    };

    # HyperFrames source: CLI monorepo and skills
    hyperframes-src = {
      url = "git+https://github.com/heygen-com/hyperframes.git";
      flake = false;
    };

    # HyperFrames CLI version from the npm dist-tags feed
    hyperframes-npm = {
      url = "file+https://registry.npmjs.org/-/package/hyperframes/dist-tags";
      flake = false;
    };

    # Superpowers source
    superpowers-src = {
      url = "github:obra/superpowers";
      flake = false;
    };

    # Kokoro version, from the PyPI metadata feed
    kokoro-pypi = {
      url = "file+https://pypi.org/pypi/kokoro-onnx/json";
      flake = false;
    };

    # MusicGen deps
    torch-pypi = {
      url = "file+https://pypi.org/pypi/torch/json";
      flake = false;
    };

    transformers-pypi = {
      url = "file+https://pypi.org/pypi/transformers/json";
      flake = false;
    };

    # NeuraKeep version
    neurakeep-npm = {
      url = "file+https://registry.npmjs.org/-/package/neurakeep/dist-tags";
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

      # The merged HyperFrames skill set (upstream + local OpenCode
      # adaptations), so the skills can be built and inspected on their own.
      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          craft-launcher = pkgs.callPackage ./modules/packages/media/craft-launcher/package.nix {
            craftLauncherFeed = inputs.craft-launcher-feed;
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
