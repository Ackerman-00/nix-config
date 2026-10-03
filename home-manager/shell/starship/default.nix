# Starship prompt.
{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = import ./settings.nix;
  };

  # Alt preset, activate via STARSHIP_CONFIG.
  xdg.configFile."starship/powerline.toml".source =
    (pkgs.formats.toml { }).generate "powerline.toml"
      (import ./powerline.nix);
}
