{ lib, ... }:
{
  # hardware-configuration.nix is gitignored (machine-specific UUIDs); build
  # with `path:` so the flake can still see it.
  # Remove the guard once the real file is committed.
  imports =
    lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix
    ++ [ ../../modules ];

  # Toggle groups with my.<name>.enable = false.

  # NOTE: must equal the release of the ISO used for the FIRST install.
  # Never change this afterwards.
  system.stateVersion = "26.11";
}
