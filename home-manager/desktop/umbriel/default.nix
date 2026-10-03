# Umbriel config
{
  imports = [
    ./general.nix
    ./env.nix
    ./core.nix
    ./binds.nix
    ./rules.nix
    ./validate.nix
  ];

  programs.umbriel = {
    enable = true;
    package = null;
  };
}
