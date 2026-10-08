{ config, inputs, ... }:
{
  imports = [
    inputs.umbriel.homeModules.default
    ./home-manager/programs/noctalia
    ./home-manager/programs/vesktop.nix
    ./home-manager/programs/opencode.nix
    ./home-manager/shell
  ];

  home = {
    stateVersion = "26.11";

    sessionPath = [
      "${config.home.homeDirectory}/.cargo/bin"
    ];
  };
}
