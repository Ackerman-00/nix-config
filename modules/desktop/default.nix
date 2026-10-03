# Graphical session: greeter, Wayland env, fonts, services, compositor.
{
  imports = [
    ./session.nix
    ./fonts.nix
    ./services.nix
    ./noctalia.nix
    ./umbriel.nix
    ./niri.nix
  ];
}
