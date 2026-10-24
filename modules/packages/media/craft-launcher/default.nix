{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  options.my.craftLauncher = {
    enable = lib.mkEnableOption "The Craft launcher." // {
      default = true;
    };
  };

  config = lib.mkIf config.my.craftLauncher.enable {
    environment.systemPackages = [
      (pkgs.callPackage ./package.nix { craftLauncherFeed = inputs.craft-launcher-feed; })
    ];
  };
}
