{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.brave-origin.enable = lib.mkEnableOption "The Brave Origin browser." // {
    default = true;
  };

  config = lib.mkIf config.my.brave-origin.enable {
    environment.systemPackages = [ pkgs.brave-origin ];
  };
}
