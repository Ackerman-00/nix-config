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
  options.my.concat.enable = lib.mkEnableOption "Concat video editor." // {
    default = true;
  };

  config = lib.mkIf config.my.concat.enable {
    environment.systemPackages = [ concat ];
  };
}
