{ config, inputs, ... }:
{
  imports = [
    inputs.umbriel.homeModules.default
    ./modules/home-manager/programs/noctalia
    ./modules/home-manager/programs/vesktop.nix
    ./modules/home-manager/shell
  ];

  home = {
    stateVersion = "26.11";

    sessionPath = [
      "${config.home.homeDirectory}/.cargo/bin"
    ];
  };
}
