# Machine fundamentals: nix, boot, network, locale, user.
{
  imports = [
    ./nix-settings.nix
    ./boot.nix
    ./network.nix
    ./locale.nix
    ./users.nix
  ];
}
