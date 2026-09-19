# Mirrors core.toml 1:1. Shader paths point at ./shaders (vendored into the
# store); commented example blocks kept as notes below their tables.
{
  programs.umbriel.settings = {
    workspaces = {
      back_and_forth = false;
      empty_above = false;
    };

    # Colors: all commented upstream, Noctalia template owns them via noctalia.toml.
    # background/text_primary/text_muted/accent_primary/accent_secondary/
    # warning/error/insert_hint/backdrop/shadow, see Umbriel Appearance reference.

    animation = {
      enabled = true;
      duration_ms = 200;
      curve = "easeout";

      springs.snap = {
        damping = 0.9;
        stiffness = 400;
      };

      windows_in = {
        enabled = true;
        duration_ms = 600;
        curve = "easeout";
        style = "zoom";
        shader = "${./shaders/open.glsl}";
      };

      windows_out = {
        enabled = true;
        duration_ms = 400;
        curve = "easeout";
        style = "slide";
        shader = "${./shaders/close.glsl}";
      };

      windows_move = {
        enabled = true;
        duration_ms = 400;
        curve = "easeout";
      };

      workspaces = {
        enabled = true;
        duration_ms = 500;
        curve = "ease";
      };

      overview = {
        enabled = true;
        duration_ms = 250;
        curve = "easeout";
      };

      scratchpad = {
        enabled = true;
        duration_ms = 250;
        curve = "easeout";
        dim = 0.5;
        blur = true;
        scale = 0.0;
        maximize = false;
        fullscreen = false;
      };

      border = {
        enabled = true;
        duration_ms = 300;
        curve = "easeout";
      };

      dim_unfocused = {
        enabled = false;
        duration_ms = 250;
        curve = "easeout";
        dim = 0.0;
      };

      layers = {
        enabled = true;
        duration_ms = 200;
        curve = "easeout";
      };
    };

    appearance = {
      prefer_no_csd = true;
      border_width = 2;
      outer_border_width = 0;
      corner_radius = 1;
      drag_opacity = 0.90;

      blur = {
        enabled = true;
        optimized = true;
        passes = 2;
        radius = 5;
        noise = 0.02;
        brightness = 0.9;
        contrast = 0.9;
        saturation = 1.1;
      };

      shadow = {
        enabled = true;
        softness = 10;
        offset_x = 2;
        offset_y = 2;
      };
    };

    overview = {
      zoom = 0.5;
      # background_blur / workspace_background / shortcuts / badge_color
      # left at defaults; see Umbriel docs/user/workspaces-overview.
    };

    hot_corners = {
      top_left = {
        enabled = false;
        delay_ms = 500;
        action = "overview-open";
      };
      top_right = {
        enabled = false;
        delay_ms = 500;
        action = "overview-close";
      };
      bottom_left = {
        enabled = false;
        delay_ms = 500;
        action = "overview-toggle";
      };
      bottom_right = {
        enabled = false;
        delay_ms = 500;
        action = "spawn:notify-send 'Bottom right'";
      };
    };

    layout = {
      mode = "scrolling";
      gap = 5;
      extent_presets = [
        0.33333
        0.5
        0.66667
        1.0
      ];

      struts = {
        left = 0;
        right = 0;
        top = 0;
        bottom = 0;
      };

      scrolling = {
        default_extent_fraction = 0.66667;
        center_underfull_strip = false;
        center_focused = "never";
      };

      dwindle = { };

      master = {
        position = "left";
        default_width_fraction = 0.55;
        new_on_top = true;
      };
    };

    # Workspace override example (docs/user/outputs.md#workspace-rules):
    # workspace = [{ name = "chat"; layout.mode = "dwindle"; }];

    output = {
      "Samsung Electric Company S19C170 HYCFB02483" = {
        mode = "1366x768@59.79";
        scale = 1;
        transform = "normal";
        vrr = "disabled";
        tearing = false;
        direct_scanout = true;
        hdr = "off";
        sdr_white = 203;
        position = [
          0
          0
        ];
        enabled = true;
      };
    };

    input = {
      middle_click_paste = true;
      window_drag_toggle = "none";

      keyboard = {
        layout = "us";
        variant = "";
        options = "";
        repeat_rate = 45;
        repeat_delay = 250;
        numlock_toggle = true;
        track_layout = "global";
      };

      touchpad = {
        tap = true;
        natural_scroll = true;
      };

      mouse = {
        accel_profile = "flat";
        sensitivity = 0.0;
        scroll_wheel_step = 60;
      };

      tablet.enabled = true;

      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
        hardware_cursor = true;
        follows_focus = false;
        hide_when_typing = false;
        hide_timeout_ms = 0;
      };

      focus = {
        follows_mouse = false;
        follows_mouse_max_scroll = 0.0;
      };
    };

    # Per-device overrides example (names from `libinput list-devices`):
    # input.device = [{ name = "Acme Precision Touchpad"; tap = true; }];
  };
}
