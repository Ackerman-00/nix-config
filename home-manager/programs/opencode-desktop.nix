# opencode-desktop: nixpkgs build (official SST client), user install.
{ pkgs, ... }:
{
  home.packages = [ pkgs.opencode-desktop ];
}
