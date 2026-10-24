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
