# Git: credential helper via GNOME Keyring.
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.git.override { withLibsecret = true; };

    settings = {
      user.name = "Qᴜɪᴇᴛᴄʀᴀꜰᴛ";
      user.email = "mdzunaid384@gmail.com";
      credential.helper = "libsecret";
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      safe.directory = [ "/etc/nixos" ];
    };
  };
}
