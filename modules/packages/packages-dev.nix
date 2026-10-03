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
      nodejs
      rustup
      uv
      pipx
    ];

    # Domain libs for the single interpreter (python-env.nix builds it).
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
