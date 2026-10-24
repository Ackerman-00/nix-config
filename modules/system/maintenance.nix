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

  system.switch.inhibitors = {
    systemd-version = config.systemd.package.version;
  };

  systemd.oomd.enable = true;
}
