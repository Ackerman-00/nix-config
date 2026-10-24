{ inputs, ... }:
{
  # hardware-configuration.nix is gitignored (machine-specific UUIDs), so it
  # is pulled in through the local-hardware path: input instead of git.
  imports = [
    "${inputs.local-hardware}"
    ../../modules
  ];

  # Toggle groups with my.<name>.enable = false.

  # NOTE: must equal the release of the ISO used for the FIRST install.
  # Never change this afterwards.
  system.stateVersion = "26.11";
}
