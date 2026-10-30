{ _, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      http-connections = 50;
      download-buffer-size = 33554432;
      fallback = true;
      keep-outputs = true;
      warn-dirty = false;
      allowed-users = [
        "root"
        "ackerman"
      ];
      extra-substituters = [ "https://umbriel.cachix.org" ];
      extra-trusted-public-keys = [
        "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
      ];
    };

    optimise.automatic = true;
  };
}
