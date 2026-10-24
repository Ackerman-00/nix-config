{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.neurakeep;
  hm = inputs.home-manager.lib;
  src = ./files;
  homeDir = config.users.users.ackerman.home;
  node = pkgs.nodejs_latest;
in
{
  options.my.neurakeep = {
    enable = lib.mkEnableOption "Install the NeuraKeep runtime and expose it to OpenCode." // {
      default = true;
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = (builtins.fromJSON (builtins.readFile inputs.neurakeep-npm)).latest;
      description = ''
        Version of the NeuraKeep runtime. It comes from the npm dist-tags feed,
        so `nix flake update neurakeep-npm` moves it.
      '';
    };

    dir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/.local/share/neurakeep";
      description = "Runtime home: node_modules, the vault and the capture state.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.ackerman.home = {
      file = {
        ".local/share/neurakeep/lib.mjs".source = "${src}/lib.mjs";
        ".local/share/neurakeep/backfill.mjs".source = "${src}/backfill.mjs";
        ".local/share/neurakeep/extractors/owner-facts.mjs".source = "${src}/extractors/owner-facts.mjs";
      };
      activation.neurakeep-runtime = hm.hm.dag.entryAfter [ "writeBoundary" ] ''
        installed_version() {
          [ -f "${cfg.dir}/node_modules/neurakeep/package.json" ] || return 1
          ${pkgs.gnused}/bin/sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            "${cfg.dir}/node_modules/neurakeep/package.json" | head -n 1
        }
        installed_marker() {
          [ -f "${cfg.dir}/$1" ] || return 1
          ${pkgs.gnused}/bin/sed -n '1p' "${cfg.dir}/$1"
        }
        abi="$(${node}/bin/node -p 'process.versions.modules')"
        run mkdir -p "${cfg.dir}"
        if [ "$(installed_version || true)" != "${cfg.version}" ] || [ "$(installed_marker .node-abi || true)" != "$abi" ]; then
          run ${pkgs.coreutils}/bin/env PATH="${node}/bin:$PATH" ${node}/bin/npm --prefix "${cfg.dir}" install --no-audit --no-fund \
            --save-exact "neurakeep@${cfg.version}"
          run ${node}/bin/node -e "require('node:fs').writeFileSync('${cfg.dir}/.node-abi', '$abi\n')"
        fi
        if [ ! -f "${cfg.dir}/vault/config.json" ] || [ "$(installed_marker .init-version || true)" != "${cfg.version}" ]; then
          run ${node}/bin/node "${cfg.dir}/node_modules/neurakeep/dist/cli/index.js" init \
            --root "${cfg.dir}/vault"
          run ${node}/bin/node -e "require('node:fs').writeFileSync('${cfg.dir}/.init-version', '${cfg.version}\n')"
        fi
      '';
    };
  };
}
