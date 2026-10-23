# Craft launcher
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  options.my.craftLauncher = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "The Craft launcher.";
    };
  };

  config = lib.mkIf config.my.craftLauncher.enable {
    environment.systemPackages = [
      (pkgs.callPackage ./package.nix { craftLauncherFeed = inputs.craft-launcher-feed; })
    ];
  };
}
