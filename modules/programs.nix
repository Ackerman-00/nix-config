{ pkgs, ... }:
{
  # AppImage + portable binaries
  programs = {
    dconf.enable = true;

    appimage = {
      enable = true;
      binfmt = true;
    };

    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        alsa-lib
        at-spi2-core
        cairo
        curl
        dbus
        expat
        fontconfig
        freetype
        fuse3
        gdk-pixbuf
        glib
        gtk3
        icu
        libdrm
        libgcc
        libGL
        libnotify
        libpulseaudio
        libsecret
        libva
        libx11
        libxcb
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxi
        libxinerama
        libxkbcommon
        libxml2
        libxrandr
        libxrender
        libxscrnsaver
        libxtst
        nss
        openssl
        pango
        stdenv.cc.cc.lib
        vulkan-loader
        zlib
      ];
    };
  };
}
