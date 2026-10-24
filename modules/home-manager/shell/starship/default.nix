{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = import ./settings.nix;
  };

  xdg.configFile."starship/powerline.toml".source =
    (pkgs.formats.toml { }).generate "powerline.toml"
      (import ./powerline.nix);
}
