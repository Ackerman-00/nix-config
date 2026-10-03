# OpenCode desktop, vendored in-tree: the official prebuilt .deb.
# package.nix reads version + hash from the `opencode-feed` flake input, so
# flake.lock is the pin and `nix flake update` is the whole update procedure.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  opencode-desktop = pkgs.callPackage ./package.nix { opencodeFeed = inputs.opencode-feed; };
in
{
  options.my.opencode.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "OpenCode desktop client.";
  };

  config = lib.mkIf config.my.opencode.enable {
    environment.systemPackages = [ opencode-desktop ];
  };
}
