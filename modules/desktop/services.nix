{ pkgs, ... }:
{
  services = {
    gvfs.enable = true;
    udisks2.enable = true;
    fwupd.enable = true; # vendor firmware updates (fwupdmgr)
    power-profiles-daemon.enable = true;
    upower.enable = false; # desktop PC, no battery
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

    # Greeter sync: passwordless Noctalia→login-screen appearance sync.
    # No-op until greeter >= 1.5.0 + Noctalia post-5.0.1; older pairs keep
    # the admin-authenticated legacy path. Never adapted to the old action.
    polkit = {
      enable = true;
      enablePkexecWrapper = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          var allowedUsers = ["ackerman"];
          if (action.id == "org.noctalia.greeter.sync-appearance" &&
              action.lookup("program") == "${pkgs.noctalia-greeter}/bin/noctalia-greeter-apply-appearance" &&
              action.lookup("user") == "root" &&
              subject.local && subject.active &&
              allowedUsers.indexOf(subject.user) >= 0) {
            return polkit.Result.YES;
          }
        });
      '';
    };
  };

  systemd.user.services.speech-dispatcher = {
    enable = false;
    aliases = [ ];
    wantedBy = [ ];
  };
}
