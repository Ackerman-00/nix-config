{ pkgs, ... }:
{
  programs = {
    dconf.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        curl
        expat
        fuse3
        glib
        icu
        libgcc
        libxkbcommon
        libxml2
        nss
        openssl
        vulkan-loader
        zlib
      ];
    };
  };
}
