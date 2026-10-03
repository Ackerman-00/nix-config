# Umbriel compositor (noctalia-dev/umbriel, wlroots-based, v0.1.0).
# Binary, Wayland session, systemd user service and portal come from the
# upstream flake's nixosModule (wired in flake.nix outputs); this file is
# the on/off switch. Config lives in home-manager/desktop/umbriel via
# programs.umbriel.settings (TOML). Niri stays enabled as fallback session.
#
# Xwayland here is classic wlroots Xwayland: upstream wraps nixpkgs xwayland
# onto Umbriel's PATH, starting lazily per `general.xwayland`. No
# xwayland-satellite needed for Umbriel (that one serves niri only).
_: {
  programs.umbriel.enable = true;
}
