{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.gaming.enable = lib.mkEnableOption "Gaming packages." // {
    default = true;
  };

  config = lib.mkIf config.my.gaming.enable {
    programs = {
      steam.enable = true;
      gamemode.enable = true;
      gamescope.enable = true;
    };

    environment.systemPackages = with pkgs; [
      faugus-launcher
      heroic
      mangohud
      protonplus
      protontricks
      vulkan-tools
    ];
  };
}
