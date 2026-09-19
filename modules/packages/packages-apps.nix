{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.apps.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Desktop apps.";
  };

  config = lib.mkIf config.my.apps.enable {
    # GPU decode in mpv (wiki: Accelerated Video Playback).
    home-manager.users.ackerman.xdg.configFile."mpv/mpv.conf".text = ''
      hwdec=auto
    '';

    environment.systemPackages = with pkgs; [
      blender
      evince
      file-roller
      gnome-text-editor
      godot
      imv
      kitty
      loupe
      mpv
      nautilus
      proton-vpn
      qbittorrent
      sassc
      telegram-desktop
      vesktop
      zed-editor
    ];
  };
}
