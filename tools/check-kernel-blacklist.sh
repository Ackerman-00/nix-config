#!/usr/bin/env bash
# check-kernel-blacklist.sh - a blacklisted module that the kernel stopped
# building is a silent no-op. Fail loudly so the list keeps matching the kernel.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

cfg=nixosConfigurations.quietcraft.config

modules=$(nix build --impure --no-link --print-out-paths ".#$cfg.boot.kernelPackages.kernel.modules")
mapfile -t names < <(
  nix eval --impure --json ".#$cfg.boot.blacklistedKernelModules" |
    tr -d '[]" ' | tr ',' '\n' | grep -v '^$'
)
[ "${#names[@]}" -gt 0 ] || {
  echo "FAIL could not read boot.blacklistedKernelModules"
  exit 1
}

fail=0
for name in "${names[@]}"; do
  if ! find "$modules" -name "$name.ko*" -print -quit | grep -q .; then
    echo "FAIL blacklisted module '$name' is not built by this kernel"
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "OK   every blacklisted module exists in $(basename "$modules")"
exit "$fail"
