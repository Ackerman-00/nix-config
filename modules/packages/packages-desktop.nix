{
  config,
  inputs,
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

      adw-gtk3
      bibata-cursors
      gsettings-desktop-schemas
      # tela-icon-theme # 2026-10-02: store path has XFS metadata corruption
      # (inode 0x29e12b85, 'Structure needs cleaning'). Disabled until xfs_repair
      # from a live USB; re-enable after. vimix-icon-theme below covers icons.
      vimix-icon-theme
      kdePackages.qt6ct
      kdePackages.qtstyleplugin-kvantum
      nwg-look
    ];

  };
}
