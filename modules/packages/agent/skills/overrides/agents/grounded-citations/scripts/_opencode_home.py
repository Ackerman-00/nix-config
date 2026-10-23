"""Resolve OpenCode directories for standalone skill scripts.

Skill scripts may run outside the OpenCode process (system Python, a
container, CI), so the paths are resolved from the environment with
stdlib-only fallbacks.
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


def get_opencode_cache_home() -> Path:
    """Return the OpenCode cache directory (default: ~/.cache/opencode)."""
    val = os.environ.get("OPENCODE_CACHE_DIR", "").strip()
    if val:
        return Path(val)
    xdg = os.environ.get("XDG_CACHE_HOME", "").strip()
    if xdg:
        return Path(xdg) / "opencode"
    return Path.home() / ".cache" / "opencode"


def get_opencode_state_home() -> Path:
    """Return the OpenCode state directory (default: ~/.local/state/opencode)."""
    val = os.environ.get("OPENCODE_STATE_DIR", "").strip()
    if val:
        return Path(val)
    xdg = os.environ.get("XDG_STATE_HOME", "").strip()
    if xdg:
        return Path(xdg) / "opencode"
    return Path.home() / ".local" / "state" / "opencode"
