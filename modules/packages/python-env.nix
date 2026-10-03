# The only `python3.withPackages` site in the tree (a second one
# collides on bin/python). Modules append lib names to
# `my.python.packages` instead of building rival envs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  env = pkgs.python3.withPackages (
    ps:
    map (
      n: ps.${n} or (throw "my.python.packages: no such python package `${n}`")
    ) config.my.python.packages
  );
in
{
  options.my.python.packages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    # NOTE: `default` is ignored once any module defines the option, so
    # the base below lives in `config` (a real definition) and
    # concatenates with dev/tts contributions.
    default = [ ];
    description = "Python libs in the single system-wide interpreter env.";
  };

  config = {
    my.python.packages = [
      "pip"
      "setuptools"
      "wheel"
      "virtualenv"
    ];

    environment.systemPackages = [ env ];
  };
}
