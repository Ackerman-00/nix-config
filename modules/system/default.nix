# Machine fundamentals: nix, boot, network, locale, user.
{
  imports = [
    ./nix-settings.nix
    ./maintenance.nix
    ./boot.nix
    ./network.nix
    ./locale.nix
    ./users.nix
  ];
}
