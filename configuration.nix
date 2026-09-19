{ lib, ... }:
{
  imports =
    lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
    ++ [ ./modules ];

  # Set false to trim a group without touching package lists:
  # my.gaming.enable = false;
  # my.dev.enable = false;
  # my.apps.enable = false;
  # my.utils.enable = false;
  # my.desktop.enable = false;
  # my.helium.enable = false;
  # my.firefox.enable = false;

  system.stateVersion = "26.11";
}
