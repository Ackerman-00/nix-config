# Concat video editor, vendored in-tree: the official prebuilt .deb.
# package.nix reads version + url + sha256 from the `concat-manifest` flake
# input, so flake.lock is the pin and `nix flake update` is the whole update
# procedure.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  concat = pkgs.callPackage ./package.nix { concatManifest = inputs.concat-manifest; };
in
{
  options.my.concat.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Concat video editor.";
  };

  config = lib.mkIf config.my.concat.enable {
    environment.systemPackages = [ concat ];
  };
}
