#!/usr/bin/env bash
set -euo pipefail
RUN_ID="${RUN_ID:-}"
RELAY=".opencode-relay.md"
echo "----- VERIFICATION REPORT -----"
if [[ -f "$RELAY" ]]; then
  if [[ -z "$RUN_ID" ]]; then
    echo "FAIL: RUN_ID not set"
    exit 1
  fi
  if ! grep -qx "run_id: $RUN_ID" "$RELAY"; then
    echo "FAIL: relay run_id mismatch"
    exit 1
  fi
  if ! grep -qi "status: complete" "$RELAY"; then
    echo "FAIL: relay status not complete"
    exit 1
  fi
  echo "PASS: relay run_id and status"
else
  echo "FAIL: missing relay file"
  exit 1
fi
nix --extra-experimental-features 'nix-command flakes' --accept-flake-config flake check
echo "PASS: nix flake check"
