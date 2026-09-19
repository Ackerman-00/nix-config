# Shell programs: prompt, git, shell itself (user shell set in system/users.nix).
{
  programs = {
    zsh.enable = true;
    starship.enable = true;
    git.enable = true;
  };
}
