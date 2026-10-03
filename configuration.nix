{ lib, ... }:
{
  imports =
    lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
    ++ [ ./modules ];

  # Toggle groups with my.<name>.enable = false.

  system.stateVersion = "26.11";
}
