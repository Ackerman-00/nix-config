# General
{ config, ... }:
{
  programs.umbriel.settings = {
    include.optional.files = [
      "${config.home.homeDirectory}/.config/umbriel/noctalia.toml"
    ];

    general = {
      mod_key = "Super";
      autostart = [ "noctalia" ];
      xwayland = true;
      show_cheatsheet = false;
      focus_on_activate = false;
      honor_restored_maximize = false;
    };
  };
}
