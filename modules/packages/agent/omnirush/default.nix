{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  omnirush = pkgs.callPackage ./package.nix { omnirushFeed = inputs.omnirush-feed; };
in
{
  options.my.omnirush.enable = lib.mkEnableOption "OmniRush desktop." // {
    default = true;
  };

  config = lib.mkIf config.my.omnirush.enable {
    environment.systemPackages = [ omnirush ];
  };
}
