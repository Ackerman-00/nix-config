# OpenCode
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./config.nix ];

  options.my.opencode = {
    enable = lib.mkEnableOption "The OpenCode app and its runtime config." // {
      default = true;
    };

    config = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        The OpenCode runtime config: the global AGENTS.md, the global
        subagents, the plugins, the slash commands and opencode.json.
      '';
    };
  };

  config = lib.mkIf config.my.opencode.enable {
    environment.systemPackages = [
      pkgs.opencode
      pkgs.opencode-desktop
    ];
  };
}
