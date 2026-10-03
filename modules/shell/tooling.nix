# Shell programs: shell, git (credential helper in home-manager/shell/git).
{
  programs = {
    zsh = {
      enable = true;
      interactiveShellInit = ''
        # Rehash before every prompt so commands never resolve to store
        # paths from before the last nixos-rebuild switch.
        autoload -Uz add-zsh-hook
        rehash_on_precmd() { hash -r; }
        add-zsh-hook precmd rehash_on_precmd
      '';
    };
    git.enable = true;
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
