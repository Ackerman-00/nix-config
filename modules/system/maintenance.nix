{ config, ... }:
{
  programs.nh = {
    enable = true;
    flake = "path:/etc/nixos";

    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  services.fstrim.enable = true;

  system.switch.inhibitors = {
    systemd-version = config.systemd.package.version;
  };
}
