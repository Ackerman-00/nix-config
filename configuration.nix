{ lib, ... }:
{
  # hardware-configuration.nix is gitignored (machine-specific UUIDs); build
  # with `path:` so the flake can still see it.
  imports =
    lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
    ++ [ ./modules ];

  # Toggle groups with my.<name>.enable = false.

  system.stateVersion = "26.11";
}
