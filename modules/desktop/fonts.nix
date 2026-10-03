{ pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      anonymousPro
      ibm-plex
      maple-mono.NF
      lohit-fonts.bengali
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      font-awesome
      material-symbols
      nerd-fonts.jetbrains-mono
    ];
    fontconfig = {
      enable = true; # packages alone don't reach pickers without this
      defaultFonts = {
        serif = [
          "Maple Mono NF"
          "Noto Serif"
          "Noto Serif Bengali"
        ];
        sansSerif = [
          "Maple Mono NF"
          "Noto Sans"
          "Noto Sans Bengali"
        ];
        monospace = [
          "Maple Mono NF"
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
