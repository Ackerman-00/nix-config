# Login session: compositor binary, greeter, Wayland env, portals, dirs.
{ pkgs, ... }:
{
  programs.umbriel.enable = true;

  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = {
      cursor.size = 24;
      keyboard.layout = "us";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  xdg = {
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
      # Umbriel's own portal handles most, GTK picks up file chooser.
      config.umbriel."org.freedesktop.impl.portal.FileChooser" = "gtk";
    };

    mime.defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
}
