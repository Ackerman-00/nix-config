# Noctalia shell, from nixpkgs (no flake pin).
# NOTE: nixpkgs ships 4.7.7 while the old flake pin tracked 5.2.0. The
# 5.x-era config.toml still applies (unknown keys warn, they don't fail),
# but Umbriel-era shell integration expects 5.x. If the bar/panels
# misbehave under Umbriel, this downgrade is the first suspect.
_: {
  programs.noctalia.enable = true;
}
