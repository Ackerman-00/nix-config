# opencode-desktop: nixpkgs build (official SST client) behind a toggle.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.opencode-desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "opencode-desktop AI client.";
  };

  config = lib.mkIf config.my.opencode-desktop.enable {
    environment.systemPackages = with pkgs; [
      opencode-desktop
    ];
  };
}
