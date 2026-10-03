# Niri compositor via epireyn/niri-flake.
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  environment.systemPackages = [ pkgs.xwayland-satellite-unstable ];

  environment.pathsToLink = [ "/share/wayland-sessions" ];
}
