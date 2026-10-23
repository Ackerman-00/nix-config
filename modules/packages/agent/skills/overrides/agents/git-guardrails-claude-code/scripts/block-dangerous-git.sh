#!/usr/bin/env bash
# Check a shell command against the blocked git patterns.
#
# Usage:
#   block-dangerous-git.sh "<command>"
#   echo "<command>" | block-dangerous-git.sh
#
# Exit codes:
#   0  command is allowed
#   2  command matches a blocked pattern
#
# The pattern list lives in blocked-git-patterns.txt next to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERN_FILE="$SCRIPT_DIR/blocked-git-patterns.txt"

if [[ ! -f "$PATTERN_FILE" ]]; then
  echo "missing pattern file: $PATTERN_FILE" >&2
  exit 3
fi

COMMAND="${1:-}"
if [[ -z "$COMMAND" && ! -t 0 ]]; then
  COMMAND="$(cat)"
fi

if [[ -z "$COMMAND" ]]; then
  echo "usage: $(basename "$0") \"<command>\"" >&2
  exit 3
fi

while IFS= read -r pattern; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  if grep -qE -- "$pattern" <<<"$COMMAND"; then
    echo "BLOCKED: '$COMMAND' matches pattern '$pattern'." >&2
    exit 2
  fi
done <"$PATTERN_FILE"

exit 0
