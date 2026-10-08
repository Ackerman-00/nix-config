# Umbriel compositor (noctalia-dev/umbriel, wlroots-based, v0.1.0).
# Binary, Wayland session, systemd user service and portal come from the
# upstream flake's nixosModule (wired in flake.nix outputs); this file is
# the on/off switch.
#
# No declarative config: home-manager/desktop/umbriel was removed. Umbriel
# now loads its packaged share/umbriel/config.toml, then any
# $XDG_CONFIG_HOME/umbriel/config.toml you hand-edit — those paths stay
# watched, so edits apply live, no rebuild. To go back to declarative, add
# `programs.umbriel.settings = { ... }` here or in a home-manager module.
#
# Sole compositor: niri was removed (it could not be substituted from its
# cache; see flake.nix inputs). Xwayland is classic wlroots Xwayland —
# upstream wraps nixpkgs xwayland onto Umbriel's PATH, starting lazily per
# `general.xwayland`. The xwayland-satellite niri needed went with it.
_: {
  programs.umbriel.enable = true;
}
