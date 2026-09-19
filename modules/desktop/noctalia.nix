# Noctalia shell, flake build pulled binary-only from noctalia.cachix.org.
# Autostarted by Umbriel (see home-manager desktop config), so no systemd unit.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.noctalia.nixosModules.default ];

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
}
