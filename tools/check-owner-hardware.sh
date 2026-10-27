#!/usr/bin/env bash
# check-owner-hardware.sh - the CI stub must never reach the owner's machine.
#
# Verification copies tools/ci-hardware.nix over hardware-configuration.nix and
# re-locks the local-hardware input to it. Forgetting either step pushes a flake
# whose lock narHash does not match the owner's real hardware file, so every
# `nh os switch` fails on a NAR hash mismatch. This checks both, and --restore
# undoes both.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

BASE=${BASE:-origin/main}
MODE=${1:---check}
FAIL=0

if [ -e hardware-configuration.nix ]; then
  if cmp -s hardware-configuration.nix tools/ci-hardware.nix; then
    if [ "$MODE" = "--restore" ]; then
      rm -f hardware-configuration.nix
      echo "RESTORED removed the CI stub hardware-configuration.nix"
    else
      echo "FAIL hardware-configuration.nix is the CI stub"
      FAIL=1
    fi
  fi
fi

if git ls-files --error-unmatch hardware-configuration.nix >/dev/null 2>&1; then
  echo "FAIL hardware-configuration.nix is tracked"
  FAIL=1
fi

python3 - "$BASE" "$MODE" <<'PY' || FAIL=1
import json, subprocess, sys

base, mode = sys.argv[1], sys.argv[2]
try:
    upstream = json.loads(subprocess.check_output(["git", "show", f"{base}:flake.lock"], text=True))
except (subprocess.CalledProcessError, ValueError):
    print(f"SKIP no flake.lock on {base}")
    sys.exit(0)

want = upstream["nodes"]["local-hardware"]
data = json.load(open("flake.lock"))
if data["nodes"]["local-hardware"] == want:
    print(f"OK   local-hardware matches {base}")
    sys.exit(0)
if mode != "--restore":
    print(f"FAIL local-hardware locks the CI stub, not the owner's hardware")
    sys.exit(1)
data["nodes"]["local-hardware"] = want
with open("flake.lock", "w") as f:
    f.write(json.dumps(data, indent=2) + "\n")
print(f"RESTORED local-hardware from {base}")
PY

if [ "$FAIL" -ne 0 ]; then
  echo "OWNER HARDWARE CHECK FAILED - run bash tools/check-owner-hardware.sh --restore"
  exit 1
fi
echo "OWNER HARDWARE CHECK PASSED"
