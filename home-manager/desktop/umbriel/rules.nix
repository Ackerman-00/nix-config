# Layer rules
{
  programs.umbriel.settings = {
    window_rule = [
      {
        blur = true;
        blur_optimized = false;
        blur_popups = true;
        blur_ignore_alpha = 0.05;
      }
      { opacity = 0.80; }
      {
        match.app_id = "steam_app.*|ffxiv.*";
        default_floating = true;
        opacity = 1.0;
        blur = false;
        blur_popups = false;
      }
      {
        match.xdg_tag = "^proton-game$";
        default_floating = true;
        opacity = 1.0;
        blur = false;
        blur_popups = false;
      }
      {
        match.content_type = "game";
        default_floating = true;
        opacity = 1.0;
        blur = false;
        blur_popups = false;
      }
      {
        match.content_type = "video";
        blur = false;
        opacity = 1.0;
      }
      {
        match.content_type = "photo";
        blur = false;
        opacity = 1.0;
      }
      {
        match.app_id = "^(Alacritty|kitty|ghostty|foot)$";
        opacity = 0.9;
      }
      {
        match.app_id = "[Vv]esktop|[Dd]iscord|brave-browser|chromium|helium";
        opacity = 0.93;
      }
      {
        match.app_id = "^org.mozilla.firefox$|[Ff]irefox";
        blur = true;
        blur_optimized = false;
        blur_popups = true;
        blur_ignore_alpha = 0.05;
        opacity = 0.95;
        focus_on_activate = true;
        default_scrolling_column = "browsers";
        default_scrolling_column_order = 20;
      }
      {
        match.app_id = "^[Zz]en";
        blur = false;
        opacity = 1.0;
        focus_on_activate = true;
        default_scrolling_column = "browsers";
        default_scrolling_column_order = 30;
      }
      {
        match.app_id = "^([Hh]elium|[Bb]rave|[Cc]hromium)";
        focus_on_activate = true;
        default_scrolling_column = "browsers";
        default_scrolling_column_order = 10;
      }
      {
        match.app_id = "^(org[.]gnome[.]Nautilus|org[.]gnome[.]Settings|org[.]gnome[.]Loupe|org[.]gnome[.]TextEditor)$";
        blur = true;
        blur_optimized = true;
        blur_popups = false;
        corner_radius = 0;
        shadow = false;
        opacity = 0.90;
      }
      {
        match.app_id = "blender";
        default_floating = false;
        opacity = 1.0;
        blur = false;
        blur_popups = false;
      }
      {
        match.app_id = "[Kk]vantum|qt5ct|qt6ct|nwg-look|org.kde.ark|pavucontrol|blueman|[Qq]bittorrent";
        default_floating = true;
      }
      {
        match.app_id = "gnome-text-editor|org[.]gnome[.]TextEditor";
        default_floating = true;
      }
      {
        match.title = "[Kk]vantum";
        default_floating = true;
      }
      {
        match.app_id = "[Qq]bittorrent";
        default_floating_size_px = {
          width = 880;
          height = 500;
        };
      }
      {
        match.title = "^Open$|^Save As$|^Choose Files$|^File Operation Progress$";
        default_floating = true;
      }
      {
        match.app_id = "^dev.noctalia.UmbrielSharePicker$";
        default_floating = true;
        default_floating_size_px = {
          width = 800;
          height = 600;
        };
        default_position = {
          x = 32;
          y = 32;
          anchor = "bottom_right";
        };
      }
      {
        match.app_id = "^dev.noctalia.Noctalia$";
        default_floating = false;
        default_floating_size_px = {
          width = 1020;
          height = 900;
        };
        blur = true;
        blur_popups = false;
        opacity = 1.0;
      }
      {
        match.app_id = "^scratchpad-terminal$";
        default_scratchpad = "default";
        default_output = "Samsung Electric Company S19C170 HYCFB02483";
      }
      {
        match.is_alone = true;
        default_maximize = true;
      }
    ];

    layer_rule = [
      {
        match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\"]*)$";
        blur = true;
        blur_ignore_alpha = 0.5;
        blur_optimized = false;
        blur_popups = true;
      }
    ];
  };
}
