{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.gaming.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Gaming packages.";
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
