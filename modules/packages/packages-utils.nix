{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.utils.enable = lib.mkEnableOption "CLI utilities and codecs." // {
    default = true;
  };

  config = lib.mkIf config.my.utils.enable {
    environment.systemPackages = with pkgs; [
      btop
      brightnessctl
      cava
      cliphist
      efibootmgr
      eza
      ffmpeg-full
      ffmpegthumbnailer
      fzf
      glib
      gpu-screen-recorder
      grim
      libheif
      libsecret
      libva-utils
      nh
      nvd
      p7zip
      rar
      ripgrep
      slurp
      swappy
      unzip
      wget
      xdg-user-dirs
      zip

      gst_all_1.gst-libav
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-ugly
    ];
  };
}
