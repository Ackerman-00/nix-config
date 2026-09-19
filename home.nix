{ config, ... }:
{
  imports = [
    ./home-manager/desktop/umbriel
    ./home-manager/programs/noctalia
    ./home-manager/programs/opencode.nix
  ];

  home = {
    stateVersion = "26.11";

    sessionPath = [
      "${config.home.homeDirectory}/.cargo/bin"
    ];
  };
}
