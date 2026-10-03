# config.kdl, build-time validated by the flake module.
{
  programs.niri.config = builtins.readFile ./config.kdl;
}
