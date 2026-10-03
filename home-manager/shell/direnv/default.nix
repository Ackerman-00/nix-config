# direnv + nix-direnv: auto-enter project flakes on cd.
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
