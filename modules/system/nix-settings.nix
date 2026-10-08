# Nix store: caches, offline dedup timer, daily GC.
{ lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Let flake.nix's nixConfig (the substituter pair below, declaring
      # umbriel.cachix.org for first-switch bootstrap) actually apply.
      # Without this, nix refuses untrusted flake configuration and warns
      # every time the flake is evaluated, silently ignoring those
      # substituters until the built system provides them.
      #
      # Trade-off, knowingly accepted: any flake you run nix against can
      # now set nix settings, including `post-build-hook`, which is
      # arbitrary code run on a successful build. Safe as long as you only
      # build flakes you trust. Remove this line to close that surface,
      # then delete the nixConfig block in flake.nix to silence the
      # warning instead.
      accept-flake-config = true;
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
      # Umbriel + xdg-desktop-portal-umbriel. Verbatim from
      # docs.noctalia.dev/umbriel "Binary cache"; upstream flake.nix ships
      # no nixConfig of its own, so the substituter must be declared here.
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
