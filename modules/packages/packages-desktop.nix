{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  options.my.desktop.enable = lib.mkEnableOption "Desktop shell and theming packages." // {
    default = true;
  };

  config = lib.mkIf config.my.desktop.enable {
    environment.systemPackages = with pkgs; [

      adw-gtk3
      bibata-cursors
      gsettings-desktop-schemas
      vimix-icon-theme
      kdePackages.qt6ct
      kdePackages.qtstyleplugin-kvantum
      nwg-look
    ];

  };
}
