# Nix store: caches, offline dedup timer, daily GC.
{ _, ... }:
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
      # cache.nixos.org is already in nix's default substituters.
      # Umbriel + xdg-desktop-portal-umbriel come from a cachix cache; add
      # it as an *extra* substituter so a missing cache nar falls back to
      # the defaults instead of replacing them.
      extra-substituters = [ "https://umbriel.cachix.org" ];
      extra-trusted-public-keys = [
        "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
      ];
    };

    optimise.automatic = true;

    # nh.clean (maintenance.nix) is the single cleanup mechanism: it keeps
    # recent generations for rollback. Enabling nix.gc.automatic alongside it
    # warns and risks the two collectors fighting.
    gc.automatic = false;
  };
}
