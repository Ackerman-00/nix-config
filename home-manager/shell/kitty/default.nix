# Kitty terminal.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.kitty = {
    enable = true;

    font = {
      name = "Maple Mono NF";
      size = 9.4;
      package = null;
    };

    settings = import ./settings.nix // {
      shell = "/run/current-system/sw/bin/zsh";
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";
    };
  };

  # Fatal gate: bad kitty.conf refuses to activate.
  home.activation.validateKitty = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        kitty_lib="$(dirname "$(dirname "$(readlink -f "${config.programs.kitty.package}/bin/kitty")")")/lib/kitty"
        kitty_conf="${config.xdg.configHome}/kitty/kitty.conf"
        bad=$(${pkgs.python3}/bin/python3 - "$kitty_lib" "$kitty_conf" <<'PYEOF'
    import sys
    sys.path.insert(0, sys.argv[1])
    from kitty.config import load_config
    bad_lines = []
    load_config(sys.argv[2], accumulate_bad_lines=bad_lines)
    print(len(bad_lines))
    PYEOF
        )
        if [ "$bad" != "0" ]; then
          echo "ERROR: generated kitty.conf has $bad bad line(s); refusing to activate" >&2
          exit 1
        fi
        echo "kitty.conf parses clean"
  '';
}
