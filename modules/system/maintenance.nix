# Machine maintenance.
{ config, ... }:
{
  programs.nh = {
    enable = true;
    flake = "path:/etc/nixos";

    # Daily safe cleanup: keeps the 5 newest generations plus everything
    # younger than 7 days, so a rollback target always survives. This is the
    # replacement for `nix-collect-garbage -d`, which deletes ALL old
    # generations and leaves nothing to roll back to when the new one
    # misbehaves (broken greeter/shell after an update). Manual equivalent:
    #   nh clean all --keep 5 --keep-since 7d
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
