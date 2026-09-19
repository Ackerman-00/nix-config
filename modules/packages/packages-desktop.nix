{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Desktop shell and theming packages.";
  };

  config = lib.mkIf config.my.desktop.enable {
    environment.systemPackages = with pkgs; [
      xwayland-satellite

      adw-gtk3
      bibata-cursors
      tela-icon-theme
      vimix-icon-theme
      kdePackages.qt6ct
      kdePackages.qtstyleplugin-kvantum
      nwg-look
    ];
  };
}
