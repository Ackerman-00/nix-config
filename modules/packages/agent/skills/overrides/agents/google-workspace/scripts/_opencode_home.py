"""Resolve OpenCode directories for standalone skill scripts.

The Google OAuth token and client-secret files live next to the OpenCode
config so they are covered by the same access rules as the rest of the
OpenCode state.
"""

from __future__ import annotations

import os
from pathlib import Path


def get_opencode_config_home() -> Path:
    """Return the OpenCode config directory (default: ~/.config/opencode)."""
    val = os.environ.get("OPENCODE_CONFIG_DIR", "").strip()
    if val:
        return Path(val)
    xdg = os.environ.get("XDG_CONFIG_HOME", "").strip()
    if xdg:
        return Path(xdg) / "opencode"
    return Path.home() / ".config" / "opencode"


def display_opencode_config_home() -> str:
    """Return a ``~/``-shortened display string for the config directory."""
    home = get_opencode_config_home()
    try:
        return "~/" + home.relative_to(Path.home()).as_posix()
    except ValueError:
        return str(home)
