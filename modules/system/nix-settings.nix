# Nix store: caches, offline dedup timer, weekly GC.
{ lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = false;
      max-jobs = "auto";
      http-connections = 50;
      download-buffer-size = 268435456;
      fallback = true;
      keep-outputs = true;
      warn-dirty = false;
      trusted-users = [
        "root"
        "ackerman"
      ];
      substituters = lib.mkForce [ "https://cache.nixos.org" ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      extra-substituters = [
        "https://niri-epireyn.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niri-epireyn.cachix.org-1:tlVyFN7CtsDT+ZcLPS+ekFWeT1X6X4OqvWqbBMyIzFA="
      ];
    };

    optimise.automatic = true;

    # nh.clean (maintenance.nix) is the single cleanup mechanism: it keeps
    # recent generations for rollback. Enabling nix.gc.automatic alongside it
    # warns and risks the two collectors fighting.
    gc.automatic = false;
  };
}
