# OpenCode config
{
  config,
  lib,
  inputs,
  ...
}:
let
  enabled = config.my.opencode.config;
  src = ./config;

  neurakeepCfg = builtins.fromJSON (builtins.readFile "${src}/neurakeep-memory.json");
  neurakeepServer = {
    type = "local";
    command = [
      "node"
      "${config.my.neurakeep.dir}/node_modules/neurakeep/dist/cli/index.js"
      "mcp"
      "--root"
      neurakeepCfg.vault
    ];
    disabled = !config.my.mcp.neurakeep.enable;
    timeout = 20000;
  };

  superpowersRev = inputs.superpowers-src.rev;
  base = builtins.fromJSON (
    builtins.replaceStrings [ "\${superpowers_rev}" ] [ superpowersRev ] (
      builtins.readFile "${src}/opencode.base.json"
    )
  );

  toServer =
    s:
    {
      type = "local";
      inherit (s) command;
    }
    // (if s.environment != { } then { inherit (s) environment; } else { })
    // {
      disabled = !s.enabled;
      inherit (s) timeout;
    };

  regularFiles = dir: lib.filterAttrs (_: v: v == "regular") (builtins.readDir dir);
  treeOf =
    dir: sub:
    lib.mapAttrs'
      (n: v: {
        name = ".config/opencode/${sub}/${n}";
        value = v;
      })
      (
        lib.genAttrs (lib.attrNames (regularFiles dir)) (n: {
          source = "${src}/${sub}/${n}";
        })
      );
in
{
  config = lib.mkIf enabled {
    home-manager.users.ackerman.programs.opencode = {
      enable = true;
      context = src + "/AGENTS.md";
      agents = src + "/agents";
      commands = src + "/commands";
      settings = base // {
        mcp = {
          servers =
            lib.mapAttrs (_: toServer) config.my.mcp.servers
            // lib.optionalAttrs config.my.neurakeep.enable {
              "neurakeep-global" = neurakeepServer;
            };
        };
      };
    };

    home-manager.users.ackerman.home = {
      file = {
        ".config/opencode/REVIEW-LOOP.md".source = "${src}/REVIEW-LOOP.md";
        ".config/opencode/neurakeep-memory.json".source = "${src}/neurakeep-memory.json";
        ".config/opencode/review-loop.json".source = "${src}/review-loop.json";
      }
      // (lib.removeAttrs (treeOf ./config/plugins "plugins") (
        lib.optionals (!config.my.neurakeep.enable) [ ".config/opencode/plugins/neurakeep-memory.js" ]
      ));
    };
  };
}
