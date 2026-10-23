# Freebuff desktop
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  freebuff = pkgs.callPackage ./package.nix { freebuffFeed = inputs.freebuff-feed; };
in
{
  options.my.freebuff.enable = lib.mkEnableOption "Freebuff desktop." // {
    default = true;
  };

  config = lib.mkIf config.my.freebuff.enable {
    environment.systemPackages = [ freebuff ];
  };
}
