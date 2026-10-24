{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.cline.enable =
    lib.mkEnableOption "The Cline coding agent CLI (opt-in while the nixpkgs package has a broken fixed-output hash)."
    // {
      default = false;
    };

  config = lib.mkIf config.my.cline.enable {
    environment.systemPackages = [ pkgs.cline ];
  };
}
