#!/usr/bin/env bash
# Regenerate artifacts
# Keep the hyperframes owner
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

skills=$(nix --extra-experimental-features 'nix-command flakes' --accept-flake-config \
  build --no-link --print-out-paths "$root#hyperframes-skills" | tail -1)

python3 "$root/modules/packages/agent/skills/generate.py" \
  --hyperframes-dir "$skills/skills" \
  "$@"
