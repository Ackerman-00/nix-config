# OpenChamber desktop, vendored in-tree: the official AppImage (see
# package.nix for the bump procedure: version + URL + hash literals).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  openchamber = pkgs.callPackage ./package.nix { };
in
{
  options.my.openchamber.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "OpenChamber agentic development environment.";
  };

  config = lib.mkIf config.my.openchamber.enable {
    environment.systemPackages = [ openchamber ];
  };
}
