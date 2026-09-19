# Umbriel system side: package, session, portal. Config fragments live in
# home-manager/desktop/umbriel (upstream Home Manager path).
{
  programs.umbriel.enable = true;

  # Umbriel's own portal handles most, GTK picks up file chooser.
  xdg.portal.config.umbriel."org.freedesktop.impl.portal.FileChooser" = "gtk";
}
