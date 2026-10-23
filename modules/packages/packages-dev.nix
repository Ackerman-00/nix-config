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
      pkg-config
      lazygit
      nixfmt
      nodejs_latest
      rustup
      uv
      pipx
    ];

    # Domain libs
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
