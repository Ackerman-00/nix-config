{
  programs = {
    zsh = {
      enable = true;
      interactiveShellInit = ''
        autoload -Uz add-zsh-hook
        rehash_on_precmd() { hash -r; }
        add-zsh-hook precmd rehash_on_precmd
      '';
    };
    git.enable = true;
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
