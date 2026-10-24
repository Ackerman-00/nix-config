{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.dev.enable = lib.mkEnableOption "Dev tools and python env." // {
    default = true;
  };

  config = lib.mkIf config.my.dev.enable {
    environment.systemPackages = with pkgs; [
      fd
      gcc
      pkg-config
      lazygit
      nixfmt
      nodejs_latest
      rustup
      uv
      pipx
    ];

    my.python.packages = [
      "ipython"
      "debugpy"
      "openai"
      "requests"
      "numpy"
      "pyyaml"
    ];
  };
}
