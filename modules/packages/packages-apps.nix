{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.apps.enable = lib.mkEnableOption "Desktop apps." // {
    default = true;
  };

  config = lib.mkIf config.my.apps.enable {
    home-manager.users.ackerman.xdg.configFile."mpv/mpv.conf".text = ''
      hwdec=auto
    '';

    environment.systemPackages = with pkgs; [
      blender
      chatgpt
      evince
      file-roller
      gnome-text-editor
      godot
      imv
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
