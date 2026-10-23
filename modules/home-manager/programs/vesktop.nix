# Vesktop launcher: pin default icon, immune to icon theme.
{ pkgs, ... }:
{
  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    genericName = "Internet Messenger";
    comment = "Alternative Discord client with Vencord built-in";
    exec = "vesktop %U";
    icon = "${pkgs.vesktop}/share/icons/hicolor/256x256/apps/vesktop.png";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
    startupNotify = true;
  };
}
