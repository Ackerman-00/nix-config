#!/usr/bin/env bash
set -euo pipefail

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx is required but not found on PATH." >&2
  exit 1
fi

has_session_flag="false"
has_browser_flag="false"
for arg in "$@"; do
  case "$arg" in
    --session|--session=*)
      has_session_flag="true"
      ;;
    --browser|--browser=*)
      has_browser_flag="true"
      ;;
  esac
done

cmd=(npx --yes --package @playwright/cli playwright-cli)
# The CLI defaults to the "chrome" channel (Google Chrome at /opt/google/chrome).
# This machine has chromium instead, so default to it and let the caller
# override with --browser or PLAYWRIGHT_CLI_BROWSER.
if [[ "${has_browser_flag}" != "true" ]]; then
  cmd+=(--browser "${PLAYWRIGHT_CLI_BROWSER:-chromium}")
fi
if [[ "${has_session_flag}" != "true" && -n "${PLAYWRIGHT_CLI_SESSION:-}" ]]; then
  cmd+=(--session "${PLAYWRIGHT_CLI_SESSION}")
fi
cmd+=("$@")

exec "${cmd[@]}"
