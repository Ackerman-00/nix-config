# Graphical session: greeter, Wayland env, fonts, services, compositor.
{
  imports = [
    ./session.nix
    ./fonts.nix
    ./services.nix
  ];
}
