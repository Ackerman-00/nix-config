{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.cline.enable = lib.mkEnableOption "The Cline coding agent CLI." // {
    default = true;
  };

  config = lib.mkIf config.my.cline.enable {
    environment.systemPackages = [ pkgs.cline ];
  };
}
