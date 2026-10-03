{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    fwupd.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = false;
    gnome.gnome-keyring.enable = true;
    gnome.localsearch.enable = false;
    xserver.xkb.layout = "us";
    dbus.packages = [ pkgs.nautilus ];
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
  };

  security = {
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;

    polkit = {
      enable = true;
      enablePkexecWrapper = true;
    };
  };

  systemd.user.services.speech-dispatcher = {
    enable = false;
    aliases = [ ];
    wantedBy = [ ];
  };
}
