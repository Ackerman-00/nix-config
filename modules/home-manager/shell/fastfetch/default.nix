# Fastfetch + random-logo wrapper.
{ pkgs, ... }:
let
  esc = builtins.fromJSON ''"\u001b"'';
  fastfetch-sh = pkgs.writeShellApplication {
    name = "fastfetch.sh";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      fastfetch
    ];
    text = ''
      #!/usr/bin/env bash

      confDir="''${XDG_CONFIG_HOME:-$HOME/.config}"
      logoDir="''${confDir}/fastfetch/logo"

      mkdir -p "$logoDir"

      chosen_logo_path=$(find -L "$logoDir" -maxdepth 1 -type f \
        \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.txt" \) \
        2>/dev/null | shuf -n 1)

      if [ -z "$chosen_logo_path" ]; then
        exec fastfetch
      fi

      extension="''${chosen_logo_path##*.}"
      extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

      if [[ "$extension" == "txt" ]]; then
        exec fastfetch --logo-type file --logo "$chosen_logo_path"
      else
        exec fastfetch --logo-type kitty --logo "$chosen_logo_path"
      fi
    '';
  };
in
{
  programs.fastfetch.enable = true;

  programs.fastfetch.settings = import ./settings.nix { inherit esc; };

  xdg.configFile."fastfetch/logo" = {
    source = ./logo;
    recursive = true;
  };

  home.file.".local/bin/fastfetch.sh".source = "${fastfetch-sh}/bin/fastfetch.sh";
}
