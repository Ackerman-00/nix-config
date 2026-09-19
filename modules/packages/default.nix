# Package sets, one file per role (toggle via my.<role>.enable).
{
  imports = [
    ./packages-desktop.nix
    ./packages-apps.nix
    ./packages-utils.nix
    ./packages-gaming.nix
    ./packages-dev.nix
  ];
}
