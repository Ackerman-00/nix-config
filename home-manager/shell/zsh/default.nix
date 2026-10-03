# Zsh + Oh My Zsh.
{ config, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "sudo"
        "z"
        "web-search"
        "extract"
        "fzf"
        "colored-man-pages"
      ];
    };

    history = {
      size = 100000;
      save = 100000;
      share = true;
      append = true;
      ignoreDups = true;
      ignoreSpace = true;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    shellAliases = {
      c = "clear";
      l = "eza -lh --icons=auto";
      ls = "eza -1 --icons=auto";
      ll = "eza -lha --icons=auto --sort=name --group-directories-first";
      ld = "eza -lhD --icons=auto";
      lt = "eza --icons=auto --tree";
      vc = "nvim";
      cdconf = "cd ~/.config";
      cleancache = "rm -rf ~/.zcompdump* ~/.cache/fastfetch";
      ".." = "cd ..";
      "..." = "cd ../..";
      ".3" = "cd ../../..";
      ".4" = "cd ../../../..";
      mkdir = "mkdir -p";
    };

    initContent = ''
      export PATH="${config.home.homeDirectory}/.opencode/bin:$PATH"
      unsetopt nomatch
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
      setopt HIST_REDUCE_BLANKS INC_APPEND_HISTORY

      if [[ $- == *i* && -z "$_FASTFETCH_INITIAL_RUN" ]]; then
        clear
        if [[ -x ~/.local/bin/fastfetch.sh ]]; then
          ~/.local/bin/fastfetch.sh
        elif command -v fastfetch >/dev/null; then
          fastfetch
        fi
        typeset -g _FASTFETCH_INITIAL_RUN=1
      fi
    '';
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];
}
