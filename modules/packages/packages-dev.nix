{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.dev.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Dev tools and python env.";
  };

  config = lib.mkIf config.my.dev.enable {
    environment.systemPackages = with pkgs; [
      fd
      gcc
      lazygit
      nixfmt
      nodejs
      rustup

      (python3.withPackages (
        ps: with ps; [
          openai
          requests
          pip
          numpy
        ]
      ))
    ];
  };
}
