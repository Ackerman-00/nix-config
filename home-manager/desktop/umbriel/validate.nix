# Warn (never fail: an older binary may not know newer keys) when the
# live Umbriel config stops validating. Invalid configs keep the last
# working one, so this surfaces silent staleness instead of breakage.
{ lib, ... }:
{
  home.activation.validateUmbriel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umbriel_bin="$(command -v umbriel || echo /run/current-system/sw/bin/umbriel)"
    if [ -x "$umbriel_bin" ]; then
      if out="$("$umbriel_bin" config validate 2>&1)"; then
        echo "umbriel $out"
      else
        echo "WARNING: umbriel config invalid; previous working config stays active:" >&2
        echo "$out" >&2
      fi
    else
      echo "WARNING: umbriel binary not found; skipping config validation" >&2
    fi
  '';
}
