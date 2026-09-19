# Umbriel config, one topic per file. Merged into programs.umbriel.settings
# (upstream Home Manager path) and written to ~/.config/umbriel/config.toml.
{ inputs, ... }:
{
  imports = [
    inputs.umbriel.homeModules.default
    ./general.nix
    ./env.nix
    ./core.nix
    ./binds.nix
    ./rules.nix
  ];

  programs.umbriel.enable = true;
}
